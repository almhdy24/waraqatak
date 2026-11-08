import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:almhdy_analytics/almhdy_analytics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('almhdy_queue_test_');
    AlmHdyAnalytics.resetForTesting();
  });

  tearDown(() {
    AlmHdyAnalytics.resetForTesting();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('default maxQueueSize is 500', () async {
    final bufferPath = '${tempDir.path}/buffer_default.json';
    final client = AlmHdyAnalytics.instance;

    await client.initialize(
      projectKey: 'ak_test_key',
      storagePath: bufferPath,
    );

    expect(client.maxQueueSize, equals(500));
  });

  test('custom maxQueueSize is configured via initialize', () async {
    final bufferPath = '${tempDir.path}/buffer_custom.json';
    final client = AlmHdyAnalytics.instance;

    await client.initialize(
      projectKey: 'ak_test_key',
      storagePath: bufferPath,
      maxQueueSize: 25,
    );

    expect(client.maxQueueSize, equals(25));
  });

  test('FIFO eviction drops oldest events when queue reaches maxQueueSize',
      () async {
    final bufferPath = '${tempDir.path}/buffer_eviction.json';
    final client = AlmHdyAnalytics.instance;

    // Use a small cap of 3 and batchSize of 100 so automatic flush does not drain
    await client.initialize(
      projectKey: 'ak_test_key',
      storagePath: bufferPath,
      maxQueueSize: 3,
      batchSize: 100,
      endpoint: 'http://127.0.0.1:9999/unreachable',
    );

    client.track('event_1');
    client.track('event_2');
    client.track('event_3');

    expect(client.queueLength, equals(3));
    expect(client.queue.map((e) => e.event).toList(),
        equals(['event_1', 'event_2', 'event_3']));

    // Enqueue 4th event -> event_1 should be evicted
    client.track('event_4');
    expect(client.queueLength, equals(3));
    expect(client.queue.map((e) => e.event).toList(),
        equals(['event_2', 'event_3', 'event_4']));

    // Enqueue 5th event -> event_2 should be evicted
    client.track('event_5');
    expect(client.queueLength, equals(3));
    expect(client.queue.map((e) => e.event).toList(),
        equals(['event_3', 'event_4', 'event_5']));
  });

  test('eviction and remaining queue are persisted across restarts', () async {
    final bufferPath = '${tempDir.path}/buffer_persistence.json';

    // Step 1: Initialize client and enqueue events beyond cap
    final client1 = AlmHdyAnalytics.instance;
    await client1.initialize(
      projectKey: 'ak_test_key',
      storagePath: bufferPath,
      maxQueueSize: 3,
      batchSize: 100,
      endpoint: 'http://127.0.0.1:9999/unreachable',
    );

    client1.track('event_A');
    client1.track('event_B');
    client1.track('event_C');
    client1.track('event_D'); // evicts event_A

    // Give asynchronous file write a moment
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Verify on-disk content directly
    final file = File(bufferPath);
    expect(file.existsSync(), isTrue);
    final diskJson =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final diskQueue = (diskJson['queue'] as List<dynamic>)
        .map((e) => (e as Map)['event'])
        .toList();
    expect(diskQueue, equals(['event_B', 'event_C', 'event_D']));

    // Step 2: Reset client (simulate app termination)
    AlmHdyAnalytics.resetForTesting();

    // Step 3: Initialize new client with same storagePath
    final client2 = AlmHdyAnalytics.instance;
    await client2.initialize(
      projectKey: 'ak_test_key',
      storagePath: bufferPath,
      maxQueueSize: 3,
      batchSize: 100,
      endpoint: 'http://127.0.0.1:9999/unreachable',
    );

    expect(client2.queueLength, equals(3));
    expect(client2.queue.map((e) => e.event).toList(),
        equals(['event_B', 'event_C', 'event_D']));

    // Enqueue another event on restarted client -> evicts event_B
    client2.track('event_E');
    expect(client2.queue.map((e) => e.event).toList(),
        equals(['event_C', 'event_D', 'event_E']));
  });

  test('existing buffer with excess events is pruned to maxQueueSize upon load',
      () async {
    final bufferPath = '${tempDir.path}/buffer_prune_on_load.json';

    // Pre-create buffer file with 5 events
    final file = File(bufferPath);
    final payload = {
      'installation_id': 'inst_test_123',
      'user_pseudo_id': null,
      'opted_out': false,
      'queue': [
        {
          'event': 'old_1',
          'platform': 'android',
          'app_version': '1.0.0',
          'installation_id': 'inst_test_123',
          'properties': {},
          'timestamp': '2026-11-08T00:00:00Z'
        },
        {
          'event': 'old_2',
          'platform': 'android',
          'app_version': '1.0.0',
          'installation_id': 'inst_test_123',
          'properties': {},
          'timestamp': '2026-11-08T00:01:00Z'
        },
        {
          'event': 'old_3',
          'platform': 'android',
          'app_version': '1.0.0',
          'installation_id': 'inst_test_123',
          'properties': {},
          'timestamp': '2026-11-08T00:02:00Z'
        },
        {
          'event': 'old_4',
          'platform': 'android',
          'app_version': '1.0.0',
          'installation_id': 'inst_test_123',
          'properties': {},
          'timestamp': '2026-11-08T00:03:00Z'
        },
        {
          'event': 'old_5',
          'platform': 'android',
          'app_version': '1.0.0',
          'installation_id': 'inst_test_123',
          'properties': {},
          'timestamp': '2026-11-08T00:04:00Z'
        },
      ],
    };
    file.writeAsStringSync(jsonEncode(payload));

    // Initialize client with maxQueueSize: 2
    final client = AlmHdyAnalytics.instance;
    await client.initialize(
      projectKey: 'ak_test_key',
      storagePath: bufferPath,
      maxQueueSize: 2,
      batchSize: 100,
    );

    // Oldest 3 should have been dropped on load, keeping only old_4 and old_5
    expect(client.queueLength, equals(2));
    expect(
        client.queue.map((e) => e.event).toList(), equals(['old_4', 'old_5']));
  });
}

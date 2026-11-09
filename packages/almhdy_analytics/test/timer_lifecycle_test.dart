import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:almhdy_analytics/almhdy_analytics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('almhdy_timer_test_');
    AlmHdyAnalytics.resetForTesting();
  });

  tearDown(() {
    AlmHdyAnalytics.resetForTesting();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('timer is NOT started on initialize when queue is empty', () async {
    final bufferPath = '${tempDir.path}/buffer_empty.json';
    final client = AlmHdyAnalytics.instance;

    await client.initialize(
      projectKey: 'ak_test_key',
      storagePath: bufferPath,
    );

    expect(client.queueLength, equals(0));
    expect(client.isTimerActive, isFalse);
  });

  test('timer starts on initialize if offline buffer has persisted events',
      () async {
    final bufferPath = '${tempDir.path}/buffer_with_events.json';
    final file = File(bufferPath);
    final payload = {
      'installation_id': 'inst_123',
      'user_pseudo_id': null,
      'opted_out': false,
      'queue': [
        {
          'event': 'restored_event',
          'platform': 'android',
          'app_version': '1.0.0',
          'installation_id': 'inst_123',
          'properties': {},
          'timestamp': '2026-11-08T00:00:00Z',
        }
      ],
    };
    file.writeAsStringSync(jsonEncode(payload));

    final client = AlmHdyAnalytics.instance;
    await client.initialize(
      projectKey: 'ak_test_key',
      storagePath: bufferPath,
    );

    expect(client.queueLength, equals(1));
    expect(client.isTimerActive, isTrue);
  });

  test('enqueueing an event starts the flush timer', () async {
    final bufferPath = '${tempDir.path}/buffer_start_on_enqueue.json';
    final client = AlmHdyAnalytics.instance;

    await client.initialize(
      projectKey: 'ak_test_key',
      storagePath: bufferPath,
      batchSize: 50, // high batchSize so track does not immediately call flush
    );

    expect(client.isTimerActive, isFalse);

    client.track('test_event');

    expect(client.queueLength, equals(1));
    expect(client.isTimerActive, isTrue);
  });

  test('successful flush pauses timer when queue is completely drained',
      () async {
    AlmHdyAnalytics.httpClient = MockClient((request) async {
      return http.Response('{"status":"ok"}', 200,
          headers: {'content-type': 'application/json'});
    });

    final bufferPath = '${tempDir.path}/buffer_drain.json';
    final client = AlmHdyAnalytics.instance;

    await client.initialize(
      projectKey: 'ak_test_key',
      storagePath: bufferPath,
      batchSize: 10,
    );

    client.track('event_1');
    expect(client.queueLength, equals(1));
    expect(client.isTimerActive, isTrue);

    // Manually trigger flush to drain
    await client.flush();

    expect(client.queueLength, equals(0));
    expect(client.isTimerActive, isFalse);
  });

  test('failed flush leaves events in queue and timer stays active for retry',
      () async {
    AlmHdyAnalytics.httpClient = MockClient((request) async {
      return http.Response('Server Error', 500);
    });

    final bufferPath = '${tempDir.path}/buffer_retry.json';
    final client = AlmHdyAnalytics.instance;

    await client.initialize(
      projectKey: 'ak_test_key',
      storagePath: bufferPath,
      batchSize: 10,
    );

    client.track('event_failed_flush');
    expect(client.isTimerActive, isTrue);

    await client.flush();

    // Flush failed -> event remains, timer stays active to retry
    expect(client.queueLength, equals(1));
    expect(client.isTimerActive, isTrue);
  });

  test(
      'timer does not pause if another event is enqueued before flush completes',
      () async {
    final completer = Completer<http.Response>();
    AlmHdyAnalytics.httpClient =
        MockClient((request) async => completer.future);

    final bufferPath = '${tempDir.path}/buffer_race.json';
    final client = AlmHdyAnalytics.instance;

    await client.initialize(
      projectKey: 'ak_test_key',
      storagePath: bufferPath,
      batchSize: 10,
    );

    client.track('first_event');
    expect(client.queueLength, equals(1));
    expect(client.isTimerActive, isTrue);

    // Start flush (it will wait on completer)
    final flushFuture = client.flush();

    // Concurrently enqueue a second event while first flush is in-flight
    client.track('second_event');
    expect(client.queueLength, equals(2));

    // Release the first HTTP request
    completer.complete(http.Response('{"status":"ok"}', 200,
        headers: {'content-type': 'application/json'}));
    await flushFuture;

    // First event was flushed, second event remains -> timer must STILL be active!
    expect(client.queueLength, equals(1));
    expect(client.queue.first.event, equals('second_event'));
    expect(client.isTimerActive, isTrue);
  });

  test('optOut immediately pauses flush timer and clears queue', () async {
    AlmHdyAnalytics.httpClient =
        MockClient((request) async => http.Response('{"status":"ok"}', 200));

    final bufferPath = '${tempDir.path}/buffer_optout.json';
    final client = AlmHdyAnalytics.instance;

    await client.initialize(
      projectKey: 'ak_test_key',
      storagePath: bufferPath,
      batchSize: 50,
    );

    client.track('event_before_optout');
    expect(client.isTimerActive, isTrue);

    await client.optOut();

    expect(client.queueLength, equals(0));
    expect(client.isTimerActive, isFalse);
    expect(client.isOptedOut, isTrue);
  });

  test('dispose pauses flush timer', () async {
    final bufferPath = '${tempDir.path}/buffer_dispose.json';
    final client = AlmHdyAnalytics.instance;

    await client.initialize(
      projectKey: 'ak_test_key',
      storagePath: bufferPath,
      batchSize: 50,
    );

    client.track('event_dispose');
    expect(client.isTimerActive, isTrue);

    client.dispose();
    expect(client.isTimerActive, isFalse);
  });
}

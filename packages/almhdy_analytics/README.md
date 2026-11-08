# AlmHdy Analytics Flutter SDK

Cross-platform telemetry SDK for Flutter apps across Android, iOS, and Windows Desktop.

## Features
- **Cross-Platform**: Android, iOS, Windows, macOS, Linux.
- **Offline Resilient**: Local disk persistence with FIFO eviction cap (`maxQueueSize`, default 500).
- **Automatic Storage Resolution**: Resolves app support directory automatically on mobile targets using `path_provider`.
- **Battery-Friendly Lifecycle**: Pauses periodic flush timer when queue is empty; resumes on new events.
- **Automatic Batching**: Collects events and flushes periodically or when batch size is reached.
- **Session Management**: Automatically rotates sessions on 30 minutes of inactivity.
- **Privacy First**: Zero plaintext PII. Automatically filters sensitive keys.
- **Opt-Out Compliant**: In-app opt-out synchronization with server.

## Installation

Add to your `pubspec.yaml`:
```yaml
dependencies:
  almhdy_analytics:
    path: path/to/sdk/flutter
  path_provider: ^2.1.0 # Required for automatic storage path resolution on mobile
```

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:almhdy_analytics/almhdy_analytics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AlmHdyAnalytics.instance.initialize(
    projectKey: 'ak_live_your_project_key',
    appVersion: '1.2.0',
    maxQueueSize: 500, // Optional cap (default: 500 events)
    // storagePath is optional on mobile (auto-resolves via path_provider)
    debug: false,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Cashirak POS')),
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              AlmHdyAnalytics.instance.track(
                'receipt_printed',
                properties: {
                  'item_count': 5,
                  'payment_method': 'cash',
                },
              );
            },
            child: const Text('Print Receipt'),
          ),
        ),
      ),
    );
  }
}
```

## Configuration Options

| Option | Type | Default | Description |
|---|---|---|---|
| `projectKey` | `String` | *(Required)* | Project ingestion key issued by AlmHdy API panel (`ak_live_...`). |
| `endpoint` | `String?` | Production URL | Custom ingestion endpoint URL. |
| `optOutEndpoint`| `String?` | Production URL | Custom opt-out endpoint URL. |
| `appVersion` | `String?` | `'1.0.0'` | Host application version tag. |
| `platform` | `String?` | Auto-detected | Target OS identifier (`android`, `ios`, `windows`, `macos`, `linux`). |
| `batchSize` | `int?` | `10` | Maximum events flushed per network batch (clamped 1..50). |
| `maxQueueSize` | `int?` | `500` | Maximum offline events retained on disk (FIFO eviction drops oldest). |
| `flushInterval`| `Duration?` | `5s` | Periodic interval between background flush attempts. |
| `storagePath` | `String?` | Auto-resolved | Path to local JSON buffer file. Auto-resolves on Android/iOS via `path_provider`. |
| `debug` | `bool` | `false` | Enables verbose diagnostic logging in debug console. |

## Development & Verification

When developing on a workstation or CI environment with the Flutter / Dart SDK installed:

```bash
# Analyze package code for lint and type warnings
dart analyze sdk/flutter/

# Format code
dart format sdk/flutter/

# Run unit tests
flutter test sdk/flutter/test/
```

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Search debounce and session discarding logic', () {
    test('rapid keystrokes within 300ms debounce only fire the latest search', () async {
      int queryExecutionCount = 0;
      String? lastExecutedQuery;
      Timer? debounceTimer;

      void onSearchChanged(String query) {
        debounceTimer?.cancel();
        debounceTimer = Timer(const Duration(milliseconds: 300), () {
          queryExecutionCount++;
          lastExecutedQuery = query;
        });
      }

      // Simulate rapid user typing "ش", "شا", "شاي" within 100ms intervals
      onSearchChanged('ش');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      onSearchChanged('شا');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      onSearchChanged('شاي');

      // Before 300ms expires from last stroke, nothing should have executed
      expect(queryExecutionCount, 0);

      // Wait for debounce period (350ms)
      await Future<void>.delayed(const Duration(milliseconds: 350));

      // Only the last query must have executed exactly once
      expect(queryExecutionCount, 1);
      expect(lastExecutedQuery, 'شاي');
    });

    test('stale async results from an earlier session are discarded', () async {
      int searchSession = 0;
      String? activeState;

      Future<void> applySearch(String query, Duration simulatedNetworkDelay) async {
        final session = ++searchSession;
        // Simulate async query
        await Future<void>.delayed(simulatedNetworkDelay);
        // Stale session check (same as in ProductsScreen and InventoryScreen)
        if (session != searchSession) return;
        activeState = query;
      }

      // Fire query A with a slow 200ms delay
      final searchA = applySearch('Query A (Slow)', const Duration(milliseconds: 200));

      // Rapidly fire query B shortly after with a fast 50ms delay
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final searchB = applySearch('Query B (Fast)', const Duration(milliseconds: 50));

      await Future.wait([searchA, searchB]);

      // Query B finished first at ~70ms, setting activeState to 'Query B (Fast)'.
      // When Query A finished at ~200ms, its session (1) was != current session (2),
      // so it did not overwrite activeState!
      expect(activeState, 'Query B (Fast)');
    });
  });
}

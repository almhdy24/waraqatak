import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../services/access/audit_service.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/responsive.dart';

class AuditTrailScreen extends StatefulWidget {
  const AuditTrailScreen({super.key});

  @override
  State<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends State<AuditTrailScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String _searchQuery = '';
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'audit_log',
        orderBy: 'id DESC',
        limit: 200,
      );
      if (!mounted) return;
      setState(() {
        _events = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyChain() async {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await AuditService.instance.verifyChain();
      final isValid = result.isValid;
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            isValid ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
            size: 48,
            color: isValid ? cs.primary : cs.error,
          ),
          title: Text(l10n.verifyAuditIntegrity),
          content: Text(
            isValid ? l10n.auditIntegrityValid : l10n.auditIntegrityTampered,
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.continueAction),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      AppSnackBar.show(context, e.toString(), severity: AppSnackBarSeverity.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    final filtered = _events.where((e) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final action = (e['action'] ?? '').toString().toLowerCase();
      final user = (e['user_name'] ?? e['user_id'] ?? '').toString().toLowerCase();
      final details = (e['details'] ?? '').toString().toLowerCase();
      return action.contains(q) || user.contains(q) || details.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.auditTrail),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.verified_outlined),
            tooltip: l10n.verifyAuditIntegrity,
            onPressed: _verifyChain,
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: '${l10n.search}...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? AppEmptyState(
                          icon: Icons.history_edu_outlined,
                          title: l10n.auditTrail,
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) {
                              final event = filtered[i];
                              final action = event['action']?.toString() ?? '—';
                              final userName = event['user_name']?.toString() ??
                                  (event['user_id'] != null ? event['user_id'].toString() : '—');
                              final timestamp = event['timestamp'] != null
                                  ? _dateFormat.format(DateTime.parse(event['timestamp'].toString()))
                                  : '—';
                              final details = event['details']?.toString();
                              final entityType = event['entity_type']?.toString();
                              final entityId = event['entity_id']?.toString();

                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: cs.primaryContainer,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              action,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: cs.onPrimaryContainer,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(Icons.person_outline, size: 14, color: cs.onSurfaceVariant),
                                          const SizedBox(width: 4),
                                          Text(
                                            userName,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                          const Spacer(),
                                          Text(
                                            timestamp,
                                            style: TextStyle(fontSize: 11, color: cs.outline),
                                          ),
                                        ],
                                      ),
                                      if (entityType != null || entityId != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          '${entityType ?? ''} #${entityId ?? ''}',
                                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                        ),
                                      ],
                                      if (details != null && details.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          details,
                                          style: TextStyle(fontSize: 12, color: cs.outline),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

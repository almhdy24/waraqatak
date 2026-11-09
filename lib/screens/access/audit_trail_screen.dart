import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../services/access/audit_service.dart';
import '../../widgets/access/screen_access_gate.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/responsive.dart';

class AuditTrailScreen extends StatefulWidget {
  const AuditTrailScreen({super.key});

  @override
  State<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

enum AuditFilter { all, security, logins, mutations }

class _AuditTrailScreenState extends State<AuditTrailScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String _searchQuery = '';
  AuditFilter _activeFilter = AuditFilter.all;
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
        limit: 250,
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
            isValid
                ? '${l10n.auditIntegrityValid} (${result.verifiedCount} ${l10n.isArabic ? 'سجل موثق' : 'verified entries'})'
                : l10n.auditIntegrityTampered,
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

  Color _getActionColor(String action, ColorScheme cs) {
    if (action.contains('denied') || action.contains('failed') || action.contains('lockout')) {
      return cs.error;
    }
    if (action.contains('login') || action.contains('success') || action.contains('created')) {
      return Colors.teal;
    }
    if (action.contains('updated') || action.contains('override')) {
      return Colors.amber.shade800;
    }
    return cs.primary;
  }

  Color _getActionContainerColor(String action, ColorScheme cs) {
    if (action.contains('denied') || action.contains('failed') || action.contains('lockout')) {
      return cs.errorContainer.withValues(alpha: 0.6);
    }
    if (action.contains('login') || action.contains('success') || action.contains('created')) {
      return Colors.teal.withValues(alpha: 0.15);
    }
    if (action.contains('updated') || action.contains('override')) {
      return Colors.amber.withValues(alpha: 0.15);
    }
    return cs.primaryContainer.withValues(alpha: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    final filtered = _events.where((e) {
      final action = (e['action'] ?? '').toString().toLowerCase();

      // Category filter
      switch (_activeFilter) {
        case AuditFilter.security:
          if (!action.contains('denied') &&
              !action.contains('failed') &&
              !action.contains('lockout') &&
              !action.contains('reauth')) {
            return false;
          }
          break;
        case AuditFilter.logins:
          if (!action.contains('login') && !action.contains('logout')) return false;
          break;
        case AuditFilter.mutations:
          if (!action.contains('user_') && !action.contains('role_') && !action.contains('override')) {
            return false;
          }
          break;
        case AuditFilter.all:
          break;
      }

      // Search query
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final user = (e['user_name'] ?? e['user_id'] ?? '').toString().toLowerCase();
      final details = (e['details'] ?? '').toString().toLowerCase();
      return action.contains(q) || user.contains(q) || details.contains(q);
    }).toList();

    return ScreenAccessGate(
      screenType: AuditTrailScreen,
      child: Scaffold(
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
              // Search input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '${l10n.search}...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    FilterChip(
                      label: Text(l10n.isArabic ? 'الكل' : 'All'),
                      selected: _activeFilter == AuditFilter.all,
                      onSelected: (_) => setState(() => _activeFilter = AuditFilter.all),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: const Icon(Icons.shield_outlined, size: 16),
                      label: Text(l10n.isArabic ? 'الأمان والحماية' : 'Security'),
                      selected: _activeFilter == AuditFilter.security,
                      onSelected: (_) => setState(() => _activeFilter = AuditFilter.security),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: const Icon(Icons.login_rounded, size: 16),
                      label: Text(l10n.isArabic ? 'الدخول والخروج' : 'Logins'),
                      selected: _activeFilter == AuditFilter.logins,
                      onSelected: (_) => setState(() => _activeFilter = AuditFilter.logins),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: const Icon(Icons.edit_note_rounded, size: 16),
                      label: Text(l10n.isArabic ? 'التعديلات' : 'Changes'),
                      selected: _activeFilter == AuditFilter.mutations,
                      onSelected: (_) => setState(() => _activeFilter = AuditFilter.mutations),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

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
                                final badgeColor = _getActionColor(action, cs);
                                final containerColor = _getActionContainerColor(action, cs);

                                return Card(
                                  elevation: 0,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: containerColor,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                action,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: badgeColor,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(Icons.person_outline, size: 14, color: cs.onSurfaceVariant),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                userName,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
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
                                          _buildDetailsWidget(details, cs),
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
      ),
    );
  }

  Widget _buildDetailsWidget(String rawDetails, ColorScheme cs) {
    try {
      if (rawDetails.startsWith('{') && rawDetails.endsWith('}')) {
        final map = jsonDecode(rawDetails) as Map<String, dynamic>;
        final entries = map.entries.map((e) => '${e.key}: ${e.value}').join(' • ');
        return Text(
          entries,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        );
      }
    } catch (_) {}

    return Text(
      rawDetails,
      style: TextStyle(fontSize: 12, color: cs.outline),
    );
  }
}

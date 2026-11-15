import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../localization/app_localizations.dart';
import '../../services/access/access_messages.dart';
import '../../services/access/audit_service.dart';
import '../../widgets/access/screen_access_gate.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_status_colors.dart';
import '../../widgets/responsive.dart';

class AuditTrailScreen extends StatefulWidget {
  const AuditTrailScreen({super.key});

  @override
  State<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

enum AuditFilter { all, security, logins, mutations }

class _AuditTrailScreenState extends State<AuditTrailScreen> {
  static const int _pageSize = 100;
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String _searchQuery = '';
  AuditFilter _activeFilter = AuditFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool loadMore = false}) async {
    if (loadMore) {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() => _loading = true);
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      // Keyset pagination (D26)
      if (loadMore && _events.isNotEmpty) {
        final lastId = (_events.last['id'] as num).toInt();
        whereClauses.add('id < ?');
        whereArgs.add(lastId);
      }

      // Filter in database (D26)
      switch (_activeFilter) {
        case AuditFilter.security:
          whereClauses.add("(action LIKE '%denied%' OR action LIKE '%failed%' OR action LIKE '%lockout%' OR action LIKE '%reauth%')");
          break;
        case AuditFilter.logins:
          whereClauses.add("(action LIKE '%login%' OR action LIKE '%logout%')");
          break;
        case AuditFilter.mutations:
          whereClauses.add("(action LIKE '%user_%' OR action LIKE '%role_%' OR action LIKE '%override%')");
          break;
        case AuditFilter.all:
          break;
      }

      // Search in database (D26)
      if (_searchQuery.isNotEmpty) {
        whereClauses.add('(action LIKE ? OR user_name LIKE ? OR details LIKE ?)');
        whereArgs.addAll(['%%', '%%', '%%']);
      }

      final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

      final rows = await db.query(
        'audit_log',
        where: whereString,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'id DESC',
        limit: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        _hasMore = rows.length == _pageSize;
        if (loadMore) {
          _events.addAll(rows);
          _loadingMore = false;
        } else {
          _events = List.from(rows);
          _loading = false;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _verifyChain() async {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    int verified = 0;
    int total = 0;
    StateSetter? setProgressState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgContext) => StatefulBuilder(
        builder: (ctx, setState) {
          setProgressState = setState;
          return AlertDialog(
            title: Text(l10n.verifyAuditIntegrity),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: total > 0 ? (verified / total) : null,
                ),
                const SizedBox(height: 16),
                Text(
                  total > 0
                      ? '${l10n.auditVerifyingProgress} ($verified / $total)'
                      : l10n.auditVerifyingProgress,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      final result = await AuditService.instance.verifyChain(
        onProgress: (v, t) {
          if (mounted && setProgressState != null) {
            setProgressState!(() {
              verified = v;
              total = t;
            });
          }
        },
      );
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
                ? '${l10n.auditIntegrityValid} (${l10n.auditVerifiedEntries(result.verifiedCount)})'
                : (result.brokenAtId != null
                    ? '${l10n.auditIntegrityTampered}\n\n${l10n.auditBrokenAtId(result.brokenAtId!)}'
                    : l10n.auditIntegrityTampered),
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
      AppSnackBar.show(context, friendlyError(l10n, e), severity: AppSnackBarSeverity.error);
    }
  }

  Color _getActionColor(BuildContext context, String action, ColorScheme cs) {
    if (action.contains('denied') || action.contains('failed') || action.contains('lockout')) {
      return cs.error;
    }
    if (action.contains('login') || action.contains('success') || action.contains('created')) {
      return AppStatusColors.fg(context, AppStatus.success);
    }
    if (action.contains('updated') || action.contains('override') || action.contains('unlocked')) {
      return AppStatusColors.fg(context, AppStatus.warning);
    }
    return cs.primary;
  }

  Color _getActionContainerColor(BuildContext context, String action, ColorScheme cs) {
    if (action.contains('denied') || action.contains('failed') || action.contains('lockout')) {
      return cs.errorContainer.withValues(alpha: 0.6);
    }
    if (action.contains('login') || action.contains('success') || action.contains('created')) {
      return AppStatusColors.bg(context, AppStatus.success);
    }
    if (action.contains('updated') || action.contains('override') || action.contains('unlocked')) {
      return AppStatusColors.bg(context, AppStatus.warning);
    }
    return cs.primaryContainer.withValues(alpha: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

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
                  onChanged: (val) {
                    _searchQuery = val.trim();
                    _load();
                  },
                ),
              ),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    FilterChip(
                      label: Text(l10n.auditFilterAll),
                      selected: _activeFilter == AuditFilter.all,
                      onSelected: (_) {
                        setState(() => _activeFilter = AuditFilter.all);
                        _load();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: const Icon(Icons.shield_outlined, size: 16),
                      label: Text(l10n.auditFilterSecurity),
                      selected: _activeFilter == AuditFilter.security,
                      onSelected: (_) {
                        setState(() => _activeFilter = AuditFilter.security);
                        _load();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: const Icon(Icons.login_rounded, size: 16),
                      label: Text(l10n.auditFilterLogins),
                      selected: _activeFilter == AuditFilter.logins,
                      onSelected: (_) {
                        setState(() => _activeFilter = AuditFilter.logins);
                        _load();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: const Icon(Icons.edit_note_rounded, size: 16),
                      label: Text(l10n.auditFilterChanges),
                      selected: _activeFilter == AuditFilter.mutations,
                      onSelected: (_) {
                        setState(() => _activeFilter = AuditFilter.mutations);
                        _load();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _events.isEmpty
                        ? AppEmptyState(
                            icon: Icons.history_edu_outlined,
                            title: l10n.auditTrail,
                          )
                        : RefreshIndicator(
                            onRefresh: () => _load(),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _events.length + (_hasMore ? 1 : 0),
                              itemBuilder: (ctx, i) {
                                if (i == _events.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: _loadingMore
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : OutlinedButton.icon(
                                              icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                                              label: Text(l10n.loadMore),
                                              onPressed: () => _load(loadMore: true),
                                            ),
                                    ),
                                  );
                                }

                                final event = _events[i];
                                final action = event['action']?.toString() ?? '—';
                                final rawUserName = event['user_name']?.toString() ??
                                    (event['user_id'] != null ? event['user_id'].toString() : '—');
                                final userName = localizedActorName(l10n, rawUserName);

                                // D24: DateTime.tryParse handling
                                final rawTs = event['timestamp']?.toString();
                                final parsedTs = rawTs != null ? DateTime.tryParse(rawTs) : null;
                                final timestamp = parsedTs != null ? _dateFormat.format(parsedTs.toLocal()) : l10n.auditUnknownTime;

                                final details = event['details']?.toString();
                                final entityType = event['entity_type']?.toString();
                                final entityId = event['entity_id']?.toString();
                                final badgeColor = _getActionColor(context, action, cs);
                                final containerColor = _getActionContainerColor(context, action, cs);
                                final localizedAction = localizedAuditAction(l10n, action);

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
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    localizedAction ?? action,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: badgeColor,
                                                    ),
                                                  ),
                                                  if (localizedAction != null && localizedAction != action)
                                                    Text(
                                                      action,
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        color: cs.outline,
                                                      ),
                                                    ),
                                                ],
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
                                          _buildDetailsWidget(details, cs, l10n),
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

  Widget _buildDetailsWidget(String rawDetails, ColorScheme cs, AppLocalizations l10n) {
    try {
      if (rawDetails.startsWith('{') && rawDetails.endsWith('}')) {
        final map = jsonDecode(rawDetails) as Map<String, dynamic>;
        if (map.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: map.entries.map((e) {
              final label = localizedAuditDetailKey(l10n, e.key);
              final val = e.value is List ? (e.value as List).join(', ') : e.value?.toString() ?? '—';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label: ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        val,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      }
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        rawDetails,
        style: TextStyle(fontSize: 11, color: cs.outline),
      ),
    );
  }
}

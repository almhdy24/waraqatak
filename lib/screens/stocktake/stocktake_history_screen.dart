import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../localization/app_localizations.dart';
import '../../models/stocktake.dart';
import '../../services/stocktake_service.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/responsive.dart';
import 'stocktake_screen.dart';

class StocktakeHistoryScreen extends StatefulWidget {
  const StocktakeHistoryScreen({super.key});

  @override
  State<StocktakeHistoryScreen> createState() => _StocktakeHistoryScreenState();
}

class _StocktakeHistoryScreenState extends State<StocktakeHistoryScreen> {
  List<StocktakeSession> _sessions = [];
  bool _loading = true;
  String? _error;

  static final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await StocktakeService.instance.getAllSessions(limit: 100);
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.noStocktakeSessions.isEmpty ? l10n.stocktakeTitle : l10n.stocktakeTitle),
      ),
      body: ResponsiveCenter(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _sessions.isEmpty
                    ? Center(child: Text(l10n.noStocktakeSessions))
                    : ListView.separated(
                        itemCount: _sessions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final s = _sessions[idx];

                          Color statusColor = Colors.grey;
                          String statusText = s.status;
                          if (s.isCompleted) {
                            statusColor = Colors.teal;
                            statusText = l10n.sessionStatusCompleted;
                          } else if (s.isCancelled) {
                            statusColor = Colors.red;
                            statusText = l10n.sessionStatusCancelled;
                          } else if (s.isActive) {
                            statusColor = Colors.orange;
                            statusText = l10n.sessionStatusInProgress;
                          }

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: statusColor.withValues(alpha: 0.15),
                              child: Icon(Icons.fact_check_outlined, color: statusColor),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s.sessionNumber,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  _dateFmt.format(s.startedAt),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${l10n.total}: ${s.totalItems} • ${l10n.statusMatched}: ${s.matchedItems} • ${l10n.variance}: ${s.discrepantItems}',
                                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                            trailing: Icon(
                              AppIcons.chevronForward(context),
                              size: 18,
                            ),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StocktakeScreen(existingSessionId: s.id),
                                ),
                              );
                              _load();
                            },
                          );
                        },
                      ),
      ),
    );
  }
}

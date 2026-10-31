import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_constants.dart';
import '../localization/app_localizations.dart';
import '../models/app_notification.dart';
import '../services/app_ops_service.dart';
import '../utils/url_launcher_utils.dart';
import '../widgets/app_icons.dart';
import '../widgets/responsive.dart';
import 'database_diagnostic_screen.dart';
import 'google_drive_backup_screen.dart';
import 'license_screen.dart';
import 'settings_screen.dart';

class NotificationsInboxScreen extends StatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  State<NotificationsInboxScreen> createState() =>
      _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState extends State<NotificationsInboxScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await AppOpsService.instance.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = items;
        _loading = false;
      });
    }
  }

  Future<void> _sync() async {
    await AppOpsService.instance.syncInbox(force: true);
    await _load();
  }

  Future<void> _markAllAsRead() async {
    for (final n in _notifications) {
      if (!n.isRead) {
        await AppOpsService.instance.markAsRead(n.serverId);
      }
    }
    await _load();
  }

  void _openDetail(AppNotification item) async {
    if (!item.isRead) {
      await AppOpsService.instance.markAsRead(item.serverId);
      _load();
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dateStr = DateFormat(
      'yyyy/MM/dd – HH:mm',
    ).format(item.publishedAt.toLocal());

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsetsDirectional.only(
            top: 20,
            start: 20,
            end: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _categoryChip(item.category, l10n),
                  const Spacer(),
                  Text(
                    dateStr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                item.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: Text(
                    item.body,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ),
              ),
              if (item.actionUrl != null && item.actionUrl!.isNotEmpty) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _handleAction(ctx, item.actionUrl!.trim(), l10n),
                  icon: Icon(AppIcons.arrowForward(ctx), size: 18),
                  label: Text(l10n.openDestination),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(MaterialLocalizations.of(ctx).closeButtonLabel),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleAction(BuildContext ctx, String actionUrl, AppLocalizations l10n) {
    Navigator.of(ctx).pop();
    final lower = actionUrl.toLowerCase();

    if (lower == 'settings' || lower == 'app://settings') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
      return;
    }
    if (lower == 'backup' ||
        lower == 'drive' ||
        lower == 'google_drive' ||
        lower == 'app://backup' ||
        lower == 'app://drive') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GoogleDriveBackupScreen()),
      );
      return;
    }
    if (lower == 'license' || lower == 'app://license') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LicenseScreen()),
      );
      return;
    }
    if (lower == 'diagnostic' || lower == 'repair' || lower == 'app://diagnostic') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DatabaseDiagnosticScreen()),
      );
      return;
    }
    if (lower == 'help' || lower == 'app://help') {
      UrlLauncherUtils.launch(context, AppConstants.helpCenterUrl);
      return;
    }

    final isSafeWeb = RegExp(
      r'^https://([a-z0-9-]+\.)*almhdy24\.com(/.*)?$',
      caseSensitive: false,
    ).hasMatch(actionUrl);

    if (isSafeWeb) {
      UrlLauncherUtils.launch(context, actionUrl);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.networkError)),
    );
  }

  Widget _categoryChip(String category, AppLocalizations l10n) {
    Color bg;
    Color fg;
    String label;

    switch (category) {
      case 'update':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        label = l10n.categoryUpdate;
        break;
      case 'critical':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = l10n.categoryCritical;
        break;
      case 'tips':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = l10n.categoryTips;
        break;
      case 'announcement':
      default:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        label = l10n.categoryAnnouncement;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inboxTitle),
        centerTitle: true,
        actions: [
          if (unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: l10n.markAllRead,
              onPressed: _markAllAsRead,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.retry,
            onPressed: _sync,
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mark_email_read_outlined,
                        size: 72,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.noNotifications,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _sync,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(l10n.retry),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _sync,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _notifications[index];
                    final dateStr = DateFormat(
                      'yyyy/MM/dd',
                    ).format(item.publishedAt.toLocal());

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      tileColor: item.isRead
                          ? null
                          : theme.colorScheme.primaryContainer.withAlpha(25),
                      leading: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [_categoryChip(item.category, l10n)],
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: item.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!item.isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            item.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateStr,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      trailing: Icon(AppIcons.chevronForward(context), size: 20),
                      onTap: () => _openDetail(item),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

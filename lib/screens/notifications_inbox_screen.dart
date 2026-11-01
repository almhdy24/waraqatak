import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_constants.dart';
import '../localization/app_localizations.dart';
import '../models/app_notification.dart';
import '../services/app_ops_service.dart';
import '../utils/url_launcher_utils.dart';
import '../widgets/app_icons.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/responsive.dart';
import 'about_screen.dart';
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
  final Set<int> _selectedIds = {};
  bool _loading = true;

  bool get _isSelectionMode => _selectedIds.isNotEmpty;

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
        // Prune selected IDs that no longer exist
        final existingIds = items.map((n) => n.serverId).toSet();
        _selectedIds.retainWhere(existingIds.contains);
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

  void _toggleSelection(AppNotification item) {
    if (!item.isDismissible) {
      AppSnackBar.show(
        context,
        AppLocalizations.of(context).cannotDeleteCritical,
        severity: AppSnackBarSeverity.warning,
      );
      return;
    }
    setState(() {
      if (_selectedIds.contains(item.serverId)) {
        _selectedIds.remove(item.serverId);
      } else {
        _selectedIds.add(item.serverId);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  Future<void> _deleteSingle(AppNotification item) async {
    if (!item.isDismissible) return;

    final l10n = AppLocalizations.of(context);
    setState(() {
      _notifications.removeWhere((n) => n.serverId == item.serverId);
      _selectedIds.remove(item.serverId);
    });

    await AppOpsService.instance.deleteNotification(item.serverId);

    if (!mounted) return;
    AppSnackBar.show(
      context,
      l10n.notificationDeleted,
      actionLabel: l10n.undo,
      onAction: () async {
        await AppOpsService.instance.restoreNotification(item);
        await _load();
      },
    );
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final l10n = AppLocalizations.of(context);
    final toDelete = _notifications
        .where((n) => _selectedIds.contains(n.serverId) && n.isDismissible)
        .toList();

    if (toDelete.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text('${toDelete.length} ${l10n.selectedCount}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _notifications.removeWhere((n) => _selectedIds.contains(n.serverId));
      _selectedIds.clear();
    });

    for (final item in toDelete) {
      await AppOpsService.instance.deleteNotification(item.serverId);
    }

    if (!mounted) return;
    AppSnackBar.show(
      context,
      l10n.notificationsDeleted,
      actionLabel: l10n.undo,
      onAction: () async {
        for (final item in toDelete) {
          await AppOpsService.instance.restoreNotification(item);
        }
        await _load();
      },
    );
  }

  Future<void> _confirmDeleteAll() async {
    final l10n = AppLocalizations.of(context);
    final dismissibleCount =
        _notifications.where((n) => n.isDismissible).length;
    if (dismissibleCount == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDeleteAll),
        content: Text(l10n.confirmDeleteAllMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.deleteAll),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final snapshot = List<AppNotification>.from(_notifications);
    await AppOpsService.instance.deleteAllNotifications(_notifications);
    await _load();

    if (!mounted) return;
    AppSnackBar.show(
      context,
      l10n.notificationsDeleted,
      actionLabel: l10n.undo,
      onAction: () async {
        for (final item in snapshot) {
          if (item.isDismissible) {
            await AppOpsService.instance.restoreNotification(item);
          }
        }
        await _load();
      },
    );
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
                  onPressed: () =>
                      _handleAction(ctx, item.actionUrl!.trim(), l10n),
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

  void _handleAction(
    BuildContext ctx,
    String actionUrl,
    AppLocalizations l10n,
  ) {
    Navigator.of(ctx).pop();
    final lower = actionUrl.toLowerCase().trim();

    if (lower == 'open_about' ||
        lower == 'about' ||
        lower == 'app://about') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AboutScreen()),
      );
      return;
    }
    if (lower == 'open_license' ||
        lower == 'license' ||
        lower == 'app://license') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LicenseScreen()),
      );
      return;
    }
    if (lower == 'open_store_listing' ||
        lower == 'store' ||
        lower == 'app://store') {
      UrlLauncherUtils.launch(context, AppConstants.playStoreUrl);
      return;
    }
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
    if (lower == 'diagnostic' ||
        lower == 'repair' ||
        lower == 'app://diagnostic') {
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

    AppSnackBar.show(
      context,
      l10n.networkError,
      severity: AppSnackBarSeverity.error,
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
    final dismissibleCount =
        _notifications.where((n) => n.isDismissible).length;

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.cancel,
                onPressed: _clearSelection,
              ),
              title: Text('${_selectedIds.length} ${l10n.selectedCount}'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.delete,
                  onPressed: _deleteSelected,
                ),
              ],
            )
          : AppBar(
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
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (val) {
                    if (val == 'mark_all_read') {
                      _markAllAsRead();
                    } else if (val == 'delete_all') {
                      _confirmDeleteAll();
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'mark_all_read',
                      enabled: unreadCount > 0,
                      child: Row(
                        children: [
                          const Icon(Icons.done_all, size: 20),
                          const SizedBox(width: 8),
                          Text(l10n.markAllRead),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete_all',
                      enabled: dismissibleCount > 0,
                      child: Row(
                        children: [
                          Icon(Icons.delete_sweep_outlined,
                              size: 20, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Text(
                            l10n.deleteAll,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
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

                        final isSelected =
                            _selectedIds.contains(item.serverId);

                        final tile = ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          selected: isSelected,
                          selectedTileColor:
                              theme.colorScheme.primary.withAlpha(20),
                          tileColor: item.isRead
                              ? null
                              : theme.colorScheme.primaryContainer.withAlpha(25),
                          leading: _isSelectionMode
                              ? Checkbox(
                                  value: isSelected,
                                  onChanged: item.isDismissible
                                      ? (_) => _toggleSelection(item)
                                      : null,
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _categoryChip(item.category, l10n)
                                  ],
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
                              Row(
                                children: [
                                  Text(
                                    dateStr,
                                    style:
                                        theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  if (!item.isDismissible) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.lock_outline,
                                      size: 12,
                                      color: Colors.red.shade400,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      l10n.categoryCritical,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                        color: Colors.red.shade400,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          trailing: _isSelectionMode
                              ? null
                              : Icon(AppIcons.chevronForward(context), size: 20),
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(item);
                            } else {
                              _openDetail(item);
                            }
                          },
                          onLongPress: () => _toggleSelection(item),
                        );

                        if (!item.isDismissible) {
                          return tile;
                        }

                        return Dismissible(
                          key: ValueKey('notif_${item.serverId}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red.shade700,
                            alignment: AlignmentDirectional.centerEnd,
                            padding: const EdgeInsetsDirectional.only(end: 20),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (_) => _deleteSingle(item),
                          child: tile,
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

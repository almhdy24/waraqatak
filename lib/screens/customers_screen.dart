import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/contact.dart';
import '../utils/error_utils.dart';
import '../utils/name_initials.dart';
import '../widgets/app_design_tokens.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading_view.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/app_snackbar.dart';
import 'contact_form_screen.dart';
import 'customer_detail_screen.dart';
import '../widgets/responsive.dart';

class CustomersScreen extends StatefulWidget {
  final int refreshToken;
  const CustomersScreen({super.key, this.refreshToken = 0});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  List<Contact>? _contacts;
  String _query = '';
  bool _activeOnly = false;
  String? _error;
  bool _isLoading = false;
  int _loadVersion = 0;

  String get _filterType => _tabCtrl.index == 0 ? 'customer' : 'supplier';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabCtrl.indexIsChanging) _load();
      });
    _load();
  }

  @override
  void didUpdateWidget(covariant CustomersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final db = DatabaseHelper.instance;
      final contacts = _query.isNotEmpty
          ? await db.searchContacts(_query,
              type: _filterType, activeOnly: _activeOnly)
          : await db.getAllContacts(
              type: _filterType, activeOnly: _activeOnly);
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _isLoading = false;
        if (_contacts == null) {
          _error = e.toString();
        }
      });
      if (_contacts != null && mounted) {
        final l10n = AppLocalizations.of(context);
        AppSnackBar.show(
          context,
          ErrorUtils.toFriendlyMessage(e, l10n),
          severity: AppSnackBarSeverity.error,
        );
      }
    }
  }

  Future<void> _toggleActive(Contact contact) async {
    final l10n = AppLocalizations.of(context);
    await DatabaseHelper.instance
        .setContactActive(contact.id!, active: !contact.active);
    if (!mounted) return;
    AppSnackBar.show(
      context,
      contact.active ? l10n.contactDeactivated : l10n.contactActivated,
    );
    _load();
  }

  Future<void> _deleteContact(Contact contact) async {
    final l10n = AppLocalizations.of(context);
    final docCount = await DatabaseHelper.instance.countContactDocuments(contact.id!);
    if (!mounted) return;
    if (docCount > 0) {
      final archive = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.customerHasDocumentsTitle),
          content: Text(l10n.customerHasDocumentsMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.archiveCustomer),
            ),
          ],
        ),
      );
      if (archive == true && mounted && contact.active) {
        await DatabaseHelper.instance.setContactActive(contact.id!, active: false);
        if (!mounted) return;
        AppSnackBar.show(
          context,
          l10n.operationSuccessful,
          severity: AppSnackBarSeverity.success,
        );
        _load();
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(l10n.deleteCustomerMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await DatabaseHelper.instance.deleteContact(contact.id!);
      if (!mounted) return;
      AppSnackBar.show(
        context,
        l10n.operationSuccessful,
        severity: AppSnackBarSeverity.success,
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        ErrorUtils.toFriendlyMessage(e, l10n),
        severity: AppSnackBarSeverity.error,
      );
    }
  }

  void _openDetail(Contact contact) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CustomerDetailScreen(contact: contact)),
    );
    _load();
  }

  void _openForm([Contact? contact]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactFormScreen(
          contact: contact,
          initialType: _filterType,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.customers),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.people_alt_outlined, size: 18),
                const SizedBox(width: 6),
                Text(l10n.customer),
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.store_outlined, size: 18),
                const SizedBox(width: 6),
                Text(l10n.supplier),
              ]),
            ),
          ],
        ),
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: AppSearchBar(
                      hintText: l10n.search,
                      onChanged: (v) {
                        _query = v;
                        _load();
                      },
                      onClear: () {
                        _query = '';
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(
                      l10n.activeOnly,
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: _activeOnly,
                    onSelected: (v) {
                      setState(() => _activeOnly = v);
                      _load();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            if (_isLoading && _contacts != null)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildList(context, l10n),
                  _buildList(context, l10n),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_customers',
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_outlined),
        label: Text(_tabCtrl.index == 0 ? l10n.addCustomer : l10n.addSupplier),
      ),
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l10n) {
    if (_error != null && _contacts == null) {
      return AppErrorState(
        message: ErrorUtils.toFriendlyMessage(_error!, l10n),
        onRetry: _load,
      );
    }
    if (_contacts == null) {
      return const AppLoadingView();
    }
    final contacts = _contacts!;
    if (contacts.isEmpty) {
      if (_query.isNotEmpty) {
        return AppEmptyState(
          icon: Icons.search_off_rounded,
          title: l10n.noSearchResults,
          description: l10n.noSearchResultsHint,
        );
      }
      return AppEmptyState(
        icon: _filterType == 'supplier' ? Icons.store_outlined : Icons.people_alt_outlined,
        title: _filterType == 'supplier' ? l10n.noSuppliers : l10n.noCustomers,
        actionLabel: _filterType == 'supplier' ? l10n.addSupplierNew : l10n.addCustomerNew,
        onAction: () => _openForm(),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
        itemCount: contacts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _ContactCard(
          contact: contacts[i],
          onTap: () => _openDetail(contacts[i]),
          onEdit: () => _openForm(contacts[i]),
          onToggleActive: () => _toggleActive(contacts[i]),
          onDelete: () => _deleteContact(contacts[i]),
        ),
      ),
    );
  }
}

// ── Contact card ──────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final Contact contact;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _ContactCard({
    required this.contact,
    required this.onTap,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  Color _avatarColor(String name, ColorScheme cs) {
    final colors = [
      cs.primary,
      cs.secondary,
      cs.tertiary,
    ];
    return colors[initialOf(name).runes.first % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final color = _avatarColor(contact.name, cs);
    final isSupplier = contact.type == 'supplier';

    return Opacity(
      opacity: contact.active ? 1.0 : 0.6,
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
              border: Border.all(
                color: contact.active
                    ? cs.outlineVariant
                    : cs.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initialOf(contact.name),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              contact.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                decoration: contact.active
                                    ? null
                                    : TextDecoration.lineThrough,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!contact.active) ...[
                            const SizedBox(width: 6),
                            _StatusBadge(l10n.inactive, cs.onSurfaceVariant),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            isSupplier
                                ? Icons.store_outlined
                                : Icons.person_outline,
                            size: 13,
                            color: color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isSupplier ? l10n.supplier : l10n.customer,
                            style: TextStyle(
                                fontSize: 12,
                                color: color,
                                fontWeight: FontWeight.w500),
                          ),
                          if (contact.phone != null) ...[
                            const SizedBox(width: 10),
                            Icon(Icons.phone_outlined,
                                size: 13, color: cs.onSurfaceVariant),
                            const SizedBox(width: 3),
                            Text(contact.phone!,
                                style: TextStyle(
                                    fontSize: 12, color: cs.onSurfaceVariant)),
                          ],
                        ],
                      ),
                      if (contact.email != null) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(Icons.email_outlined,
                              size: 13, color: cs.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Text(contact.email!,
                              style: TextStyle(
                                  fontSize: 12, color: cs.onSurfaceVariant)),
                        ]),
                      ],
                    ],
                  ),
                ),

                // Menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      color: cs.onSurfaceVariant, size: 20),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'toggle') onToggleActive();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.edit_outlined),
                        title: Text(l10n.edit),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: ListTile(
                        dense: true,
                        leading: Icon(contact.active
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        title: Text(contact.active
                            ? l10n.deactivateContact
                            : l10n.activateContact),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.delete_outline,
                            color: cs.error),
                        title: Text(l10n.delete,
                            style: TextStyle(color: cs.error)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600)),
      );
}

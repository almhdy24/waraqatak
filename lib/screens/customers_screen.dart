import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/contact.dart';
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
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _activeOnly = false;
  String? _error;

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
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _contacts = null;
      _error = null;
    });
    try {
      final db = DatabaseHelper.instance;
      final contacts = _query.isNotEmpty
          ? await db.searchContacts(_query,
              type: _filterType, activeOnly: _activeOnly)
          : await db.getAllContacts(
              type: _filterType, activeOnly: _activeOnly);
      if (!mounted) return;
      setState(() => _contacts = contacts);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _toggleActive(Contact contact) async {
    final l10n = AppLocalizations.of(context);
    await DatabaseHelper.instance
        .setContactActive(contact.id!, active: !contact.active);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          contact.active ? l10n.contactDeactivated : l10n.contactActivated),
    ));
    _load();
  }

  Future<void> _deleteContact(Contact contact) async {
    final l10n = AppLocalizations.of(context);
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
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await DatabaseHelper.instance.deleteContact(contact.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.operationSuccessful)));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.operationFailed}: $e')));
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
          builder: (_) => ContactFormScreen(contact: contact)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

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
      body: ResponsiveCenter(child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: l10n.search,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _query = '';
                                _load();
                              })
                          : null,
                      filled: true,
                      fillColor: cs.surfaceContainerLow,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) {
                      _query = v;
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.activeOnly,
                      style: const TextStyle(fontSize: 12)),
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
      )),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_customers',
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_outlined),
        label: Text(_tabCtrl.index == 0 ? l10n.customer : l10n.supplier),
      ),
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l10n) {
    if (_error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(l10n.operationFailed),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: _load, child: Text(l10n.retry)),
        ]),
      );
    }
    if (_contacts == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final contacts = _contacts!;
    if (contacts.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            _filterType == 'supplier'
                ? Icons.store_outlined
                : Icons.people_alt_outlined,
            size: 72,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            _filterType == 'supplier' ? l10n.noSuppliers : l10n.noCustomers,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: () => _openForm(),
            child: Text(_filterType == 'supplier'
                ? l10n.supplier
                : l10n.customer),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
        itemCount: contacts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  Color _avatarColor(String name, ColorScheme cs) {
    final colors = [
      cs.primary,
      Colors.teal,
      Colors.indigo,
      Colors.deepOrange,
      Colors.purple,
      Colors.green.shade700,
    ];
    return colors[name.codeUnitAt(0) % colors.length];
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
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
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
                      _initials(contact.name),
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
                            _StatusBadge(l10n.inactive, Colors.grey),
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
                            const Icon(Icons.phone_outlined,
                                size: 13, color: Colors.grey),
                            const SizedBox(width: 3),
                            Text(contact.phone!,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ],
                      ),
                      if (contact.email != null) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.email_outlined,
                              size: 13, color: Colors.grey),
                          const SizedBox(width: 3),
                          Text(contact.email!,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
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
                        leading: const Icon(Icons.delete_outline,
                            color: Colors.red),
                        title: Text(l10n.delete,
                            style:
                                const TextStyle(color: Colors.red)),
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

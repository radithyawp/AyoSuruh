import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_service.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';
import '../theme/ayo_theme.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  static Color get _brown => AyoAdaptiveColors.brown;
  static const Color _orange = Color(0xFFF6990E);
  static const Color _green = Color(0xFF5F784F);

  final AdminService _service = AdminService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _filter = 'semua';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<Map<String, dynamic>> users = await _service.fetchUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final String q = _query.trim().toLowerCase();
    return _users.where((Map<String, dynamic> user) {
      final bool isMitra = user['is_mitra'] == true;
      if (_filter == 'customer' && isMitra) return false;
      if (_filter == 'mitra' && !isMitra) return false;
      if (q.isEmpty) return true;
      final String haystack = <String>[
        (user['fullname'] ?? '').toString(),
        (user['email'] ?? '').toString(),
        (user['phone'] ?? '').toString(),
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> users = _filtered;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: _orange,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: AyoText(
                      'Manajemen Pengguna',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _brown),
                    ),
                  ),
                  IconButton(onPressed: _load, icon: Icon(Icons.refresh_rounded, color: _brown)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (String value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: AyoI18n.t('Cari nama, email, atau nomor...'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE9DED6)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                children: <Widget>[
                  _filterChip('semua', 'Semua'),
                  _filterChip('customer', 'Customer'),
                  _filterChip('mitra', 'Mitra'),
                ],
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 10),
                AyoText(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 11)),
              ],
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator(color: _orange)),
                )
              else if (users.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: AyoText('Pengguna tidak ditemukan.')),
                )
              else
                ...users.map(_userCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final bool selected = _filter == value;
    return ChoiceChip(
      selected: selected,
      label: AyoText(label),
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: const Color(0xFFE9F1E3),
      side: BorderSide(color: selected ? _green : const Color(0xFFE7DDD6)),
      labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: selected ? _green : _brown),
    );
  }

  Widget _userCard(Map<String, dynamic> user) {
    final String name = (user['fullname'] ?? 'Pengguna').toString();
    final String email = (user['email'] ?? '-').toString();
    final String phone = (user['phone'] ?? '-').toString();
    final bool isMitra = user['is_mitra'] == true;
    final bool mitraActive = user['mitra_active'] == true;
    final DateTime? created = DateTime.tryParse((user['created_at'] ?? '').toString())?.toLocal();
    final String initials = name
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .take(2)
        .map((String part) => part[0].toUpperCase())
        .join();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFEDE3DC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 22,
            backgroundColor: isMitra ? const Color(0xFFE3EFDC) : const Color(0xFFFFE4C0),
            backgroundImage: (user['avatar_url'] ?? '').toString().isEmpty
                ? null
                : NetworkImage(user['avatar_url'].toString()),
            child: (user['avatar_url'] ?? '').toString().isEmpty
                ? AyoText(initials.isEmpty ? 'U' : initials, style: TextStyle(fontWeight: FontWeight.w900, color: _brown))
                : null,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: AyoText(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isMitra ? const Color(0xFFE9F2E4) : const Color(0xFFFFF0D9),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: AyoText(
                        isMitra ? (mitraActive ? 'Mitra Aktif' : 'Mitra Nonaktif') : 'Customer',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: isMitra ? _green : _brown),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                AyoText(email, style: const TextStyle(fontSize: 10.5, color: Color(0xFF6F635C))),
                AyoText(phone, style: const TextStyle(fontSize: 10.5, color: Color(0xFF6F635C))),
                if (created != null) ...<Widget>[
                  const SizedBox(height: 5),
                  AyoText('Terdaftar ${DateFormat('dd MMM yyyy').format(created)}', style: TextStyle(fontSize: 9.5, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.78))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import 'chats/chat_detail_page.dart';
import 'chats/chat_helpers.dart';
import 'chats/chat_service.dart';
import 'chats/presence_service.dart';
import 'jobs/job_helpers.dart';
import 'services/service_marketplace_page.dart';
import 'widgets/ayo_empty_state.dart';
import 'widgets/ayo_crystal.dart';
import 'notification.dart';
import 'widgets/ayo_avatar.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    this.tutorialKey,
    this.firstActionTutorialKey,
    this.activeMode = 'customer',
  });

  final Key? tutorialKey;
  final Key? firstActionTutorialKey;
  final String activeMode;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  final PresenceService _presenceService = PresenceService();

  StreamSubscription<List<Map<String, dynamic>>>? _messageSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _presenceSubscription;
  Timer? _presenceFreshnessTimer;
  List<Map<String, dynamic>> _rooms = <Map<String, dynamic>>[];
  final Map<String, Map<String, dynamic>> _presenceByUser =
      <String, Map<String, dynamic>>{};
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  String _query = '';
  bool _headerScrolled = false;

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _messageSubscription = _chatService.visibleMessagesStream().listen(
      (_) => _loadRooms(silent: true),
      onError: (_) {},
    );
    _presenceSubscription = _presenceService.visiblePresenceStream().listen(
      (List<Map<String, dynamic>> rows) {
        if (!mounted) return;
        setState(() {
          _presenceByUser
            ..clear()
            ..addEntries(rows.map((row) => MapEntry(
                  (row['user_id'] ?? '').toString(),
                  Map<String, dynamic>.from(row),
                )));
        });
      },
      onError: (_) {},
    );
    _presenceFreshnessTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (mounted && _presenceByUser.isNotEmpty) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _presenceSubscription?.cancel();
    _presenceFreshnessTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms({bool silent = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<Map<String, dynamic>> rooms =
          await _chatService.fetchMyRooms();
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _openRoom(Map<String, dynamic> room) async {
    final String? roomId = room['room_id']?.toString();
    if (roomId == null || roomId.isEmpty) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ChatDetailPage(
          roomId: roomId,
          initialRoom: room,
        ),
      ),
    );
    await _loadRooms(silent: true);
  }

  Future<void> _openServiceMarketplace() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const ServiceMarketplacePage(),
      ),
    );
    if (mounted) await _loadRooms(silent: true);
  }

  List<Map<String, dynamic>> get _filteredRooms {
    final String query = _query.trim().toLowerCase();
    if (query.isEmpty) return _rooms;
    return _rooms.where((Map<String, dynamic> room) {
      final String partner = (room['partner_name'] ?? '').toString().toLowerCase();
      final String job = (room['job_title'] ?? '').toString().toLowerCase();
      final String message = (room['last_message'] ?? '').toString().toLowerCase();
      return partner.contains(query) ||
          job.contains(query) ||
          message.contains(query);
    }).toList();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final bool scrolled = notification.metrics.pixels > 8;
    if (scrolled != _headerScrolled && mounted) {
      setState(() => _headerScrolled = scrolled);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AyoGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: AyoCrystalBarLayer(scrolled: _headerScrolled),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 10, 2),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: AyoText(
                                'Chat',
                                style: TextStyle(
                                  color: jobBrownColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            NotificationBell(
                              color: jobDarkBrownColor,
                              activeMode: widget.activeMode,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: AyoText(
                          'Koordinasikan pekerjaan dengan customer atau mitra.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      KeyedSubtree(
                        key: widget.tutorialKey,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                          child: AyoCrystalSurface(
                            intensity: _headerScrolled ? 0.92 : 0.60,
                            blurSigma: _headerScrolled ? 18 : 8,
                            elevated: _headerScrolled,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(16),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (String value) =>
                                  setState(() => _query = value),
                              decoration: InputDecoration(
                                hintText: AyoI18n.t('Cari nama atau pekerjaan...'),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                suffixIcon: _query.isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _query = '');
                                        },
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                filled: false,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleScrollNotification,
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: jobOrangeColor),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: AyoEmptyState(
          compact: true,
          assetPath: 'assets/images/ayos/ayos_sorry.png',
          badgeIcon: Icons.error_outline_rounded,
          title: AyoI18n.t('Chat belum dapat dimuat'),
          description: AyoI18n.t(
            'Periksa koneksi lalu coba muat ulang percakapan.',
          ),
          action: FilledButton.icon(
            onPressed: _loadRooms,
            icon: const Icon(Icons.refresh_rounded),
            label: const AyoText('Coba Lagi'),
          ),
        ),
      );
    }

    final List<Map<String, dynamic>> rooms = _filteredRooms;
    if (rooms.isEmpty) {
      return RefreshIndicator(
        color: jobOrangeColor,
        onRefresh: _loadRooms,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 112),
          children: <Widget>[
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.13),
            AyoEmptyState(
              compact: true,
              assetPath: _query.isNotEmpty
                  ? 'assets/images/ayos/ayos_search.png'
                  : widget.activeMode == 'mitra'
                      ? 'assets/images/ayos/ayos_support_headset.png'
                      : 'assets/images/ayos/ayos_chat_phone.png',
              badgeIcon: Icons.forum_outlined,
              title: AyoI18n.t(
                _query.isEmpty
                    ? (widget.activeMode == 'mitra'
                        ? 'Belum ada percakapan dengan Customer'
                        : 'Belum ada percakapan')
                    : 'Percakapan tidak ditemukan',
              ),
              description: AyoI18n.t(
                _query.isEmpty
                    ? (widget.activeMode == 'mitra'
                        ? 'Chat akan tersedia setelah Customer memilih penawaranmu atau pekerjaan diterima.'
                        : 'Chat tersedia setelah Customer terhubung dengan Mitra dalam suatu pekerjaan.')
                    : 'Coba nama Customer, Mitra, atau judul pekerjaan lainnya.',
              ),
            ),
            if (_query.isEmpty && widget.activeMode == 'customer') ...<Widget>[
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 34),
                child: KeyedSubtree(
                  key: widget.firstActionTutorialKey,
                  child: FilledButton.icon(
                    onPressed: _openServiceMarketplace,
                    icon: const Icon(Icons.search_rounded),
                    label: const AyoText(
                      'Mulai Chat Pertamamu',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: jobOrangeColor,
      onRefresh: _loadRooms,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 116),
        itemCount: rooms.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: 9),
        itemBuilder: (BuildContext context, int index) =>
            _chatRoomCard(rooms[index]),
      ),
    );
  }

  Widget _chatRoomCard(Map<String, dynamic> room) {
    final String partnerName =
        (room['partner_name'] ?? 'Pengguna Ayo Suruh').toString();
    final String jobTitle = (room['job_title'] ?? 'Pekerjaan').toString();
    final String status = (room['job_status'] ?? '').toString();
    final String? avatarUrl = room['partner_avatar_url']?.toString();
    final String lastMessage =
        (room['last_message'] ?? 'Belum ada pesan. Mulai percakapan sekarang.')
            .toString();
    final dynamic lastTime = room['last_message_at'] ?? room['updated_at'];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openRoom(room),
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  AyoAvatar(
                    imageUrl: avatarUrl,
                    size: 50,
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : const Color(0xFFFFE7C5),
                    logoPadding: 8,
                  ),
                  if (_presenceService.isOnline(
                    _presenceByUser[(room['partner_id'] ?? '').toString()],
                  ))
                    Positioned(
                      right: -1,
                      bottom: 1,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: const Color(0xFF38A169),
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              AyoText(
                                partnerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2F2A28),
                                ),
                              ),
                              AyoText(
                                _presenceService.presenceLabel(
                                  _presenceByUser[(room['partner_id'] ?? '').toString()],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 8.8,
                                  fontWeight: FontWeight.w700,
                                  color: _presenceService.isOnline(
                                    _presenceByUser[(room['partner_id'] ?? '').toString()],
                                  )
                                      ? const Color(0xFF2F855A)
                                      : const Color(0xFF9A8F88),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        AyoText(
                          chatListTime(lastTime),
                          style: const TextStyle(
                            color: Color(0xFF948880),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: AyoText(
                            jobTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: jobBrownColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (status.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(left: 7),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: jobStatusBackground(status),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: AyoText(
                              jobStatusLabel(status),
                              style: TextStyle(
                                color: jobStatusForeground(status),
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AyoText(
                      lastMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF766B64),
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

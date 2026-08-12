import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../jobs/job_helpers.dart';
import '../widgets/ayo_snackbar.dart';
import '../widgets/ayo_avatar.dart';
import '../widgets/ayo_empty_state.dart';
import 'chat_helpers.dart';
import 'chat_service.dart';
import 'presence_service.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({
    super.key,
    required this.roomId,
    this.initialRoom,
  });

  final String roomId;
  final Map<String, dynamic>? initialRoom;

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final ChatService _chatService = ChatService();
  final PresenceService _presenceService = PresenceService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  late final Stream<List<Map<String, dynamic>>> _messagesStream;

  Map<String, dynamic>? _room;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploadingAttachment = false;
  bool _isMarkingRead = false;
  int _lastMessageCount = -1;
  StreamSubscription<List<Map<String, dynamic>>>? _presenceSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _typingSubscription;
  Timer? _typingIdleTimer;
  Timer? _partnerTypingExpiryTimer;
  Timer? _presenceFreshnessTimer;
  Map<String, dynamic>? _partnerPresence;
  bool _partnerTyping = false;
  bool _selfTyping = false;

  @override
  void initState() {
    super.initState();
    _messagesStream = _chatService.messagesStream(widget.roomId);
    _presenceFreshnessTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (mounted && _partnerPresence != null) setState(() {});
      },
    );
    if (widget.initialRoom != null) {
      _room = Map<String, dynamic>.from(widget.initialRoom!);
      _isLoading = false;
      _subscribePartnerState();
    }
    _loadHeader();
  }

  @override
  void dispose() {
    _typingIdleTimer?.cancel();
    _partnerTypingExpiryTimer?.cancel();
    _presenceFreshnessTimer?.cancel();
    _presenceSubscription?.cancel();
    _typingSubscription?.cancel();
    if (_selfTyping) {
      unawaited(_chatService.setTyping(roomId: widget.roomId, isTyping: false));
    }
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHeader() async {
    try {
      final Map<String, dynamic> room =
          await _chatService.fetchRoomHeader(widget.roomId);
      if (!mounted) return;
      setState(() {
        _room = room;
        _errorMessage = null;
        _isLoading = false;
      });
      _subscribePartnerState();
      await _markMessagesRead();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  void _subscribePartnerState() {
    final String partnerId = (_room?['partner_id'] ?? '').toString();
    if (partnerId.isEmpty) return;

    _presenceSubscription?.cancel();
    _typingSubscription?.cancel();

    _presenceSubscription = _presenceService.userPresenceStream(partnerId).listen(
      (List<Map<String, dynamic>> rows) {
        if (!mounted) return;
        setState(() {
          _partnerPresence = rows.isEmpty
              ? null
              : Map<String, dynamic>.from(rows.first);
        });
      },
      onError: (_) {},
    );

    _typingSubscription = _chatService.typingStream(widget.roomId).listen(
      (List<Map<String, dynamic>> rows) {
        if (!mounted) return;
        final DateTime now = DateTime.now().toUtc();
        final bool typing = rows.any((Map<String, dynamic> row) {
          if ((row['user_id'] ?? '').toString() != partnerId ||
              row['is_typing'] != true) {
            return false;
          }
          final DateTime? updatedAt = DateTime.tryParse(
            (row['updated_at'] ?? '').toString(),
          )?.toUtc();
          return updatedAt != null &&
              now.difference(updatedAt) < const Duration(seconds: 5);
        });
        _partnerTypingExpiryTimer?.cancel();
        if (typing != _partnerTyping) {
          setState(() => _partnerTyping = typing);
        }
        if (typing) {
          _partnerTypingExpiryTimer = Timer(
            const Duration(seconds: 5),
            () {
              if (mounted && _partnerTyping) {
                setState(() => _partnerTyping = false);
              }
            },
          );
        }
      },
      onError: (_) {},
    );
  }

  void _handleComposerChanged(String value) {
    final bool shouldType = value.trim().isNotEmpty;
    _typingIdleTimer?.cancel();

    if (shouldType && !_selfTyping) {
      _selfTyping = true;
      unawaited(_chatService.setTyping(
        roomId: widget.roomId,
        isTyping: true,
      ));
    } else if (!shouldType && _selfTyping) {
      _selfTyping = false;
      unawaited(_chatService.setTyping(
        roomId: widget.roomId,
        isTyping: false,
      ));
    }

    if (shouldType) {
      _typingIdleTimer = Timer(const Duration(milliseconds: 1600), () {
        if (!_selfTyping) return;
        _selfTyping = false;
        unawaited(_chatService.setTyping(
          roomId: widget.roomId,
          isTyping: false,
        ));
      });
    }
  }

  void _clearTypingState() {
    _typingIdleTimer?.cancel();
    if (!_selfTyping) return;
    _selfTyping = false;
    unawaited(_chatService.setTyping(
      roomId: widget.roomId,
      isTyping: false,
    ));
  }

  Future<void> _sendMessage() async {
    final String message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await _chatService.sendMessage(
        roomId: widget.roomId,
        message: message,
      );
      _messageController.clear();
      _clearTypingState();
      _messageFocusNode.requestFocus();
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, 'Pesan belum berhasil dikirim: $error');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _markMessagesRead() async {
    if (_isMarkingRead) return;
    _isMarkingRead = true;
    try {
      await _chatService.markRoomMessagesRead(widget.roomId);
    } catch (_) {
      // Read receipt tidak boleh mengganggu percakapan utama.
    } finally {
      _isMarkingRead = false;
    }
  }

  void _handleIncomingMessages(List<Map<String, dynamic>> messages) {
    final bool hasUnreadIncoming = messages.any(
      (Map<String, dynamic> message) =>
          message['sender_id']?.toString() != _chatService.currentUserId &&
          message['read_at'] == null,
    );
    if (!hasUnreadIncoming) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _markMessagesRead();
    });
  }

  Future<void> _pickAndSendImage() async {
    if (_isUploadingAttachment || _isSending) return;

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const AyoText(
                  'Kirim Lampiran',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFFFFE8C8),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      color: jobBrownColor,
                    ),
                  ),
                  title: const AyoText('Ambil foto dari kamera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEAF3E4),
                    child: Icon(
                      Icons.photo_library_outlined,
                      color: Color(0xFF587348),
                    ),
                  ),
                  title: const AyoText('Pilih foto dari galeri'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (image == null || !mounted) return;

      final Uint8List bytes = await image.readAsBytes();
      if (!mounted) return;

      final String? caption = await _showImagePreview(
        bytes: bytes,
        fileName: image.name,
      );
      if (caption == null || !mounted) return;

      setState(() => _isUploadingAttachment = true);
      final String contentType = _imageContentType(image.name);
      final String url = await _chatService.uploadChatImage(
        roomId: widget.roomId,
        bytes: bytes,
        fileName: image.name,
        contentType: contentType,
      );
      await _chatService.sendImageMessage(
        roomId: widget.roomId,
        attachmentUrl: url,
        attachmentName: image.name,
        attachmentMimeType: contentType,
        attachmentSize: bytes.lengthInBytes,
        caption: caption,
      );
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, 'Foto belum berhasil dikirim: $error');
    } finally {
      if (mounted) setState(() => _isUploadingAttachment = false);
    }
  }

  Future<String?> _showImagePreview({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final TextEditingController captionController = TextEditingController();
    final String? result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            0,
            18,
            MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const AyoText(
                'Pratinjau Foto',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    bytes,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: captionController,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: AyoI18n.t('Tambahkan keterangan (opsional)'),
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF8F3F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  captionController.text.trim(),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: jobOrangeColor,
                  foregroundColor: const Color(0xFF4E3400),
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.send_rounded),
                label: AyoText('Kirim ${fileName.isEmpty ? 'Foto' : fileName}'),
              ),
            ],
          ),
        );
      },
    );
    captionController.dispose();
    return result;
  }

  String _imageContentType(String fileName) {
    final String extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _callPartner() async {
    final bool canCall = _room?['can_call'] == true;
    final String partnerName =
        (_room?['partner_name'] ?? 'pengguna').toString().trim();
    final String rawPhone =
        (_room?['partner_phone'] ?? '').toString().trim();

    if (!canCall || rawPhone.isEmpty) {
      if (!mounted) return;
      AyoSnackBar.info(
        context,
        'Telepon hanya tersedia saat pekerjaan masih aktif dan nomor lawan transaksi tersedia.',
      );
      return;
    }

    final String phone = _sanitizePhoneForDialer(rawPhone);
    if (phone.isEmpty) {
      if (!mounted) return;
      AyoSnackBar.error(
        context,
        'Nomor telepon $partnerName belum valid.',
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: <Widget>[
              Icon(Icons.call_rounded, color: jobOrangeColor),
              SizedBox(width: 10),
              Expanded(child: AyoText('Telepon sekarang?')),
            ],
          ),
          content: AyoText(
            'Kamu akan membuka aplikasi Telepon untuk menghubungi '
            '$partnerName. Gunakan panggilan hanya untuk koordinasi '
            'pekerjaan aktif. Biaya operator dapat berlaku.',
            style: const TextStyle(height: 1.45),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AyoText('Batal'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: jobOrangeColor,
                foregroundColor: const Color(0xFF4E3400),
              ),
              icon: const Icon(Icons.call_rounded),
              label: const AyoText(
                'Telepon',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final Uri uri = Uri(
      scheme: 'tel',
      path: phone,
    );

    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        AyoSnackBar.error(
          context,
          'Aplikasi Telepon belum dapat dibuka di perangkat ini.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(
        context,
        'Panggilan belum dapat dibuka: $error',
      );
    }
  }

  String _sanitizePhoneForDialer(String value) {
    String phone = value.replaceAll(RegExp(r'[^0-9+]'), '');

    if (phone.startsWith('00')) {
      phone = '+${phone.substring(2)}';
    }

    // Tanda + hanya valid di karakter pertama.
    if (phone.length > 1) {
      phone = '${phone.startsWith('+') ? '+' : ''}'
          '${phone.replaceAll('+', '')}';
    }

    return phone;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: jobBackgroundColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final String partnerName =
        (_room?['partner_name'] ?? 'Percakapan').toString();
    final String? avatarUrl = _room?['partner_avatar_url']?.toString();

    return AppBar(
      backgroundColor: jobBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context, true),
        icon: Icon(Icons.arrow_back_rounded, color: jobBrownColor),
      ),
      titleSpacing: 0,
      title: Row(
        children: <Widget>[
          AyoAvatar(
            imageUrl: avatarUrl,
            size: 38,
            backgroundColor: const Color(0xFFFFE7C5),
            logoPadding: 6,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AyoText(
                  partnerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF2B2725),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                AyoText(
                  _partnerTyping
                      ? 'sedang mengetik…'
                      : _presenceService.presenceLabel(_partnerPresence),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _partnerTyping
                        ? jobOrangeColor
                        : _presenceService.isOnline(_partnerPresence)
                            ? const Color(0xFF2F855A)
                            : const Color(0xFF857870),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      actions: <Widget>[
        if (_room?['can_call'] == true)
          IconButton(
            tooltip: AyoI18n.t('Telepon'),
            onPressed: _callPartner,
            icon: Icon(
              Icons.call_rounded,
              color: jobBrownColor,
            ),
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: jobOrangeColor),
      );
    }

    if (_errorMessage != null || _room == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: jobBrownColor,
              ),
              const SizedBox(height: 12),
              AyoText(
                _errorMessage ?? 'Percakapan tidak ditemukan.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _loadHeader,
                child: const AyoText('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        _jobContextBar(),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _messagesStream,
            builder: (
              BuildContext context,
              AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AyoText(
                      'Pesan belum dapat dimuat: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: jobOrangeColor),
                );
              }

              final List<Map<String, dynamic>> messages = snapshot.data!;
              _handleIncomingMessages(messages);
              if (_lastMessageCount != messages.length) {
                _lastMessageCount = messages.length;
                _scrollToBottom();
              }

              if (messages.isEmpty) return _emptyConversation();

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                itemCount: messages.length,
                itemBuilder: (BuildContext context, int index) {
                  final Map<String, dynamic> message = messages[index];
                  final bool showDay = index == 0 ||
                      !isSameChatDay(
                        messages[index - 1]['created_at'],
                        message['created_at'],
                      );
                  return Column(
                    children: <Widget>[
                      if (showDay) _dayDivider(message['created_at']),
                      _messageBubble(message),
                    ],
                  );
                },
              );
            },
          ),
        ),
        _composer(),
      ],
    );
  }

  Widget _jobContextBar() {
    final String jobTitle = (_room?['job_title'] ?? 'Pekerjaan').toString();
    final String jobStatus = (_room?['job_status'] ?? '').toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0E9E4)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.work_outline_rounded, size: 17, color: jobBrownColor),
          const SizedBox(width: 8),
          Expanded(
            child: AyoText(
              jobTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5F544E),
              ),
            ),
          ),
          if (jobStatus.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: jobStatusBackground(jobStatus),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AyoText(
                jobStatusLabel(jobStatus),
                style: TextStyle(
                  color: jobStatusForeground(jobStatus),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyConversation() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
        child: const AyoEmptyState(
          assetPath: 'assets/images/ayos/ayos_chat_phone.png',
          badgeIcon: Icons.forum_outlined,
          compact: true,
          title: 'Mulai percakapan',
          description:
              'Gunakan chat ini untuk mengonfirmasi lokasi, jadwal, dan kebutuhan pekerjaan.',
        ),
      ),
    );
  }

  Widget _dayDivider(dynamic createdAt) {
    final DateTime? date = parseChatDate(createdAt);
    if (date == null) return const SizedBox(height: 6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          const Expanded(child: Divider(color: Color(0xFFE9E1DD))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: AyoText(
              chatDayLabel(date),
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF8A7F78),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFFE9E1DD))),
        ],
      ),
    );
  }

  Widget _messageBubble(Map<String, dynamic> message) {
    final bool isMine =
        message['sender_id']?.toString() == _chatService.currentUserId;
    final String text = (message['message'] ?? '').toString();
    final String attachmentUrl =
        (message['attachment_url'] ?? '').toString().trim();
    final bool hasAttachment = attachmentUrl.isNotEmpty;
    final bool showText = text.trim().isNotEmpty &&
        !(hasAttachment && text.trim().toLowerCase() == 'foto');

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.fromLTRB(
          hasAttachment ? 5 : 13,
          hasAttachment ? 5 : 10,
          hasAttachment ? 5 : 11,
          7,
        ),
        decoration: BoxDecoration(
          color: isMine ? jobOrangeColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(isMine ? 15 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 15),
          ),
          border: isMine ? null : Border.all(color: const Color(0xFFECE5E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            if (hasAttachment)
              GestureDetector(
                onTap: () => _openImageViewer(attachmentUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 170,
                      maxWidth: 300,
                      maxHeight: 300,
                    ),
                    child: Image.network(
                      attachmentUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (
                        BuildContext context,
                        Widget child,
                        ImageChunkEvent? progress,
                      ) {
                        if (progress == null) return child;
                        return SizedBox(
                          width: 220,
                          height: 160,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: jobBrownColor,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, Object error, StackTrace? stackTrace) {
                        return const SizedBox(
                          width: 220,
                          height: 130,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.broken_image_outlined),
                                SizedBox(height: 5),
                                AyoText('Foto tidak dapat dimuat'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            if (hasAttachment && showText) const SizedBox(height: 7),
            if (showText)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: hasAttachment ? 7 : 0,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AyoText(
                    text,
                    style: TextStyle(
                      color: isMine
                          ? const Color(0xFF4B3100)
                          : const Color(0xFF403936),
                      fontSize: 12,
                      height: 1.42,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 3),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: hasAttachment ? 6 : 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AyoText(
                    chatBubbleTime(message['created_at']),
                    style: TextStyle(
                      color: isMine
                          ? const Color(0xFF79550B)
                          : const Color(0xFF9A8F88),
                      fontSize: 8,
                    ),
                  ),
                  if (isMine) ...<Widget>[
                    const SizedBox(width: 5),
                    _deliveryIndicator(message),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deliveryIndicator(Map<String, dynamic> message) {
    final bool isRead = message['read_at'] != null;
    final bool isDelivered = message['delivered_at'] != null;

    final String label;
    final IconData icon;
    final Color color;
    if (isRead) {
      label = 'Dibaca';
      icon = Icons.done_all_rounded;
      color = const Color(0xFF2F6F45);
    } else if (isDelivered) {
      label = 'Sampai';
      icon = Icons.done_all_rounded;
      color = const Color(0xFF79550B);
    } else {
      label = 'Terkirim';
      icon = Icons.done_rounded;
      color = const Color(0xFF79550B);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 2),
        AyoText(
          label,
          style: TextStyle(
            color: color,
            fontSize: 7.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Future<void> _openImageViewer(String url) async {
    await showDialog<void>(
      context: context,
      barrierColor: Theme.of(context).colorScheme.onSurface,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.black,
          child: SizedBox.expand(
            child: SafeArea(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Center(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, Object error, StackTrace? stackTrace) {
                          return const AyoText(
                            'Foto tidak dapat dimuat.',
                            style: TextStyle(color: Colors.white),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  Widget _composer() {
    final bool isBusy = _isSending || _isUploadingAttachment;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Color(0xFFECE5E1)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            IconButton(
              onPressed: isBusy ? null : _pickAndSendImage,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF6F0F2),
                foregroundColor: jobBrownColor,
                disabledForegroundColor: const Color(0xFFB8ADA7),
                fixedSize: const Size(40, 40),
              ),
              tooltip: AyoI18n.t('Kirim foto'),
              icon: _isUploadingAttachment
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: jobBrownColor,
                      ),
                    )
                  : const Icon(Icons.add_rounded, size: 22),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                onChanged: _handleComposerChanged,
                onSubmitted: (_) {
                  if (!isBusy) _sendMessage();
                },
                decoration: InputDecoration(
                  hintText: AyoI18n.t('Ketik pesan...'),
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF8F3F6),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: isBusy ? null : _sendMessage,
              style: IconButton.styleFrom(
                backgroundColor: jobOrangeColor,
                foregroundColor: const Color(0xFF4E3400),
                disabledBackgroundColor: const Color(0xFFFFD99F),
              ),
              icon: _isSending
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF4E3400),
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}

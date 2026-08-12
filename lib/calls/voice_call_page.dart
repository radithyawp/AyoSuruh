import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../jobs/job_helpers.dart';
import '../l10n/ayo_localization.dart';
import '../widgets/ayo_avatar.dart';
import '../widgets/ayo_snackbar.dart';
import 'voice_call_service.dart';

class VoiceCallPage extends StatefulWidget {
  const VoiceCallPage({
    super.key,
    required this.callId,
    this.initialCall,
    this.incoming = false,
  });

  final String callId;
  final Map<String, dynamic>? initialCall;
  final bool incoming;

  static final Set<String> _openCallIds = <String>{};

  static bool isOpen(String callId) => _openCallIds.contains(callId);

  static bool tryReserve(String callId) => _openCallIds.add(callId);

  static void release(String callId) => _openCallIds.remove(callId);

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> {
  final VoiceCallService _service = VoiceCallService();

  Map<String, dynamic>? _call;
  StreamSubscription<Map<String, dynamic>?>? _callSubscription;
  EventsListener<RoomEvent>? _roomListener;
  Room? _room;
  Timer? _durationTicker;
  Timer? _ringExpiryTimer;

  bool _loading = true;
  bool _responding = false;
  bool _joiningRoom = false;
  bool _roomConnected = false;
  bool _remoteParticipantPresent = false;
  bool _muted = false;
  bool _speakerOn = false;
  bool _reconnecting = false;
  bool _closing = false;
  bool _disposed = false;
  String? _errorMessage;
  Duration _duration = Duration.zero;

  static const Set<String> _terminalStatuses = <String>{
    'declined',
    'cancelled',
    'ended',
    'missed',
  };

  @override
  void initState() {
    super.initState();
    VoiceCallPage._openCallIds.add(widget.callId);
    if (widget.initialCall != null) {
      _call = Map<String, dynamic>.from(widget.initialCall!);
      _loading = false;
    }
    _callSubscription = _service.callStream(widget.callId).listen(
      _handleCallUpdate,
      onError: (Object error) {
        if (!mounted) {
          return;
        }
        setState(() => _errorMessage = _friendlyError(error));
      },
    );
    unawaited(_hydrateCall());
  }

  @override
  void dispose() {
    _disposed = true;
    VoiceCallPage.release(widget.callId);
    _durationTicker?.cancel();
    _ringExpiryTimer?.cancel();
    _callSubscription?.cancel();
    _roomListener?.dispose();
    unawaited(_disposeRoom());
    super.dispose();
  }

  Future<void> _hydrateCall() async {
    try {
      final Map<String, dynamic> call = await _service.fetchCall(widget.callId);
      if (!mounted) {
        return;
      }
      setState(() {
        _call = call;
        _loading = false;
        _errorMessage = null;
      });
      _syncFromCall(call);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = _friendlyError(error);
      });
    }
  }

  void _handleCallUpdate(Map<String, dynamic>? raw) {
    if (!mounted || raw == null) {
      return;
    }
    final Map<String, dynamic> merged = <String, dynamic>{
      ...?_call,
      ...raw,
    };
    setState(() => _call = merged);
    _syncFromCall(merged);
  }

  void _syncFromCall(Map<String, dynamic> call) {
    final String status = _statusOf(call);

    if (status == 'ringing') {
      _scheduleRingingExpiry(call);
      return;
    }

    _ringExpiryTimer?.cancel();

    if (status == 'accepted' || status == 'ongoing') {
      unawaited(_connectToLiveKitIfNeeded());
      _startDurationTicker();
      return;
    }

    if (_terminalStatuses.contains(status)) {
      _durationTicker?.cancel();
      if (_room != null) {
        unawaited(_disposeRoom());
      }
    }
  }

  void _scheduleRingingExpiry(Map<String, dynamic> call) {
    _ringExpiryTimer?.cancel();
    final DateTime? expiresAt = _date(call['expires_at']);
    if (expiresAt == null) {
      return;
    }
    final Duration delay = expiresAt.difference(DateTime.now());
    if (delay <= Duration.zero) {
      unawaited(_refreshExpiredCall());
      return;
    }
    _ringExpiryTimer = Timer(delay + const Duration(milliseconds: 250), () {
      unawaited(_refreshExpiredCall());
    });
  }

  Future<void> _refreshExpiredCall() async {
    try {
      final Map<String, dynamic> call = await _service.fetchCall(widget.callId);
      if (!mounted) {
        return;
      }
      setState(() => _call = call);
      _syncFromCall(call);
    } catch (_) {
      // Realtime atau aksi pengguna tetap dapat menyelesaikan state panggilan.
    }
  }

  Future<void> _acceptCall() async {
    if (_responding) {
      return;
    }
    setState(() => _responding = true);

    try {
      final bool allowed = await _service.ensureCallPermissions();
      if (!allowed) {
        if (mounted) {
          AyoSnackBar.info(
            context,
            'Izinkan mikrofon agar panggilan suara dapat digunakan.',
          );
        }
        return;
      }

      final Map<String, dynamic> call = await _service.respond(
        callId: widget.callId,
        accept: true,
      );
      if (!mounted) {
        return;
      }
      setState(() => _call = call);
      _syncFromCall(call);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AyoSnackBar.error(context, _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _responding = false);
      }
    }
  }

  Future<void> _declineCall() async {
    if (_responding) {
      return;
    }
    setState(() => _responding = true);
    try {
      final Map<String, dynamic> call = await _service.respond(
        callId: widget.callId,
        accept: false,
      );
      if (!mounted) {
        return;
      }
      setState(() => _call = call);
      _syncFromCall(call);
    } catch (error) {
      if (mounted) {
        AyoSnackBar.error(context, _friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _responding = false);
      }
    }
  }

  Future<void> _cancelOutgoing() async {
    if (_closing) {
      return;
    }
    setState(() => _closing = true);
    try {
      final Map<String, dynamic> call = await _service.cancel(widget.callId);
      if (!mounted) {
        return;
      }
      setState(() => _call = call);
      _syncFromCall(call);
    } catch (error) {
      if (mounted) {
        AyoSnackBar.error(context, _friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _closing = false);
      }
    }
  }

  Future<void> _endCall() async {
    if (_closing) {
      return;
    }
    setState(() => _closing = true);
    try {
      await _disposeRoom();
      final Map<String, dynamic> call = await _service.end(widget.callId);
      if (!mounted) {
        return;
      }
      setState(() => _call = call);
      _syncFromCall(call);
    } catch (error) {
      if (mounted) {
        AyoSnackBar.error(context, _friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _closing = false);
      }
    }
  }

  Future<void> _connectToLiveKitIfNeeded() async {
    if (_joiningRoom || _roomConnected || _disposed) {
      return;
    }
    final String status = _statusOf(_call);
    if (status != 'accepted' && status != 'ongoing') {
      return;
    }

    _joiningRoom = true;
    if (mounted) {
      setState(() => _errorMessage = null);
    }

    try {
      final bool allowed = await _service.ensureCallPermissions();
      if (!allowed) {
        throw StateError('Izin mikrofon diperlukan untuk panggilan suara.');
      }

      final LiveKitCallCredentials credentials =
          await _service.fetchLiveKitCredentials(widget.callId);
      if (_disposed) {
        return;
      }

      final Room room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      _room = room;
      _roomListener = room.createListener()
        ..on<ParticipantConnectedEvent>((ParticipantConnectedEvent event) {
          if (!mounted) {
            return;
          }
          setState(() {
            _remoteParticipantPresent = true;
            _reconnecting = false;
          });
          unawaited(_markConnectedBestEffort());
        })
        ..on<ParticipantDisconnectedEvent>((ParticipantDisconnectedEvent event) {
          if (!mounted) {
            return;
          }
          setState(() => _remoteParticipantPresent = false);
          if (_statusOf(_call) == 'ongoing') {
            unawaited(_endAfterRemoteLeave());
          }
        })
        ..on<RoomReconnectingEvent>((RoomReconnectingEvent event) {
          if (mounted) {
            setState(() => _reconnecting = true);
          }
        })
        ..on<RoomReconnectedEvent>((RoomReconnectedEvent event) {
          if (mounted) {
            setState(() => _reconnecting = false);
          }
        })
        ..on<RoomDisconnectedEvent>((RoomDisconnectedEvent event) {
          if (!mounted || _closing || _disposed) {
            return;
          }
          setState(() {
            _roomConnected = false;
            _remoteParticipantPresent = false;
          });
        });

      await room.connect(
        credentials.serverUrl,
        credentials.participantToken,
      );
      if (_disposed) {
        await _disposeRoom();
        return;
      }

      await AudioManager.instance.setSpeakerOutputPreferred(false);
      await room.localParticipant?.setMicrophoneEnabled(true);

      final bool hasRemote = room.remoteParticipants.isNotEmpty;
      if (mounted) {
        setState(() {
          _roomConnected = true;
          _remoteParticipantPresent = hasRemote;
          _speakerOn = false;
          _muted = false;
          _reconnecting = false;
        });
      }
      if (hasRemote) {
        await _markConnectedBestEffort();
      }
    } catch (error) {
      await _disposeRoom();
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = _friendlyError(error));
    } finally {
      _joiningRoom = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _markConnectedBestEffort() async {
    if (_statusOf(_call) == 'ongoing') {
      return;
    }
    try {
      final Map<String, dynamic> call =
          await _service.markConnected(widget.callId);
      if (!mounted) {
        return;
      }
      setState(() => _call = call);
      _startDurationTicker();
    } catch (_) {
      // Media tetap dapat berjalan; Realtime akan menyelaraskan state berikutnya.
    }
  }

  Future<void> _endAfterRemoteLeave() async {
    // Beri ruang untuk reconnect singkat agar perubahan jaringan tidak langsung
    // dianggap sebagai hang-up dari lawan bicara.
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted || _closing || _statusOf(_call) != 'ongoing') {
      return;
    }
    if (_reconnecting || (_room?.remoteParticipants.isNotEmpty ?? false)) {
      return;
    }
    await _endCall();
  }

  Future<void> _toggleMute() async {
    final LocalParticipant? participant = _room?.localParticipant;
    if (participant == null) {
      return;
    }
    final bool nextMuted = !_muted;
    try {
      await participant.setMicrophoneEnabled(!nextMuted);
      if (mounted) {
        setState(() => _muted = nextMuted);
      }
    } catch (error) {
      if (mounted) {
        AyoSnackBar.error(context, _friendlyError(error));
      }
    }
  }

  Future<void> _toggleSpeaker() async {
    final bool next = !_speakerOn;
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(next);
      if (mounted) {
        setState(() => _speakerOn = next);
      }
    } catch (error) {
      if (mounted) {
        AyoSnackBar.error(context, _friendlyError(error));
      }
    }
  }

  void _startDurationTicker() {
    _durationTicker?.cancel();
    _updateDuration();
    _durationTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateDuration(),
    );
  }

  void _updateDuration() {
    if (!mounted) {
      return;
    }
    final DateTime? start =
        _date(_call?['connected_at']) ?? _date(_call?['answered_at']);
    if (start == null) {
      return;
    }
    final Duration next = DateTime.now().difference(start);
    setState(() => _duration = next.isNegative ? Duration.zero : next);
  }

  Future<void> _disposeRoom() async {
    final Room? room = _room;
    _room = null;
    _roomConnected = false;
    _remoteParticipantPresent = false;
    _roomListener?.dispose();
    _roomListener = null;
    if (room == null) {
      return;
    }
    try {
      await room.disconnect();
    } catch (_) {}
    try {
      await room.dispose();
    } catch (_) {}
  }

  Future<bool> _handleBack() async {
    final String status = _statusOf(_call);
    if (status == 'ringing') {
      if (_isCaller) {
        await _cancelOutgoing();
      } else {
        await _declineCall();
      }
      return _terminalStatuses.contains(_statusOf(_call));
    }
    if (status == 'accepted' || status == 'ongoing') {
      await _endCall();
      return _terminalStatuses.contains(_statusOf(_call));
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color background = dark ? const Color(0xFF18120F) : const Color(0xFFFFF8F0);
    final Color panel = dark ? const Color(0xFF251C18) : Colors.white;
    final Color primaryText = dark ? const Color(0xFFFFF6ED) : const Color(0xFF3F2C1F);
    final Color secondaryText = dark ? const Color(0xFFD5C4B8) : const Color(0xFF7A6658);

    final NavigatorState navigator = Navigator.of(context);

    return PopScope(
      canPop: _terminalStatuses.contains(_statusOf(_call)),
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) {
          return;
        }
        unawaited(_handleBack().then((bool canClose) {
          if (mounted && navigator.mounted && canClose) {
            navigator.pop();
          }
        }));
      },
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: jobOrangeColor),
                )
              : _buildContent(
                  panel: panel,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                ),
        ),
      ),
    );
  }

  Widget _buildContent({
    required Color panel,
    required Color primaryText,
    required Color secondaryText,
  }) {
    final String status = _statusOf(_call);
    final String partnerName = _string(_call?['partner_name']) ?? 'Pengguna Ayo Suruh';
    final String? avatarUrl = _string(_call?['partner_avatar_url']);
    final String jobTitle = _string(_call?['job_title']) ?? 'Pekerjaan';

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: <Widget>[
              IconButton(
                tooltip: AyoI18n.t('Kembali'),
                onPressed: () async {
                  final bool canClose = await _handleBack();
                  if (mounted && canClose) {
                    Navigator.of(context).pop();
                  }
                },
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: primaryText),
              ),
              Expanded(
                child: Column(
                  children: <Widget>[
                    AyoText(
                      'Panggilan suara',
                      style: TextStyle(
                        color: primaryText,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    AyoText(
                      jobTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: jobOrangeColor.withValues(alpha: 0.36),
                      width: 3,
                    ),
                  ),
                  child: AyoAvatar(
                    imageUrl: avatarUrl,
                    size: 118,
                    backgroundColor: const Color(0xFFFFE7C5),
                    logoPadding: 18,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  partnerName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                AyoText(
                  _statusLabel(status),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _statusColor(status, secondaryText),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (status == 'ongoing' || status == 'accepted') ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    _formatDuration(_duration),
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: 18),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 360),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD73B35).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: <Widget>[
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFE85C55),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        if (status == 'accepted' || status == 'ongoing') ...<Widget>[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _joiningRoom
                                ? null
                                : () => unawaited(_connectToLiveKitIfNeeded()),
                            child: const AyoText('Coba Lagi'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(28),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: _buildControls(status, primaryText),
        ),
      ],
    );
  }

  Widget _buildControls(
    String status,
    Color primaryText,
  ) {
    if (status == 'ringing' && !_isCaller) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          _RoundAction(
            icon: Icons.call_end_rounded,
            label: 'Tolak',
            background: const Color(0xFFD9423A),
            foreground: Colors.white,
            onTap: _responding ? null : _declineCall,
          ),
          _RoundAction(
            icon: Icons.call_rounded,
            label: 'Terima',
            background: const Color(0xFF4E8A4A),
            foreground: Colors.white,
            onTap: _responding ? null : _acceptCall,
          ),
        ],
      );
    }

    if (status == 'ringing' && _isCaller) {
      return Center(
        child: _RoundAction(
          icon: Icons.call_end_rounded,
          label: 'Batalkan',
          background: const Color(0xFFD9423A),
          foreground: Colors.white,
          onTap: _closing ? null : _cancelOutgoing,
        ),
      );
    }

    if (status == 'accepted' || status == 'ongoing') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _RoundAction(
            icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _muted ? 'Aktifkan Mikrofon' : 'Bisukan',
            background: _muted
                ? jobOrangeColor.withValues(alpha: 0.18)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            foreground: primaryText,
            onTap: _roomConnected ? _toggleMute : null,
          ),
          _RoundAction(
            icon: _speakerOn
                ? Icons.volume_up_rounded
                : Icons.hearing_rounded,
            label: _speakerOn ? 'Speaker' : 'Earpiece',
            background: _speakerOn
                ? jobOrangeColor.withValues(alpha: 0.18)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            foreground: primaryText,
            onTap: _roomConnected ? _toggleSpeaker : null,
          ),
          _RoundAction(
            icon: Icons.call_end_rounded,
            label: 'Akhiri',
            background: const Color(0xFFD9423A),
            foreground: Colors.white,
            onTap: _closing ? null : _endCall,
          ),
        ],
      );
    }

    return Center(
      child: FilledButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close_rounded),
        label: const AyoText('Tutup'),
        style: FilledButton.styleFrom(
          backgroundColor: jobOrangeColor,
          foregroundColor: const Color(0xFF4E3400),
        ),
      ),
    );
  }

  bool get _isCaller => _call?['is_caller'] == true ||
      _string(_call?['caller_id']) == _service.currentUserId;

  String _statusLabel(String status) {
    if (_reconnecting) {
      return 'Menghubungkan kembali…';
    }
    switch (status) {
      case 'ringing':
        return _isCaller ? 'Memanggil…' : 'Panggilan masuk';
      case 'accepted':
        if (_joiningRoom) {
          return 'Menghubungkan…';
        }
        return _remoteParticipantPresent ? 'Terhubung' : 'Menunggu tersambung…';
      case 'ongoing':
        return _roomConnected ? 'Terhubung' : 'Menghubungkan…';
      case 'declined':
        return 'Panggilan ditolak';
      case 'cancelled':
        return 'Panggilan dibatalkan';
      case 'missed':
        return 'Panggilan tidak terjawab';
      case 'ended':
        return 'Panggilan berakhir';
      default:
        return 'Panggilan suara';
    }
  }

  Color _statusColor(String status, Color fallback) {
    if (status == 'ongoing' && _roomConnected) {
      return const Color(0xFF4E8A4A);
    }
    if (_terminalStatuses.contains(status)) {
      return fallback;
    }
    return jobOrangeColor;
  }

  String _formatDuration(Duration value) {
    final int hours = value.inHours;
    final int minutes = value.inMinutes.remainder(60);
    final int seconds = value.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String _statusOf(Map<String, dynamic>? call) =>
      (_string(call?['status']) ?? 'ringing').toLowerCase();

  DateTime? _date(dynamic value) {
    final String? raw = _string(value);
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  String? _string(dynamic value) {
    final String text = (value ?? '').toString().trim();
    return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
  }

  String _friendlyError(Object error) {
    String text = error.toString().trim();
    text = text
        .replaceFirst('StateError: ', '')
        .replaceFirst('PostgrestException(message: ', '')
        .replaceAll(RegExp(r', code:.*$'), '')
        .trim();
    return text.isEmpty ? 'Panggilan belum dapat diproses.' : text;
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Material(
            color: background,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap == null ? null : () => unawaited(onTap!()),
              child: SizedBox(
                width: 58,
                height: 58,
                child: Icon(
                  icon,
                  color: onTap == null
                      ? foreground.withValues(alpha: 0.42)
                      : foreground,
                  size: 27,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          AyoText(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

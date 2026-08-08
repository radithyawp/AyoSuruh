import 'dart:async';
import 'dart:convert';

import 'package:ayosuruh/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  debugPrint('FCM background message: ${message.messageId}');
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String channelId = 'ayosuruh_high_importance';
  static const String channelName = 'Notifikasi Ayo Suruh';
  static const String channelDescription =
      'Notifikasi pekerjaan, pembayaran, chat, dan aktivitas Ayo Suruh';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  SupabaseClient get _supabase => Supabase.instance.client;

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  String? _currentToken;
  bool _initialized = false;
  bool _isSyncing = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    channelId,
    channelName,
    description: channelDescription,
    importance: Importance.max,
  );

  Future<void> initialize() async {
    if (_initialized) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_channel);

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleRemoteNotificationTap,
    );

    _tokenSubscription = _messaging.onTokenRefresh.listen((token) {
      unawaited(_registerToken(token));
    });

    _authSubscription = _supabase.auth.onAuthStateChange.listen((authState) {
      final shouldRegister =
          authState.event == AuthChangeEvent.signedIn ||
          authState.event == AuthChangeEvent.initialSession;

      if (shouldRegister && authState.session != null) {
        unawaited(_requestPermissionAndSyncToken());
      }
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteNotificationTap(initialMessage);
    }

    _initialized = true;

    if (_supabase.auth.currentUser != null) {
      await _requestPermissionAndSyncToken();
    }
  }

  Future<void> _requestPermissionAndSyncToken() async {
    if (_isSyncing || _supabase.auth.currentUser == null) return;

    _isSyncing = true;

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!allowed) {
        debugPrint('Izin notifikasi belum diberikan.');
        return;
      }

      final token = await _messaging.getToken();

      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
    } catch (error) {
      debugPrint('Gagal meminta izin atau mengambil FCM token: $error');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _registerToken(String token) async {
    if (token.trim().isEmpty || _supabase.auth.currentUser == null) return;

    try {
      await _supabase.rpc(
        'register_fcm_token',
        params: {'p_token': token, 'p_platform': 'android'},
      );

      _currentToken = token;

      final preview = token.length > 12 ? token.substring(0, 12) : token;
      debugPrint('FCM token terdaftar: $preview...');
    } catch (error) {
      debugPrint('Gagal mendaftarkan FCM token ke Supabase: $error');
    }
  }

  Future<void> unregisterCurrentDevice() async {
    final token = _currentToken ?? await _messaging.getToken();

    if (token != null && _supabase.auth.currentUser != null) {
      try {
        await _supabase.rpc('unregister_fcm_token', params: {'p_token': token});
      } catch (error) {
        debugPrint('Gagal menghapus token dari Supabase: $error');
      }
    }

    try {
      await _messaging.deleteToken();
    } catch (error) {
      debugPrint('Gagal menghapus token dari Firebase: $error');
    }

    _currentToken = null;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (_supabase.auth.currentUser == null) return;

    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();

    if (title == null && body == null) return;

    final notificationId =
        (message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString())
            .hashCode &
        0x7fffffff;

    await _localNotifications.show(
      id: notificationId,
      title: title ?? 'Ayo Suruh',
      body: body ?? 'Ada aktivitas baru di akunmu.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static void _handleLocalNotificationTap(NotificationResponse response) {
    debugPrint('Local notification dibuka: ${response.payload}');
  }

  static void _handleRemoteNotificationTap(RemoteMessage message) {
    debugPrint('Push notification dibuka: ${message.data}');
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();

    _authSubscription = null;
    _tokenSubscription = null;
    _foregroundSubscription = null;
    _openedSubscription = null;

    _currentToken = null;
    _isSyncing = false;
    _initialized = false;
  }
}

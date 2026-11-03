import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/supabase_config.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'unisafe_citizen_alerts';
  static const String _channelName = 'UniSafe Citizen Alerts';
  static const String _channelDesc =
      'Real-time notifications for complaint updates and civic safety alerts.';

  static GlobalKey<NavigatorState>? navigatorKey;
  static bool _isInitialized = false;
  static String? _cachedFcmToken;

  /// Whether current running environment is physical or emulated Android device
  static bool get isAndroidTarget =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> showSafetyCheckNotification() async {
    if (!isAndroidTarget) return;
    try {
      await _localNotifications.show(
        73001,
        'ARE YOU SAFE?',
        'UniSafe has not detected movement on your active journey. Open the app to respond.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            playSound: true,
            enableVibration: true,
          ),
        ),
        payload: 'safety_check',
      );
    } catch (error) {
      debugPrint('Could not show journey safety notification: $error');
    }
  }

  static Future<void> cancelSafetyCheckNotification() async {
    if (!isAndroidTarget) return;
    try {
      await _localNotifications.cancel(73001);
    } catch (error) {
      debugPrint('Could not dismiss journey safety notification: $error');
    }
  }

  // ============================================================
  // INITIALIZATION (Android Citizen App)
  // ============================================================

  static Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    if (_isInitialized) return;
    if (navKey != null) navigatorKey = navKey;

    if (!isAndroidTarget) {
      debugPrint(
        'NotificationService: Current platform (${defaultTargetPlatform.name}) is not Android. '
        'FCM registration will run on Android devices only.',
      );
      _isInitialized = true;
      return;
    }

    try {
      // 1. Initialize Flutter Local Notifications for Android foreground display
      const androidInitSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(android: androidInitSettings);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          _handleLocalNotificationTap(response.payload);
        },
      );

      // 2. Create the Android Notification Channel (High Importance)
      const androidChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidChannel);
        // Request POST_NOTIFICATIONS runtime permission on Android 13+
        await androidPlugin.requestNotificationsPermission();
      }

      // 3. Request Firebase Messaging permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint(
        'NotificationService: FCM authorization status = ${settings.authorizationStatus}',
      );

      // 4. Retrieve FCM Registration Token
      _cachedFcmToken = await _messaging.getToken();
      if (_cachedFcmToken != null) {
        debugPrint(
          'NotificationService: FCM registration token acquired: $_cachedFcmToken',
        );
        // Synchronize with currently authenticated citizen in Supabase
        await syncTokenWithCurrentUser();
      }

      // 5. Token refresh listener
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('NotificationService: FCM token refreshed: $newToken');
        _cachedFcmToken = newToken;
        await syncTokenWithCurrentUser();
      });

      // 6. Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          'NotificationService: Foreground notification received: ${message.notification?.title}',
        );
        _showForegroundNotification(message);
      });

      // 7. Background message opened app listener (app was in background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint(
          'NotificationService: Notification opened from background: ${message.data}',
        );
        _handleRemoteNotificationTap(message.data);
      });

      // 8. Cold start notification check (app was completely terminated)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
          'NotificationService: App opened from cold start via notification: ${initialMessage.data}',
        );
        _handleRemoteNotificationTap(initialMessage.data);
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService: Non-blocking initialization notice: $e');
      _isInitialized = true;
    }
  }

  // ============================================================
  // SECURE TOKEN REGISTRATION IN SUPABASE
  // ============================================================

  /// Registers or updates the current device's FCM token against the authenticated citizen.
  static Future<void> syncTokenWithCurrentUser() async {
    final token = _cachedFcmToken;
    if (token == null || token.isEmpty) return;

    final supabase = SupabaseConfig.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      debugPrint(
        'NotificationService: No authenticated user session. Token sync deferred.',
      );
      return;
    }

    try {
      // 1. Fetch the corresponding citizen profile ID
      var query = supabase.from('citizens').select('id');
      if (currentUser.email != null && currentUser.email!.isNotEmpty) {
        query = query.or('auth_user_id.eq.${currentUser.id},email.eq.${currentUser.email}');
      } else if (currentUser.phone != null && currentUser.phone!.isNotEmpty) {
        query = query.or('auth_user_id.eq.${currentUser.id},phone.eq.${currentUser.phone}');
      } else {
        query = query.eq('auth_user_id', currentUser.id);
      }
      final citizenResponse = await query.maybeSingle();

      if (citizenResponse == null) {
        debugPrint(
          'NotificationService: Citizen profile not found for user ${currentUser.id}',
        );
        return;
      }

      final citizenId = citizenResponse['id']?.toString();
      if (citizenId == null) return;

      // 2. Upsert token into public.citizen_fcm_tokens
      final now = DateTime.now().toUtc().toIso8601String();
      await supabase.from('citizen_fcm_tokens').upsert({
        'citizen_id': citizenId,
        'auth_user_id': currentUser.id,
        'fcm_token': token,
        'device_type': 'android',
        'is_active': true,
        'updated_at': now,
      }, onConflict: 'fcm_token');

      debugPrint(
        'NotificationService: Successfully registered FCM token for citizen $citizenId',
      );
    } catch (e) {
      debugPrint(
        'NotificationService: Error synchronizing token with Supabase: $e',
      );
    }
  }

  /// Removes/deactivates the token in Supabase when the user logs out.
  static Future<void> unregisterCurrentDeviceToken() async {
    final token = _cachedFcmToken;
    if (token == null) return;

    try {
      final supabase = SupabaseConfig.client;
      await supabase
          .from('citizen_fcm_tokens')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('fcm_token', token);

      debugPrint(
        'NotificationService: Invalidated device FCM token on logout.',
      );
    } catch (e) {
      debugPrint('NotificationService: Error unregistering FCM token: $e');
    }
  }

  // ============================================================
  // FOREGROUND HEADS-UP NOTIFICATIONS
  // ============================================================

  static void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    _localNotifications.show(
      DateTime.now().millisecond,
      notification.title ?? 'UniSafe Alert',
      notification.body ?? '',
      notificationDetails,
      payload: message.data['complaint_id']?.toString() ?? '',
    );
  }

  // ============================================================
  // NOTIFICATION TAP ROUTING
  // ============================================================

  static void _handleLocalNotificationTap(String? payload) {
    if (payload == 'safety_check') return;
    if (payload != null && payload.isNotEmpty) {
      _navigateToComplaintOrMap(payload);
    }
  }

  static void _handleRemoteNotificationTap(Map<String, dynamic> data) {
    final complaintId = data['complaint_id']?.toString();
    _navigateToComplaintOrMap(complaintId);
  }

  static void _navigateToComplaintOrMap(String? complaintId) {
    final nav = navigatorKey?.currentState;
    if (nav == null) {
      debugPrint(
        'NotificationService: Navigator key is null. Cannot navigate.',
      );
      return;
    }

    // Navigate to interactive map or report screen
    nav.pushNamed('/interactive-map', arguments: {'complaint_id': complaintId});
  }

  // ============================================================
  // BUSINESS LOGIC: COMPLAINT LIFECYCLE NOTIFICATIONS
  // ============================================================

  /// Triggered immediately after a citizen submits a complaint successfully.
  static Future<void> notifyComplaintSubmitted({
    required String complaintId,
    required String title,
    String? citizenId,
  }) async {
    const notifTitle = 'Complaint Submitted Successfully';
    final notifBody =
        'Your report "$title" has been registered and assigned for review.';

    await _recordAndDisplayNotification(
      complaintId: complaintId,
      citizenId: citizenId,
      title: notifTitle,
      body: notifBody,
    );
  }

  /// Triggered when the status of a complaint changes (e.g. pending -> in_progress).
  static Future<void> notifyComplaintStatusChanged({
    required String complaintId,
    required String title,
    required String newStatus,
    String? citizenId,
  }) async {
    final formattedStatus = _formatStatus(newStatus);
    final notifTitle = 'Complaint Status Update';
    final notifBody = 'Your report "$title" is now marked as $formattedStatus.';

    await _recordAndDisplayNotification(
      complaintId: complaintId,
      citizenId: citizenId,
      title: notifTitle,
      body: notifBody,
    );
  }

  /// Triggered when a complaint is officially resolved.
  static Future<void> notifyComplaintResolved({
    required String complaintId,
    required String title,
    String? citizenId,
  }) async {
    const notifTitle = 'Complaint Resolved';
    final notifBody =
        'Your report "$title" has been marked as Resolved by municipal authorities.';

    await _recordAndDisplayNotification(
      complaintId: complaintId,
      citizenId: citizenId,
      title: notifTitle,
      body: notifBody,
    );
  }

  /// Triggered when multiple complaints in a radius trigger a safety/heatmap zone.
  static Future<void> notifySafetyThresholdReached({
    required String zoneType,
    required int reportCount,
    String? citizenId,
  }) async {
    final notifTitle = 'Civic Safety Alert: $zoneType Area';
    final notifBody =
        'A high density of reports ($reportCount nearby) has established an active safety alert zone.';

    await _recordAndDisplayNotification(
      complaintId: '',
      citizenId: citizenId,
      title: notifTitle,
      body: notifBody,
    );
  }

  // ============================================================
  // INTERNAL HELPER: RECORD IN SUPABASE & SHOW LOCAL ALERT
  // ============================================================

  static Future<void> _recordAndDisplayNotification({
    required String complaintId,
    String? citizenId,
    required String title,
    required String body,
  }) async {
    final supabase = SupabaseConfig.client;

    try {
      // 1. Resolve citizen ID if not passed directly
      String? resolvedCitizenId = citizenId;
      if (resolvedCitizenId == null) {
        final currentUser = supabase.auth.currentUser;
        if (currentUser != null) {
          var query = supabase.from('citizens').select('id');
          if (currentUser.email != null && currentUser.email!.isNotEmpty) {
            query = query.or('auth_user_id.eq.${currentUser.id},email.eq.${currentUser.email}');
          } else if (currentUser.phone != null && currentUser.phone!.isNotEmpty) {
            query = query.or('auth_user_id.eq.${currentUser.id},phone.eq.${currentUser.phone}');
          } else {
            query = query.eq('auth_user_id', currentUser.id);
          }
          final res = await query.maybeSingle();
          resolvedCitizenId = res?['id']?.toString();
        }
      }

      // 2. Persist notification in public.notifications
      if (resolvedCitizenId != null) {
        await supabase.from('notifications').insert({
          'citizen_id': resolvedCitizenId,
          'title': title,
          'body': body,
          'is_read': false,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint(
        'NotificationService: Error persisting notification in database: $e',
      );
    }

    // 3. Show local notification on Android devices
    if (isAndroidTarget) {
      try {
        const androidDetails = AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        );

        await _localNotifications.show(
          DateTime.now().millisecond,
          title,
          body,
          const NotificationDetails(android: androidDetails),
          payload: complaintId,
        );
      } catch (e) {
        debugPrint('NotificationService: Error showing local notification: $e');
      }
    }

    // 4. Show in-app banner across all platforms (Desktop, Web, Mobile)
    try {
      final currentCtx = navigatorKey?.currentContext;
      if (currentCtx != null) {
        ScaffoldMessenger.of(currentCtx).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1E1B4B),
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            content: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    color: Colors.amber,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('NotificationService: In-app banner notice: $e');
    }
  }

  static String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
      case 'in progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Under Review';
    }
  }
}

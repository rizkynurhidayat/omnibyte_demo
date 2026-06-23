import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level background message handler for Firebase Cloud Messaging.
/// It must be a top-level function (not a class member) and annotated with @pragma('vm:entry-point')
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background tasks
  await Firebase.initializeApp();
  debugPrint("Handling background message: ${message.messageId}");
  debugPrint("Background Message data: ${message.data}");
  if (message.notification != null) {
    debugPrint("Background Message notification title: ${message.notification?.title}");
    debugPrint("Background Message notification body: ${message.notification?.body}");
  }
}

/// Service class to manage Firebase Cloud Messaging and local notifications.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Android High Importance Notification Channel.
  static const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.', // description
    importance: Importance.max,
    playSound: true,
  );

  /// Initializes FCM and local notification settings.
  Future<void> initialize() async {
    // 1. Request notification permissions from the user
    await _requestPermissions();

    // 2. Initialize Flutter Local Notifications for foreground notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    // 3. Create High Importance Notification Channel on Android
    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // 4. Set foreground presentation options for FCM (primarily for iOS)
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 5. Setup foreground message listener
    _setupForegroundListener();

    // 6. Handle notification click when app is opened from different states
    _setupInteractionListeners();

    // 7. Fetch and print FCM Token for testing
    await _printFCMToken();
  }

  /// Request permissions for notifications (required for Android 13+ and iOS)
  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');
  }

  /// Retrieves and prints the Firebase Cloud Messaging Token for testing purposes.
  Future<void> _printFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      debugPrint('================ FCM TOKEN ================');
      debugPrint(token ?? 'Failed to get token');
      debugPrint('===========================================');
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  /// Listen for incoming messages while the app is in the foreground
  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received a foreground message: ${message.messageId}');
      
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // If the notification is present, show local notification overlay
      if (notification != null && android != null) {
        _localNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannel.id,
              _androidChannel.name,
              channelDescription: _androidChannel.description,
              icon: android.smallIcon ?? '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
            ),
          ),
          payload: message.data.toString(), // Pass data if navigation is needed
        );
      }
    });
  }

  /// Listen for user interaction (clicks) on notifications
  void _setupInteractionListeners() {
    // Case 1: App is in background and user clicks the notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened from background via notification: ${message.messageId}');
      _handleNotificationClick(message.data);
    });

    // Case 2: App was terminated and user clicks the notification to open it
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('App opened from terminated state via notification: ${message.messageId}');
        _handleNotificationClick(message.data);
      }
    });
  }

  /// Handles action when a local notification is clicked (Foreground case)
  void _onDidReceiveNotificationResponse(NotificationResponse details) {
    debugPrint('Local notification clicked: ${details.payload}');
    // Parse payload and handle routing here if needed
  }

  /// Unified handler to manage app navigation/action when user clicks on a notification
  void _handleNotificationClick(Map<String, dynamic> data) {
    debugPrint('Handling notification click data: $data');
    // Implement routing or feature trigger here based on the data payload
  }
}

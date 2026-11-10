import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final title = message.notification?.title ?? 'Savings update';
  final body = message.notification?.body ?? 'Your transaction status changed.';
  await NotificationService.showNotification(
    TransactionNotificationContent(title: title, body: body),
  );
}

class TransactionNotificationContent {
  final String title;
  final String body;

  const TransactionNotificationContent({
    required this.title,
    required this.body,
  });

  static TransactionNotificationContent forDepositStatus({
    required String status,
    required double amount,
  }) {
    final formattedAmount = 'Ksh ${amount.toStringAsFixed(0)}';

    switch (status.toLowerCase()) {
      case 'pending':
        return const TransactionNotificationContent(
          title: 'Savings deposit started',
          body:
              'Your M-Pesa request is being processed. Please check your phone.',
        );
      case 'completed':
        return TransactionNotificationContent(
          title: 'Savings deposit confirmed',
          body: '$formattedAmount has been added to your savings.',
        );
      case 'failed':
        return TransactionNotificationContent(
          title: 'Savings deposit failed',
          body:
              'Your deposit of $formattedAmount was not completed. Please try again.',
        );
      default:
        return TransactionNotificationContent(
          title: 'Savings update',
          body: 'Your deposit status for $formattedAmount has changed.',
        );
    }
  }

  static TransactionNotificationContent forWithdrawalStatus({
    required String status,
    required double amount,
  }) {
    final formattedAmount = 'Ksh ${amount.toStringAsFixed(0)}';

    switch (status.toLowerCase()) {
      case 'pending':
        return const TransactionNotificationContent(
          title: 'Withdrawal in progress',
          body:
              'Your withdrawal request is being processed. Please check your phone.',
        );
      case 'completed':
        return TransactionNotificationContent(
          title: 'Withdrawal completed',
          body: '$formattedAmount has been sent to your M-Pesa account.',
        );
      case 'failed':
        return TransactionNotificationContent(
          title: 'Withdrawal failed',
          body:
              'Your withdrawal of $formattedAmount could not be completed. Please try again.',
        );
      default:
        return TransactionNotificationContent(
          title: 'Withdrawal update',
          body: 'Your withdrawal status for $formattedAmount has changed.',
        );
    }
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final iosPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  static Future<void> initializeFirebase({required String apiBaseUrl}) async {
    await Firebase.initializeApp();

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        try {
          await http.post(
            Uri.parse('$apiBaseUrl/device-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token}),
          );
        } catch (_) {
          // Ignore backend registration errors and keep app working.
        }
      }
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? 'Savings update';
      final body =
          message.notification?.body ?? 'Your transaction status changed.';
      unawaited(
        showNotification(
          TransactionNotificationContent(title: title, body: body),
        ),
      );
    });

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  static Future<void> showNotification(
    TransactionNotificationContent notification,
  ) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'savings_channel',
          'Savings Updates',
          channelDescription:
              'Notifications for savings deposits and withdrawals',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'Savings update',
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title,
      notification.body,
      details,
    );
  }
}

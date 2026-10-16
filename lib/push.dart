import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'db.dart';

// Tokens live in an owner-only doc (users/* is readable by every signed-in user).
DocumentReference<Json> _fcmDoc(String uid) => userDoc(uid).collection('private').doc('fcm');
StreamSubscription<String>? _refresh;
StreamSubscription<RemoteMessage>? _foreground;

// Same id as default_notification_channel_id in AndroidManifest.xml, so background pushes match.
const _channel = AndroidNotificationChannel('couplefit', '짝꿍 알림', importance: Importance.high);
final _local = FlutterLocalNotificationsPlugin();

const _restChannel = AndroidNotificationChannel('rest', '휴식 타이머', importance: Importance.high);
const _restId = 7001;
const _restDetails = NotificationDetails(
  android: AndroidNotificationDetails('rest', '휴식 타이머', importance: Importance.high, priority: Priority.high),
  // Banner + sound even while the app is open (AppDelegate makes the plugin's delegate see in-app notifications).
  iOS: DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentList: true, presentSound: true),
);

Future<void>? _init;

/// One-time local notification setup. Permission is asked by FirebaseMessaging.requestPermission.
Future<void> _initLocal() => _init ??= () async {
  await _local.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );
  final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(_channel);
  await android?.createNotificationChannel(_restChannel);
}();

/// "휴식 끝!" for the rest that ends at [end] (null = cancel the pending one).
/// iOS: scheduled, so it rings locked, in another app, or in-app.
/// Android: the workout screen calls [showRestAlertNow] when it sees the rest end.
// ponytail: Android background rest alert needs an exact alarm (SCHEDULE_EXACT_ALARM); add if Android users matter.
Future<void> scheduleRestAlert(DateTime? end, String body) async {
  await _initLocal();
  await _local.cancel(id: _restId);
  if (end == null || defaultTargetPlatform != TargetPlatform.iOS) return;
  final at = tz.TZDateTime.from(end, tz.UTC);
  if (!at.isAfter(tz.TZDateTime.now(tz.UTC))) return;
  await _local.zonedSchedule(
    id: _restId,
    title: '휴식 끝!',
    body: body,
    scheduledDate: at,
    notificationDetails: _restDetails,
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );
}

Future<void> showRestAlertNow(String body) async {
  if (defaultTargetPlatform != TargetPlatform.android) return; // iOS already fired the scheduled one
  await _initLocal();
  await _local.show(id: _restId, title: '휴식 끝!', body: body, notificationDetails: _restDetails);
}

/// Android doesn't display FCM notifications while the app is open, so show them ourselves.
/// (iOS does it natively via setForegroundNotificationPresentationOptions.)
Future<void> _showAndroidForeground() async {
  if (defaultTargetPlatform != TargetPlatform.android || _foreground != null) return;
  await _initLocal();
  _foreground = FirebaseMessaging.onMessage.listen((m) {
    final n = m.notification;
    if (n == null) return;
    _local.show(
      id: m.messageId.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  });
}

/// Ask permission and save this device's token so Cloud Functions can push to it.
Future<void> registerPush() async {
  final m = FirebaseMessaging.instance;
  await m.requestPermission();
  // iOS: show pushes while the app is open too.
  await m.setForegroundNotificationPresentationOptions(alert: true, sound: true);
  await _showAndroidForeground();
  final uid = myUid;
  Future<void> save(String t) => _fcmDoc(uid).set({
    'tokens': FieldValue.arrayUnion([t]),
  }, SetOptions(merge: true));
  try {
    final t = await m.getToken();
    if (t != null) await save(t);
  } catch (_) {
    // iOS without APNs set up (e.g. simulator) has no token; pushes just won't arrive.
  }
  await _refresh?.cancel();
  _refresh = m.onTokenRefresh.listen(save);
}

/// Call before sign-out so this device stops getting the old account's pushes.
Future<void> unregisterPush() async {
  await _refresh?.cancel();
  try {
    final t = await FirebaseMessaging.instance.getToken();
    if (t != null) {
      await _fcmDoc(myUid).update({
        'tokens': FieldValue.arrayRemove([t]),
      });
    }
  } catch (_) {}
}

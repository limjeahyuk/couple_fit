import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'db.dart';

// Tokens live in an owner-only doc (users/* is readable by every signed-in user).
DocumentReference<Json> _fcmDoc(String uid) => userDoc(uid).collection('private').doc('fcm');
StreamSubscription<String>? _refresh;
StreamSubscription<RemoteMessage>? _foreground;

// Same id as default_notification_channel_id in AndroidManifest.xml, so background pushes match.
const _channel = AndroidNotificationChannel('couplefit', '짝꿍 알림', importance: Importance.high);
final _local = FlutterLocalNotificationsPlugin();

/// Android doesn't display FCM notifications while the app is open, so show them ourselves.
/// (iOS does it natively via setForegroundNotificationPresentationOptions.)
Future<void> _showAndroidForeground() async {
  if (defaultTargetPlatform != TargetPlatform.android || _foreground != null) return;
  await _local.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
  await _local
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);
  _foreground = FirebaseMessaging.onMessage.listen((m) {
    final n = m.notification;
    if (n == null) return;
    _local.show(
      id: m.messageId.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(_channel.id, _channel.name, importance: Importance.high, priority: Priority.high)),
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
  Future<void> save(String t) => _fcmDoc(uid).set({'tokens': FieldValue.arrayUnion([t])}, SetOptions(merge: true));
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
    if (t != null) await _fcmDoc(myUid).update({'tokens': FieldValue.arrayRemove([t])});
  } catch (_) {}
}

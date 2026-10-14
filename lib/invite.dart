import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'db.dart';

// Firebase Hosting domain serving hosting/public (invite page + app/universal-link files).
// Also set in ios/Runner/Runner.entitlements and android/app/src/main/AndroidManifest.xml.
const inviteHost = 'couplefit-a47ae.web.app';

typedef Invite = ({String code, String? token});

/// Set when the app is opened from an invite link; the shell consumes it once signed in.
final pendingInvite = ValueNotifier<Invite?>(null);

void listenInviteLinks() => AppLinks().uriLinkStream.listen((u) {
      final i = parseInvite(u);
      if (i != null) pendingInvite.value = i;
    }, onError: (_) {});

/// `https://HOST/invite/CODE?t=TOKEN` or `couplefit://invite/CODE?t=TOKEN`
Invite? parseInvite(Uri u) {
  final seg = u.pathSegments.where((s) => s.isNotEmpty).toList();
  final ok = u.scheme == 'couplefit' ? u.host == 'invite' && seg.length == 1 : seg.length == 2 && seg.first == 'invite';
  if (!ok) return null;
  final t = u.queryParameters['t'];
  return (code: seg.last.toUpperCase(), token: t == null || t.isEmpty ? null : t);
}

/// Mint a one-time token (owner-only doc; the server checks it to link without a manual accept) and open the share sheet.
Future<void> shareInvite(BuildContext context, Json me) async {
  const chars = 'abcdefghijkmnpqrstuvwxyz23456789';
  final r = Random.secure();
  final token = List.generate(16, (_) => chars[r.nextInt(chars.length)]).join();
  await userDoc(myUid).collection('private').doc('invite').set({'token': token});
  if (!context.mounted) return;
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(ShareParams(
    subject: '같이 운동해요',
    text: '${me['name']}님이 같이 운동하자고 초대했어요 💪\nhttps://$inviteHost/invite/${me['code']}?t=$token',
    sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size, // iPad popover anchor
  ));
}

/// Shown by the shell when an invite link arrives. Sends the link request; the server completes it.
Future<void> openInvite(BuildContext context, Invite inv, Json me, {required bool linked}) async {
  void say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  if (inv.code == me['code']) return say('내가 보낸 초대 링크예요');
  if (linked) return say('이미 짝꿍과 연결돼 있어요');
  final q = await fs.collection('users').where('code', isEqualTo: inv.code).limit(1).get();
  final inviter = q.docs.firstOrNull;
  if (!context.mounted) return;
  if (inviter == null) return say('초대를 찾을 수 없어요');
  final name = inviter.data()['name'] ?? '상대방';
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('$name님의 초대'),
      content: const Text('연결하면 서로의 운동 기록을 보고 루틴을 짜줄 수 있어요.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('연결하기')),
      ],
    ),
  );
  if (ok == true) await userDoc(myUid).update({'partnerId': inviter.id, 'inviteToken': inv.token});
}

bool _accepting = false;

/// Inviter side, no server needed: an incoming request carrying my current one-time token links right away.
/// (functions/index.js does the same when Cloud Functions are deployed; both end in the same state.)
Future<void> autoAcceptInvite(Json me, List<QueryDocumentSnapshot<Json>> requests) async {
  final candidates = requests.where((d) => d.data()['inviteToken'] != null).toList();
  if (_accepting || me['partnerId'] != null || candidates.isEmpty) return;
  _accepting = true;
  try {
    final ref = userDoc(myUid).collection('private').doc('invite');
    final token = (await ref.get()).data()?['token'];
    final match = candidates.where((d) => d.data()['inviteToken'] == token).firstOrNull;
    if (token == null || match == null) return;
    await ref.delete(); // one-time
    await userDoc(myUid).update({'partnerId': match.id});
  } finally {
    _accepting = false;
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'db.dart';
import 'demo.dart';
import 'invite.dart';
import 'push.dart';
import 'theme.dart';

/// Pairing: I set my partnerId to their uid (request); they do the same back (accept).
class CouplePage extends StatefulWidget {
  const CouplePage({super.key});

  @override
  State<CouplePage> createState() => _CouplePageState();
}

class _CouplePageState extends State<CouplePage> {
  final codeCtl = TextEditingController();

  Future<void> _setPartner(String? uid) => userDoc(myUid).update({'partnerId': uid});

  Future<void> _request() async {
    final q = await fs.collection('users').where('code', isEqualTo: codeCtl.text.trim().toUpperCase()).limit(1).get();
    final uid = q.docs.firstOrNull?.id;
    if (uid == null || uid == myUid) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('코드를 찾을 수 없어요')));
      return;
    }
    await _setPartner(uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('커플')),
      body: StreamBuilder(
        stream: userDoc(myUid).snapshots(),
        builder: (context, meSnap) {
          final me = meSnap.data?.data();
          if (me == null) return const SizedBox();
          final pid = me['partnerId'] as String?;
          return StreamBuilder(
            stream: pid == null ? null : userDoc(pid).snapshots(),
            builder: (context, pSnap) {
              final p = pSnap.data?.data();
              final linked = p != null && p['partnerId'] == myUid;
              return ListView(padding: const EdgeInsets.all(20), children: [
                box(
                  Row(children: [
                    // Tap to decorate: the badge hints it's editable.
                    IconButton(
                      tooltip: '아바타 꾸미기',
                      padding: EdgeInsets.zero,
                      onPressed: () => showModalBottomSheet(
                          context: context, isScrollControlled: true, builder: (_) => AvatarEditor(me: me)),
                      icon: Stack(clipBehavior: Clip.none, children: [
                        avatar(me['name'] ?? '', lime, size: 56, look: me['avatar']),
                        const Positioned(
                          right: -2,
                          bottom: -2,
                          child: CircleAvatar(radius: 11, backgroundColor: surf2, child: Icon(Icons.edit, size: 13, color: fg)),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${me['name']} (나)', style: ts(16, w: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text.rich(TextSpan(style: ts(13, color: muted), children: [
                          const TextSpan(text: '내 커플 코드  '),
                          TextSpan(text: '${me['code']}', style: digits(15, color: lime)),
                        ])),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                if (linked) ...[
                  box(Row(children: [
                    avatar(p['name'] ?? '', coral, size: 44, look: p['avatar']),
                    const SizedBox(width: 14),
                    Expanded(child: Text('${p['name']}님과 연결됨', style: ts(16, w: FontWeight.w700))),
                    const Icon(Icons.favorite, color: coral),
                  ])),
                  const SizedBox(height: 8),
                  Text('운동 탭에서 짝꿍 루틴을 짜주고, 캘린더에서 서로의 기록을 볼 수 있어요.',
                      textAlign: TextAlign.center, style: ts(13, color: muted, h: 1.5)),
                  TextButton(onPressed: () => _setPartner(null), child: const Text('연결 끊기', style: TextStyle(color: muted))),
                ] else if (pid != null) ...[
                  box(Row(children: [
                    const Icon(Icons.hourglass_top, color: coral),
                    const SizedBox(width: 14),
                    Expanded(child: Text('${p?['name'] ?? '상대방'}님의 수락을 기다리는 중', style: ts(15, w: FontWeight.w600))),
                  ])),
                  TextButton(onPressed: () => _setPartner(null), child: const Text('요청 취소')),
                ] else ...[
                  Builder(
                    builder: (context) => FilledButton.icon(
                      onPressed: () => shareInvite(context, me),
                      icon: const Icon(Icons.ios_share),
                      label: const Text('초대 링크 보내기'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('링크를 받은 짝꿍이 누르면 바로 연결돼요', textAlign: TextAlign.center, style: ts(13, color: muted)),
                  const SizedBox(height: 24),
                  Text('또는 코드로 연결', style: ts(13, color: muted)),
                  const SizedBox(height: 8),
                  TextField(controller: codeCtl, decoration: const InputDecoration(labelText: '짝꿍의 커플 코드')),
                  const SizedBox(height: 10),
                  OutlinedButton(
                      onPressed: _request,
                      style: OutlinedButton.styleFrom(foregroundColor: lime, minimumSize: const Size.fromHeight(52)),
                      child: const Text('연결 요청')),
                  const SizedBox(height: 24),
                  Text('받은 요청', style: ts(13, color: muted)),
                  StreamBuilder(
                    stream: fs.collection('users').where('partnerId', isEqualTo: myUid).snapshots(),
                    builder: (context, snap) => Column(children: [
                      for (final d in snap.data?.docs ?? [])
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: avatar(d.data()['name'] ?? '', coral, look: d.data()['avatar']),
                          title: Text('${d.data()['name']}님의 요청'),
                          trailing: TextButton(onPressed: () => _setPartner(d.id), child: const Text('수락')),
                        ),
                    ]),
                  ),
                ],
                if (demoAvailable && !linked) ...[
                  const SizedBox(height: 24),
                  ValueListenableBuilder(
                    valueListenable: demoPartner,
                    builder: (context, on, _) => box(
                      r: 20,
                      p: const EdgeInsets.fromLTRB(18, 12, 8, 12),
                      Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('데모 짝꿍으로 미리 보기', style: ts(15, w: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('개발용 · 가짜 짝꿍 기록을 화면에만 보여줘요', style: ts(12, color: muted)),
                          ]),
                        ),
                        Switch(value: on, onChanged: (v) => demoPartner.value = v),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                TextButton(
                  onPressed: () async {
                    await unregisterPush();
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
                  },
                  child: const Text('로그아웃', style: TextStyle(color: muted)),
                ),
              ]);
            },
          );
        },
      ),
    );
  }
}

/// Pick a background color and a character (emoji or the name's first letter).
class AvatarEditor extends StatefulWidget {
  const AvatarEditor({super.key, required this.me});
  final Json me;

  @override
  State<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<AvatarEditor> {
  late int bgValue = (widget.me['avatar']?['bg'] as int?) ?? lime.toARGB32();
  late String? emoji = widget.me['avatar']?['emoji'] as String?;
  bool saving = false;

  Future<void> _save() async {
    setState(() => saving = true);
    await userDoc(myUid).update({'avatar': {'bg': bgValue, 'emoji': emoji}});
    if (mounted) Navigator.pop(context);
  }

  Widget _pick({required bool on, required VoidCallback onTap, required Widget child, String? label}) => Semantics(
        label: label,
        selected: on,
        button: true,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? fg : Colors.transparent, width: 2)),
            child: child,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final name = widget.me['name'] as String? ?? '';
    final look = {'bg': bgValue, 'emoji': emoji};
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('아바타 꾸미기', style: ts(18, w: FontWeight.w700)),
          const SizedBox(height: 20),
          Center(child: avatar(name, lime, size: 96, look: look)),
          const SizedBox(height: 20),
          Text('배경색', style: ts(13, color: muted)),
          const SizedBox(height: 8),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final c in avatarColors)
              _pick(
                on: c.toARGB32() == bgValue,
                label: '배경색',
                onTap: () => setState(() => bgValue = c.toARGB32()),
                child: CircleAvatar(radius: 17, backgroundColor: c),
              ),
          ]),
          const SizedBox(height: 16),
          Text('캐릭터', style: ts(13, color: muted)),
          const SizedBox(height: 8),
          Wrap(spacing: 4, runSpacing: 4, children: [
            _pick(
              on: emoji == null,
              label: '이름 첫 글자',
              onTap: () => setState(() => emoji = null),
              child: Text(name.isEmpty ? '?' : name.characters.first, style: ts(18, w: FontWeight.w700)),
            ),
            for (final e in avatarEmojis)
              _pick(on: emoji == e, onTap: () => setState(() => emoji = e), child: Text(e, style: const TextStyle(fontSize: 24))),
          ]),
          const SizedBox(height: 20),
          FilledButton(onPressed: saving ? null : _save, child: const Text('저장')),
        ]),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth.dart';
import 'calendar.dart';
import 'db.dart';
import 'demo.dart';
import 'firebase_options.dart';
import 'home.dart';
import 'invite.dart';
import 'push.dart';
import 'records.dart';
import 'routines.dart';
import 'setup.dart';
import 'theme.dart';
import 'workout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  listenInviteLinks();
  runApp(
    MaterialApp(
      title: 'CoupleFit',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      // Tap anywhere outside a field to close the keyboard (the number pad has no Done key).
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
      ),
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) => snap.data == null ? const LoginPage() : Shell(key: ValueKey(snap.data!.uid)),
      ),
    ),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController(), pw = TextEditingController(), name = TextEditingController();
  bool signUp = false, busy = false;

  /// Runs a sign-in; the profile itself is created by the shell (createProfileIfMissing).
  Future<void> _run(Future<void> Function() signIn) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await signIn();
    } on FirebaseAuthException catch (e) {
      _say(e.message ?? e.code);
    } catch (e) {
      _say('로그인하지 못했어요: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _say(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _email() async {
    final auth = FirebaseAuth.instance;
    if (!signUp) {
      await auth.signInWithEmailAndPassword(email: email.text.trim(), password: pw.text);
      return;
    }
    if (name.text.trim().isEmpty) return _say('이름을 입력하세요');
    pendingName = name.text.trim();
    await auth.createUserWithEmailAndPassword(email: email.text.trim(), password: pw.text);
  }

  Widget _social(String label, Widget icon, Color bg, Color fg, Future<void> Function() signIn) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: FilledButton.icon(
      onPressed: busy ? null : () => _run(signIn),
      style: FilledButton.styleFrom(backgroundColor: bg, foregroundColor: fg, minimumSize: const Size.fromHeight(56)),
      icon: icon,
      label: Text(label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 64),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                avatar('운', lime, size: 52, ring: true),
                Transform.translate(offset: const Offset(-14, 0), child: avatar('동', coral, size: 52, ring: true)),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '둘이 하는 운동',
              textAlign: TextAlign.center,
              style: ts(28, w: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '루틴, 타이머, 서로의 기록까지 함께',
              textAlign: TextAlign.center,
              style: ts(14, color: muted),
            ),
            const SizedBox(height: 40),
            ValueListenableBuilder(
              valueListenable: pendingInvite,
              builder: (context, inv, _) => inv == null
                  ? const SizedBox()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: box(
                        r: 16,
                        p: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        c: coral.withValues(alpha: 0.12),
                        Text(
                          '초대 링크로 들어왔어요. 로그인하거나 가입하면 바로 연결할 수 있어요',
                          textAlign: TextAlign.center,
                          style: ts(14, color: coral, w: FontWeight.w600),
                        ),
                      ),
                    ),
            ),
            if (Platform.isIOS)
              _social('Apple로 계속하기', const Icon(Icons.apple, size: 24), Colors.white, Colors.black, signInWithApple),
            _social(
              'Google로 계속하기',
              Text(
                'G',
                style: ts(20, color: const Color(0xFF4285F4), w: FontWeight.w800),
              ),
              surf2,
              fg,
              signInWithGoogle,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  const Expanded(child: Divider(color: off)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('또는 이메일로', style: ts(13, color: muted)),
                  ),
                  const Expanded(child: Divider(color: off)),
                ],
              ),
            ),
            if (signUp) ...[
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: '이메일'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pw,
              obscureText: true,
              decoration: const InputDecoration(labelText: '비밀번호'),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: busy ? null : () => _run(_email),
              style: OutlinedButton.styleFrom(foregroundColor: lime, minimumSize: const Size.fromHeight(56)),
              child: Text(signUp ? '가입하기' : '이메일로 로그인'),
            ),
            TextButton(
              onPressed: () => setState(() => signUp = !signUp),
              child: Text(signUp ? '이미 계정이 있어요' : '처음이에요 · 가입하기'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Holds the live Firestore data every tab renders, plus the bottom bar.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  Json? me, paDoc;
  String? paId;
  List<Json> mySes = [], paSes = [], myBody = [], paBody = [];
  bool bodyLoaded = false;
  List<QueryDocumentSnapshot<Json>> routines = [], requests = [];
  late final List<StreamSubscription> _subs;
  StreamSubscription? _paDocSub;
  List<StreamSubscription> _paData = [];

  // ponytail: streams a year of sessions per person; page by month if history gets heavy.
  Stream<List<Json>> _sessions(String uid) =>
      sessionsOf(uid)
          .where('date', isGreaterThanOrEqualTo: dayKey(DateTime.now().subtract(const Duration(days: 366))))
          .orderBy('date', descending: true)
          .snapshots()
          .map((s) => s.docs.map((d) => d.data()).toList());
  Stream<List<Json>> _body(String uid) =>
      bodyOf(uid).orderBy('date').snapshots().map((s) => s.docs.map((d) => d.data()).toList());
  void _ignore(Object _) {}
  void _onWorkout() => setState(() {}); // workout started/ended: swap the 운동 tab content

  bool _inviteOpen = false;
  Future<void> _maybeInvite() async {
    final inv = pendingInvite.value;
    if (inv == null || me == null || _inviteOpen || !mounted) return;
    _inviteOpen = true;
    pendingInvite.value = null;
    await openInvite(context, inv, me!, linked: _paData.isNotEmpty);
    _inviteOpen = false;
  }

  @override
  void initState() {
    super.initState();
    registerPush();
    pendingInvite.addListener(_maybeInvite);
    activeWorkout.addListener(_onWorkout);
    demoPartner.addListener(_onWorkout);
    _subs = [
      userDoc(myUid).snapshots().listen((s) {
        if (!s.exists && !s.metadata.isFromCache) createProfileIfMissing().catchError((_) {});
        setState(() => me = s.data());
        _watchPartner(me?['partnerId']);
        _maybeInvite();
        if (me != null) autoAcceptInvite(me!, requests);
      }, onError: _ignore),
      _sessions(myUid).listen((v) => setState(() => mySes = v), onError: _ignore),
      _body(myUid).listen((v) => setState(() {
            myBody = v;
            bodyLoaded = true;
          }), onError: _ignore),
      routinesOf(myUid)
          .orderBy('createdAt')
          .snapshots()
          .listen((s) => setState(() => routines = s.docs), onError: _ignore),
      // Incoming link requests: auto-accept the one that came through my invite link.
      fs.collection('users').where('partnerId', isEqualTo: myUid).snapshots().listen((s) {
        requests = s.docs;
        if (me != null) autoAcceptInvite(me!, requests);
      }, onError: _ignore),
    ];
  }

  void _watchPartner(String? id) {
    if (id == paId) return;
    paId = id;
    paDoc = null;
    _paDocSub?.cancel();
    _setLinked(false);
    if (id == null) return;
    _paDocSub = userDoc(id).snapshots().listen((s) {
      setState(() => paDoc = s.data());
      _setLinked(paDoc?['partnerId'] == myUid);
    }, onError: _ignore);
  }

  /// Partner's sessions are readable only once the link is mutual.
  void _setLinked(bool on) {
    if (on == _paData.isNotEmpty) return;
    for (final s in _paData) {
      s.cancel();
    }
    _paData = [];
    paSes = [];
    paBody = [];
    if (on) {
      _paData = [
        _sessions(paId!).listen((v) => setState(() => paSes = v), onError: _ignore),
        _body(paId!).listen((v) => setState(() => paBody = v), onError: _ignore),
      ];
    }
  }

  @override
  void dispose() {
    pendingInvite.removeListener(_maybeInvite);
    activeWorkout.removeListener(_onWorkout);
    demoPartner.removeListener(_onWorkout);
    for (final s in [..._subs, ..._paData]) {
      s.cancel();
    }
    _paDocSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (me == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    // First run (or an older account): gender + height/weight before anything else.
    if (me!['gender'] == null || (bodyLoaded && !myBody.any((b) => b['weight'] is num))) {
      return ProfileSetup(gender: me!['gender'], last: myBody.lastOrNull);
    }
    // Debug preview: an in-memory partner (never saved) when no real one is linked.
    final demo = demoPartner.value && _paData.isEmpty;
    final data = AppData(
      me: me!,
      partner: demo ? demoPartnerDoc(myUid) : (_paData.isNotEmpty && paDoc != null ? {...paDoc!, 'uid': paId} : null),
      mySessions: mySes,
      paSessions: demo ? demoSessions() : paSes,
      routines: routines,
      myBody: demo && myBody.isEmpty ? demoMyBody() : myBody,
      paBody: demo ? demoPartnerBody() : paBody,
    );
    void go(int i) => setState(() => tab = i);
    const items = [
      (Icons.home_outlined, '홈'),
      (Icons.fitness_center, '운동'),
      (Icons.calendar_month_outlined, '캘린더'),
      (Icons.monitor_weight_outlined, '기록'),
    ];
    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: [
          HomePage(data: data, go: go),
          // A running workout takes over the 운동 tab; other tabs stay usable meanwhile.
          if (activeWorkout.value case final w?)
            WorkoutView(s: w, onDone: () => go(0))
          else
            RoutinesPage(data: data, uid: myUid),
          CalendarPage(data: data),
          RecordsPage(data: data),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (demo)
            Container(
              width: double.infinity,
              color: coral,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '데모 짝꿍 미리보기 중 · 저장되지 않아요',
                textAlign: TextAlign.center,
                style: ts(12, color: ink, w: FontWeight.w700),
              ),
            ),
          Container(
            decoration: const BoxDecoration(
              color: navBg,
              border: Border(top: BorderSide(color: navLine)),
            ),
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: InkWell(
                        onTap: () => go(i),
                        child: SizedBox(
                          height: 56,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(items[i].$1, color: tab == i ? lime : navOff),
                              const SizedBox(height: 4),
                              if (i == 1 && activeWorkout.value != null)
                                // Running workout: show its clock under the 운동 icon.
                                ListenableBuilder(
                                  listenable: activeWorkout.value!,
                                  builder: (_, _) => Text(
                                    mmss(activeWorkout.value?.t.elapsedSec ?? 0),
                                    style: digits(12, color: lime),
                                  ),
                                )
                              else
                                Text(
                                  items[i].$2,
                                  style: ts(12, w: FontWeight.w600, color: tab == i ? lime : navOff),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

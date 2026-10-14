import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'db.dart';

/// Name typed on email sign-up or handed over by Apple (first login only); used when the profile is created.
String? pendingName;

/// Creates users/{uid} (+ starter routines) on first sign-in, whatever the provider.
/// Transaction so a cache miss can never overwrite an existing profile.
Future<void> createProfileIfMissing() async {
  final u = FirebaseAuth.instance.currentUser!;
  final ref = userDoc(u.uid);
  final name = [pendingName, u.displayName, u.email?.split('@').first].firstWhere(
      (s) => s != null && s.trim().isNotEmpty,
      orElse: () => '나')!.trim();
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = Random.secure();
  final created = await fs.runTransaction((tx) async {
    if ((await tx.get(ref)).exists) return false;
    tx.set(ref, {'name': name, 'code': List.generate(6, (_) => chars[r.nextInt(chars.length)]).join()});
    return true;
  });
  pendingName = null;
  if (!created) return;
  final batch = fs.batch();
  final routines = sampleRoutines(name);
  for (var i = 0; i < routines.length; i++) {
    batch.set(routinesOf(u.uid).doc(),
        {...routines[i], 'createdAt': Timestamp.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch + i)});
  }
  await batch.commit();
}

// Web OAuth client (google-services.json, client_type 3). Android needs it as serverClientId.
const _googleWebClientId = '382254231096-hordmbvk4q94cj3fva02t9nn8tcl9pnu.apps.googleusercontent.com';
bool _googleReady = false;

/// Returns normally on success or when the user cancels; throws with a readable message otherwise.
Future<void> signInWithGoogle() async {
  if (!_googleReady) {
    await GoogleSignIn.instance.initialize(
      clientId: Platform.isIOS ? Firebase.app().options.iosClientId : null,
      serverClientId: _googleWebClientId,
    );
    _googleReady = true;
  }
  try {
    final account = await GoogleSignIn.instance.authenticate(scopeHint: const ['email']);
    final idToken = account.authentication.idToken;
    if (idToken == null) throw Exception('Google 인증 토큰을 받지 못했어요');
    pendingName = account.displayName;
    await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
  } on GoogleSignInException catch (e) {
    if (e.code != GoogleSignInExceptionCode.canceled) rethrow;
  }
}

/// iOS only (Android would need Apple's web flow + a Services ID).
Future<void> signInWithApple() async {
  // Apple gets the SHA-256 of the nonce, Firebase gets the raw nonce.
  const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
  final rng = Random.secure();
  final rawNonce = List.generate(32, (_) => charset[rng.nextInt(charset.length)]).join();
  try {
    final c = await SignInWithApple.getAppleIDCredential(
      scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
    );
    if (c.identityToken == null) throw Exception('Apple 인증 토큰을 받지 못했어요');
    // Apple only sends the name on the very first authorization for this app.
    final name = [c.familyName, c.givenName].whereType<String>().join().trim();
    if (name.isNotEmpty) pendingName = name;
    await FirebaseAuth.instance
        .signInWithCredential(OAuthProvider('apple.com').credential(idToken: c.identityToken, rawNonce: rawNonce));
  } on SignInWithAppleAuthorizationException catch (e) {
    if (e.code != AuthorizationErrorCode.canceled) rethrow;
  }
}

const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/firestore');
const { setGlobalOptions } = require('firebase-functions/options');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

// Must match your Firestore database location (asia-northeast3 = Seoul).
setGlobalOptions({ region: 'asia-northeast3' });
initializeApp();
const db = getFirestore();

/** Partner uid + my name, only when the couple link is mutual. */
async function linkedPartner(uid) {
  const me = (await db.doc(`users/${uid}`).get()).data();
  if (!me?.partnerId) return null;
  const pa = (await db.doc(`users/${me.partnerId}`).get()).data();
  return pa?.partnerId === uid ? { uid: me.partnerId, myName: me.name } : null;
}

const GONE = ['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'];
const deadTokens = (tokens, responses) => tokens.filter((_, i) => GONE.includes(responses[i].error?.code));

async function push(uid, title, body) {
  const ref = db.doc(`users/${uid}/private/fcm`);
  const tokens = (await ref.get()).get('tokens') ?? [];
  if (!tokens.length) return;
  const res = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    apns: { payload: { aps: { sound: 'default' } } },
    android: { notification: { sound: 'default' } },
  });
  const dead = deadTokens(tokens, res.responses);
  if (dead.length) await ref.update({ tokens: FieldValue.arrayRemove(...dead) });
}

// Workout saved with "완료 알림 보내기" on → tell the partner.
exports.notifyWorkoutDone = onDocumentCreated('users/{uid}/sessions/{id}', async (e) => {
  const s = e.data?.data();
  if (!s?.notify) return;
  const p = await linkedPartner(e.params.uid);
  if (p) await push(p.uid, '짝꿍이 운동을 끝냈어요', `${p.myName}님이 ${s.routine} 루틴을 끝냈어요. 이제 내 차례!`);
});

/**
 * I just pointed partnerId at `target`. What does that mean?
 *  'accepted': they already point at me → we're linked now
 *  'invited':  I came via their invite link with the right token and they're free → link them too
 *  'request':  plain request, they must accept in the app
 */
function linkOutcome(uid, me, target, inviteToken) {
  if (target.partnerId === uid) return 'accepted';
  if (me.inviteToken && me.inviteToken === inviteToken && !target.partnerId) return 'invited';
  return 'request';
}

exports.onUserUpdated = onDocumentUpdated('users/{uid}', async (e) => {
  const before = e.data?.before.data() ?? {}, me = e.data?.after.data() ?? {}, uid = e.params.uid;

  // 콕 찌르기: nudgeAt changed to a new day → tell the partner.
  if (me.nudgeAt && me.nudgeAt !== before.nudgeAt) {
    const p = await linkedPartner(uid);
    if (p) await push(p.uid, '콕!', `${p.myName}님이 콕 찔렀어요. 오늘 운동 같이 해요!`);
  }

  // Link request / accept / invite link.
  if (me.partnerId && me.partnerId !== before.partnerId) {
    const targetRef = db.doc(`users/${me.partnerId}`), inviteRef = db.doc(`users/${me.partnerId}/private/invite`);
    // Transaction: a token can be spent once even if two people tap the link at the same moment.
    const outcome = await db.runTransaction(async (tx) => {
      const target = (await tx.get(targetRef)).data();
      if (!target) return null;
      const o = linkOutcome(uid, me, target, (await tx.get(inviteRef)).get('token'));
      if (o === 'invited') {
        tx.delete(inviteRef); // one-time token
        tx.update(targetRef, { partnerId: uid }); // re-triggers this function → 'accepted' push to the invitee
      }
      return o;
    });
    if (outcome === 'accepted') {
      await push(me.partnerId, '짝꿍과 연결됐어요', `${me.name}님과 연결됐어요. 이제 서로의 기록을 볼 수 있어요!`);
    } else if (outcome === 'invited') {
      await push(me.partnerId, '초대를 수락했어요', `${me.name}님과 연결됐어요!`);
    } else if (outcome === 'request') {
      await push(me.partnerId, '연결 요청', `${me.name}님이 짝꿍 연결을 요청했어요`);
    }
  }
});

exports.linkOutcome = linkOutcome; // for index.test.js
exports.deadTokens = deadTokens; // for index.test.js

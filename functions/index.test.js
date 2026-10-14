const test = require('node:test');
const assert = require('node:assert');
const { deadTokens, linkOutcome } = require('./index');

test('only unregistered/invalid tokens are pruned', () => {
  const responses = [
    { success: true },
    { success: false, error: { code: 'messaging/registration-token-not-registered' } },
    { success: false, error: { code: 'messaging/internal-error' } }, // transient: keep
    { success: false, error: { code: 'messaging/invalid-registration-token' } },
  ];
  assert.deepStrictEqual(deadTokens(['a', 'b', 'c', 'd'], responses), ['b', 'd']);
});

test('invite token links only a free inviter with the matching token', () => {
  const me = { inviteToken: 'tok' };
  assert.strictEqual(linkOutcome('me', me, { partnerId: 'me' }, 'tok'), 'accepted');
  assert.strictEqual(linkOutcome('me', me, {}, 'tok'), 'invited');
  assert.strictEqual(linkOutcome('me', me, {}, 'other'), 'request'); // wrong / reused token
  assert.strictEqual(linkOutcome('me', me, {}, undefined), 'request'); // token already consumed
  assert.strictEqual(linkOutcome('me', me, { partnerId: 'someone' }, 'tok'), 'request'); // inviter taken
  assert.strictEqual(linkOutcome('me', {}, {}, undefined), 'request'); // no token on either side
});

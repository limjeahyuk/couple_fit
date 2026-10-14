import 'package:couple_fit/invite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses https and custom-scheme invite links', () {
    expect(parseInvite(Uri.parse('https://x.web.app/invite/ab12cd?t=tok')), (code: 'AB12CD', token: 'tok'));
    expect(parseInvite(Uri.parse('couplefit://invite/AB12CD?t=tok')), (code: 'AB12CD', token: 'tok'));
    expect(parseInvite(Uri.parse('couplefit://invite/AB12CD')), (code: 'AB12CD', token: null));
    expect(parseInvite(Uri.parse('https://x.web.app/invite/AB12CD/')), (code: 'AB12CD', token: null));
  });

  test('ignores other links', () {
    expect(parseInvite(Uri.parse('https://x.web.app/')), isNull);
    expect(parseInvite(Uri.parse('https://x.web.app/other/AB12CD')), isNull);
    expect(parseInvite(Uri.parse('couplefit://settings/AB12CD')), isNull);
    expect(parseInvite(Uri.parse('couplefit://invite')), isNull);
  });
}

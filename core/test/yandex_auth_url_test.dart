/// The Yandex OAuth authorize link: what Yandex actually receives.
library;

import 'package:ms_core/ms_core.dart';
import 'package:test/test.dart';

void main() {
  test('parameters arrive decoded, exactly once', () {
    final url = yandexAuthorizeUrl(
      clientId: 'cid',
      redirectUri: 'http://127.0.0.1:8450/oauth',
      codeChallenge: 'abc-_X',
      state: 's 1',
    );
    final q = Uri.parse(url).queryParameters;
    expect(Uri.parse(url).host, 'oauth.yandex.ru');
    expect(q['redirect_uri'], 'http://127.0.0.1:8450/oauth');
    expect(q['client_id'], 'cid');
    expect(q['code_challenge'], 'abc-_X');
    expect(q['code_challenge_method'], 'S256');
    expect(q['response_type'], 'code');
    expect(q['state'], 's 1');
  });

  test('asks for the Disk rights registered for the app', () {
    final url = yandexAuthorizeUrl(
        clientId: 'cid', redirectUri: 'http://x/y', codeChallenge: 'c');
    expect(Uri.parse(url).queryParameters['scope']!.split(' '), [
      'cloud_api:disk.read',
      'cloud_api:disk.write',
      'cloud_api:disk.info',
    ]);
  });
}

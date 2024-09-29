@TestOn('vm')
library;

import 'package:dev_test/test.dart';
import 'package:tekartik_sc/src/scpath.dart';

void main() => defineTests();

void defineTests() {
  group('scpath', () {
    test('https', () async {
      // git
      expect(scUriToPathParts('https://bitbucket.org/alextk/public_git_test'),
          ['bitbucket.org', 'alextk', 'public_git_test']);
      // hg
      expect(scUriToPathParts('https://bitbucket.org/alextk/hg_data_test'),
          ['bitbucket.org', 'alextk', 'hg_data_test']);
      // github
      expect(scUriToPathParts('https://github.com/tekartik/sc.dart'),
          ['github.com', 'tekartik', 'sc.dart']);
    });

    test('ssh', () async {
      // github
      expect(scUriToPathParts('git@github.com:tekartik/sc.dart.git'),
          ['github.com', 'tekartik', 'sc.dart.git']);
    });
  });
}

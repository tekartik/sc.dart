@TestOn("vm")
library tekartik_sc.test.sc_test;

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/hg.dart';
import 'package:tekartik_sc/sc.dart';

import 'io_test_common.dart';

void main() => defineTests();

void defineTests() {
  group('sc', () {
    test('git', () async {
      bool _isGitSupported = await isGitSupported;

      if (_isGitSupported) {
        String outPath = clearOutTestPath();

        var prj = GitProject('https://bitbucket.org/alextk/public_git_test',
            path: outPath);
        await runCmd(prj.cloneCmd());

        expect(await isScTopLevelPath(outPath), isTrue);
        expect(await getScName(outPath), "git");
        expect(await findScTopLevelPath(outPath), outPath);
        String sub = join(outPath, "sub");
        expect(await findScTopLevelPath(sub), outPath);
        expect(await getScName(sub), isNull);
      }
    });

    test('hg', () async {
      bool _isHgSupported = await isHgSupported;

      if (_isHgSupported) {
        String outPath = clearOutTestPath();

        var prj = HgProject('https://bitbucket.org/alextk/hg_data_test',
            rootFolder: outPath);
        await runCmd(prj.cloneCmd());

        expect(await isScTopLevelPath(outPath), isTrue);
        expect(await getScName(outPath), "hg");
        expect(await findScTopLevelPath(outPath), outPath);
        String sub = join(outPath, "sub");
        expect(await findScTopLevelPath(sub), outPath);
        expect(await getScName(sub), isNull);
      }
    });
  });
}

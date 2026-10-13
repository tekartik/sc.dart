// ignore_for_file: avoid_print

@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/hg.dart';
import 'package:tekartik_sc/sc.dart';

import 'hg_test.dart';
import 'io_dev_test_common.dart';

void main() => defineTests();

void defineTests() {
  group('sc', () {
    test('git', () async {
      final testIsGitSupported = await isGitSupported;

      if (testIsGitSupported) {
        final outPath = normalize(absolute(clearOutTestPath()));

        var prj = GitProject(
          'https://bitbucket.org/alextk/public_git_test',
          path: outPath,
        );
        await runCmd(prj.cloneCmd());

        expect(await isScTopLevelPath(outPath), isTrue);
        expect(await getScName(outPath), 'git');
        expect(await findScTopLevelPath(outPath), outPath);
        final sub = join(outPath, 'sub');
        expect(await findScTopLevelPath(sub), outPath);
        expect(await getScName(sub), isNull);
      }
    });

    test('hg', () async {
      final testIsHgSupported = await isHgSupported;

      if (testIsHgSupported && !isRunningOnTravis()) {
        final outPath = normalize(absolute(clearOutTestPath()));

        var prj = HgProject(
          'https://bitbucket.org/alextk/hg_data_test',
          rootFolder: outPath,
        );
        await runCmd(prj.cloneCmd());

        expect(await isScTopLevelPath(outPath), isTrue);
        expect(await getScName(outPath), 'hg');
        expect(await findScTopLevelPath(outPath), outPath);
        final sub = join(outPath, 'sub');
        expect(await findScTopLevelPath(sub), outPath);
        expect(await getScName(sub), isNull);
      }
    }, skip: 'Bitbucket hg no longer supported');

    test('handleScPath', () async {
      // See sc_offline_git_test.dart for the recursive cases
      final dirs = <String>[];
      if (await isGitTopLevelPath(Directory.current.path)) {
        await handleScPath(join('.', 'test'), (dir) => dirs.add(dir));
        expect(dirs, [Directory.current.path]);
      }
    });
  });
}

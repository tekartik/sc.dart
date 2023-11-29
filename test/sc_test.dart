@TestOn('vm')
library tekartik_sc.test.sc_test;

import 'dart:async';
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

        var prj = GitProject('https://bitbucket.org/alextk/public_git_test',
            path: outPath);
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

        var prj = HgProject('https://bitbucket.org/alextk/hg_data_test',
            rootFolder: outPath);
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
      // find top path
      final dirs = <String>[];
      Future handle(String dir) async {
        dirs.add(dir);
      }

      try {
        var dir = dirname(Directory.current.path);
        dirs.clear();
        await handleScPath(dir, handle);
        expect(dirs.length, 0);

        await handleScPath(dir, handle, recursive: true);
        expect(dirs.length, greaterThan(1));
        expect(dirs, contains(Directory.current.path));

        dirs.clear();
        await handleScPath('..', handle, recursive: true);
        expect(dirs.length, greaterThan(1));
        expect(dirs, contains(Directory.current.path));
      } catch (e) {
        print('This could fail on travis if we cannot reach the parent folder');
        print(e);
      }
    });
  });
}

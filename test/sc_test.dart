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
import 'io_test_common.dart';

void main() => defineTests();

void defineTests() {
  group('sc', () {
    test('git', () async {
      final _isGitSupported = await isGitSupported;

      if (_isGitSupported) {
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
      final _isHgSupported = await isHgSupported;

      if (_isHgSupported && !isRunningOnTravis()) {
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
    });

    test('handleScPath', () async {
      // find top path
      final dirs = <String>[];
      Future handle(String dir) async {
        dirs.add(dir);
      }

      await handleScPath(null, handle, recursive: true);
      expect(dirs.length, 1);

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

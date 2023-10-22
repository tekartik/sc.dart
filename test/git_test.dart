@TestOn('vm')
library tekartik_sc.test.git_test;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:process_run/shell_run.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_sc/git.dart';

import 'io_test_common.dart';

Future main() async {
  //useVMConfiguration();
  final testIsGitSupported = isGitSupportedSync;
  group('Git', () {
    group('supported', () {
      test('check', () async {
        expect(checkGitSupportedSync(), testIsGitSupported);
        expect(await checkGitSupported(), testIsGitSupported);
      });
      test('missing', () {},
          skip: testIsGitSupported ? false : 'Git (Mercurial) not supported');
    });

    if (testIsGitSupported) {
      test('path', () {
        var giPath = GitPath('.');
        expect(giPath.path, '.');
      });

      test('isGitSupported', () async {
        expect(await isGitSupported, testIsGitSupported);
      });

      test('version', () async {
        if (testIsGitSupported) {
          final result = await runCmd(gitVersionCmd());
          // git version 1.9.1
          expect(result.stdout.toString().startsWith('git version'), isTrue);
        }
      });

      /*
    test('isGitTopLevelPath', () async {
      print(Platform.script);
      //await new Completer().future;
      expect(await isGitTopLevelPath(scriptDirPath), isFalse);
      expect(await isGitTopLevelPath(dirname(scriptDirPath)), isTrue, reason: dirname(scriptDirPath));
    });
    */

      test('isGitRepository1', () async {
        expect(
            await isGitRepository(
                'https://github.com/alextekartik/tekartik_io_tools.dart'),
            isTrue);
      });

      test('isGitRepository2', () async {
        expect(
            await isGitRepository(
                'https://github.com/alextekartik/tekartik_io_tools.dart_NO'),
            isFalse);
      });

      test('isGitRepository3', () async {
        try {
          expect(
              await isGitRepository(
                  'https://bitbucket.org/alextk/public_git_test'),
              isTrue);
        } on TestFailure catch (e) {
          await Shell().run(
              'git ls-remote --exit-code -h https://bitbucket.org/alextk/public_git_test');
          print('previous error $e');
          rethrow;
        }
      });

      // Skipped since 2020-08-29 asking for credentials with hg shutdown
      test('isGitRepository4', () async {
        expect(
            await isGitRepository('https://bitbucket.org/alextk/public_hg_test',
                verbose: true),
            isFalse);
      }, skip: true);

      group('bitbucket.org', () {
        test('bbGitProject', () async {
          if (testIsGitSupported) {
            final outPath = clearOutTestPath(testDescriptions);
            expect(await (isGitTopLevelPath(outPath)), isFalse);
            var prj = GitProject('https://bitbucket.org/alextk/public_git_test',
                path: outPath);
            await runCmd(prj.cloneCmd(depth: 1));
            expect(await (isGitTopLevelPath(outPath)), isTrue);
            var statusResult = await prj.status();
            expect(statusResult.nothingToCommit, true);
            expect(statusResult.branchIsAhead, false);

            final tempFile = File(join(prj.path, 'temp_file.txt'));
            await tempFile.writeAsString('echo', flush: true);
            statusResult = await prj.status();
            expect(statusResult.nothingToCommit, false);
            expect(statusResult.branchIsAhead, false);

            await runCmd(prj.addCmd(pathspec: '.'));
            final commitResult = await runCmd(prj.commitCmd('test'));
            // Needed to travis
            if (commitResult.exitCode == 0) {
              statusResult = await prj.status();
              expect(statusResult.nothingToCommit, true,
                  reason: processResultToDebugString(statusResult.runResult));
            }
            // not supported for empty repository
            //expect(statusResult.branchIsAhead, true);
          }
        });
      });

      group('github.com', () {
        test('GitProject', () async {
          if (testIsGitSupported) {
            final outPath = clearOutTestPath(testDescriptions);
            expect(await (isGitTopLevelPath(outPath)), isFalse);
            var prj = GitProject(
                'https://github.com/alextekartik/data_test.git',
                path: outPath);
            await runCmd(prj.cloneCmd());
            expect(await (isGitTopLevelPath(outPath)), isTrue);
            var statusResult = await prj.status();
            expect(statusResult.nothingToCommit, true);
            expect(statusResult.branchIsAhead, false);

            final tempFile = File(join(prj.path, 'temp_file.txt'));
            await tempFile.writeAsString('echo', flush: true);
            statusResult = await prj.status();
            expect(statusResult.nothingToCommit, false);
            expect(statusResult.branchIsAhead, false);

            await runCmd(prj.addCmd(pathspec: '.'));
            final commitResult = await runCmd(prj.commitCmd('test'));
            // Needed to travis
            if (commitResult.exitCode == 0) {
              statusResult = await prj.status();
              expect(statusResult.nothingToCommit, true,
                  reason: processResultToDebugString(statusResult.runResult));
              expect(statusResult.branchIsAhead, true);
            }
          }
        });
      });

      group('gitlab.com', () {
        test('GitProject', () async {
          if (testIsGitSupported) {
            final outPath = clearOutTestPath(testDescriptions);
            expect(await (isGitTopLevelPath(outPath)), isFalse);
            var prj = GitProject('https://gitlab.com/tkexp/branch_exp.git',
                path: outPath);
            await runCmd(prj.cloneCmd());
            expect(await (isGitTopLevelPath(outPath)), isTrue);
            var statusResult = await prj.status();
            expect(statusResult.nothingToCommit, true);
            expect(statusResult.branchIsAhead, false);

            final tempFile = File(join(prj.path, 'temp_file.txt'));
            await tempFile.writeAsString('echo', flush: true);
            statusResult = await prj.status();
            expect(statusResult.nothingToCommit, false);
            expect(statusResult.branchIsAhead, false);

            await runCmd(prj.addCmd(pathspec: '.'));
            final commitResult = await runCmd(prj.commitCmd('test'));
            // Needed to travis
            if (commitResult.exitCode == 0) {
              statusResult = await prj.status();
              expect(statusResult.nothingToCommit, true,
                  reason: processResultToDebugString(statusResult.runResult));
              expect(statusResult.branchIsAhead, true);
            }
          }
        });

        test('branches', () async {
          var gitPath = GitPath('.');
          var branches = await gitPath.getBranches();
          expect(branches, isNotEmpty);
          var currentBranch = await gitPath.getCurrentBranch();
          expect(branches, contains(currentBranch));
        });
      });
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}

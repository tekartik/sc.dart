@TestOn("vm")
library tekartik_sc.test.git_test;

import 'package:tekartik_sc/git.dart';
import 'package:process_run/cmd_run.dart';
import 'dart:io';
import 'io_test_common.dart';
import 'package:path/path.dart';

void main() {
  //useVMConfiguration();
  group('git', () {
    bool _isGitSupported;

    setUp(() async {
      if (_isGitSupported == null) {
        _isGitSupported = await isGitSupported;
      }
    });

    test('isGitSupported', () async {
      expect(await isGitSupported, _isGitSupported);
    });

    test('version', () async {
      if (_isGitSupported) {
        ProcessResult result = await runCmd(gitVersionCmd());
        // git version 1.9.1
        expect(result.stdout.startsWith("git version"), isTrue);
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

    test('isGitRepository', () async {
      expect(
          await isGitRepository(
              'https://github.com/alextekartik/tekartik_io_tools.dart'),
          isTrue);
      expect(
          await isGitRepository(
              'https://github.com/alextekartik/tekartik_io_tools.dart_NO'),
          isFalse);
      expect(
          await isGitRepository('https://bitbucket.org/alextk/public_git_test'),
          isTrue);
      expect(
          await isGitRepository('https://bitbucket.org/alextk/public_hg_test'),
          isFalse);
    });

    group('bitbucket.org', () {
      test('GitProject', () async {
        if (_isGitSupported) {
          String outPath = clearOutTestPath(testDescriptions);
          expect(await (isGitTopLevelPath(outPath)), isFalse);
          var prj = new GitProject(
              'https://bitbucket.org/alextk/public_git_test',
              rootFolder: outPath);
          await runCmd(prj.cloneCmd());
          expect(await (isGitTopLevelPath(outPath)), isTrue);
          GitStatusResult statusResult = await prj.status();
          expect(statusResult.nothingToCommit, true);
          expect(statusResult.branchIsAhead, false);

          File tempFile = new File(join(prj.path, "temp_file.txt"));
          await tempFile.writeAsString("echo");
          statusResult = await prj.status();
          expect(statusResult.nothingToCommit, false);
          expect(statusResult.branchIsAhead, false);

          await runCmd(prj.addCmd(pathspec: "."));
          await runCmd(prj.commitCmd("test"));
          statusResult = await prj.status();
          expect(statusResult.nothingToCommit, true);
          // not supported for empty repository
          //expect(statusResult.branchIsAhead, true);
        }
      });
    });

    group('github.com', () {
      test('GitProject', () async {
        if (_isGitSupported) {
          String outPath = clearOutTestPath(testDescriptions);
          expect(await (isGitTopLevelPath(outPath)), isFalse);
          var prj = new GitProject(
              'https://github.com/alextekartik/data_test.git',
              rootFolder: outPath);
          await runCmd(prj.cloneCmd());
          expect(await (isGitTopLevelPath(outPath)), isTrue);
          GitStatusResult statusResult = await prj.status();
          expect(statusResult.nothingToCommit, true);
          expect(statusResult.branchIsAhead, false);

          File tempFile = new File(join(prj.path, "temp_file.txt"));
          await tempFile.writeAsString("echo");
          statusResult = await prj.status();
          expect(statusResult.nothingToCommit, false);
          expect(statusResult.branchIsAhead, false);

          await runCmd(prj.addCmd(pathspec: "."));
          await runCmd(prj.commitCmd("test"));
          statusResult = await prj.status();
          expect(statusResult.nothingToCommit, true);
          expect(statusResult.branchIsAhead, true);
        }
      });
    });
  });
}

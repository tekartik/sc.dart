@TestOn("vm")
library tekartik_sc.test.hg_test;

import 'package:tekartik_sc/hg.dart';
import 'package:process_run/cmd_run.dart';
import 'dart:io';
import 'io_test_common.dart';
import 'package:path/path.dart';

void main() => defineTests();

void defineTests() {
  //useVMConfiguration();
  group('hg', () {
    bool _isHgSupported;

    setUp(() async {
      if (_isHgSupported == null) {
        _isHgSupported = await isHgSupported;
      }
    });

    test('isHgSupported', () async {
      expect(await isHgSupported, _isHgSupported);
    });
    test('version', () async {
      if (_isHgSupported) {
        ProcessResult result = await runCmd(hgVersionCmd());
        // git version 1.9.1
        expect(result.stdout.startsWith("Mercurial Distributed SCM"), isTrue);
      }
    });

    /*
    test('isHgTopLevelPath', () async {
      print(Platform.script);
      //await new Completer().future;
      expect(await isHgTopLevelPath(scriptDirPath), isFalse);
      expect(await isHgTopLevelPath(dirname(scriptDirPath)), isTrue, reason: dirname(scriptDirPath));
    });
    */
    test('isHgRepository', () async {
      if (_isHgSupported) {
        expect(
            await isHgRepository('https://bitbucket.org/alextk/public_hg_test'),
            isTrue);
        expect(
            await isHgRepository(
                'https://bitbucket.org/alextk/public_hg_test_NO'),
            isFalse);
        expect(
            await isHgRepository(
                'https://bitbucket.org/alextk/public_git_test'),
            isFalse);
      }
    });

    test('HgProject', () async {
      if (_isHgSupported) {
        String outPath = clearOutTestPath(testDescriptions);
        var prj = HgProject('https://bitbucket.org/alextk/hg_data_test',
            rootFolder: outPath);
        expect(await (isHgTopLevelPath(outPath)), isFalse);
        await runCmd(prj.cloneCmd());
        expect(await (isHgTopLevelPath(outPath)), isTrue);
        HgStatusResult statusResult = await prj.status();
        expect(statusResult.nothingToCommit, true);
        HgOutgoingResult outgoingResult = await prj.outgoing();
        expect(outgoingResult.branchIsAhead, false);

        File tempFile = File(join(prj.path, "temp_file.txt"));
        await tempFile.writeAsString("echo");
        statusResult = await prj.status();
        expect(statusResult.nothingToCommit, false);
        outgoingResult = await prj.outgoing();
        expect(outgoingResult.branchIsAhead, false);

        await runCmd(prj.addCmd(pathspec: "."));
        await runCmd(prj.commitCmd("test"));
        statusResult = await prj.status();
        expect(statusResult.nothingToCommit, true);
        outgoingResult = await prj.outgoing();
        expect(outgoingResult.branchIsAhead, true);
      }
    });
  });
}

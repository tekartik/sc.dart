@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_common_utils/bool_utils.dart';
import 'package:tekartik_sc/hg.dart';

import 'io_dev_test_common.dart';

void main() => defineTests();

void defineTests() {
  //useVMConfiguration();
  group('hg', () {
    bool? testIsHgSupported;

    setUp(() async {
      testIsHgSupported ??= await isHgSupported;
    });

    group('hgSupported', () async {
      if (!isRunningOnTravis()) {
        // to debug travis issues
        test('verbose', () async {
          expect(
              await isHgRepository(
                  'https://bitbucket.org/alextk/public_hg_test',
                  verbose: true,
                  insecure: true),
              isTrue);
        }, skip: 'Bitbucket hg no longer supported');

        // expect(await isHgSupported, true);
        test('isHgRepository insecure', () async {
          expect(
              await isHgRepository(
                  'https://bitbucket.org/alextk/public_hg_test',
                  insecure: true),
              isTrue);
          expect(
              await isHgRepository(
                  'https://bitbucket.org/alextk/public_hg_test_NO',
                  insecure: true),
              isFalse);
          expect(
              await isHgRepository(
                  'https://bitbucket.org/alextk/public_git_test',
                  insecure: true),
              isFalse);
        }, skip: 'Bitbucket hg no longer supported');
      }
      // only works locally
      test('isHgRepository secure', () async {
        if (testIsHgSupported!) {
          expect(
              await isHgRepository(
                  'https://bitbucket.org/alextk/public_hg_test'),
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
      }, skip: true);
    }, skip: !isHgSupportedSync && isRunningOnTravis());

    test('isHgSupported', () async {
      expect(await isHgSupported, testIsHgSupported);
    });
    test('version', () async {
      if (testIsHgSupported!) {
        final result = await runCmd(hgVersionCmd());
        // git version 1.9.1
        expect(result.stdout.toString().startsWith('Mercurial Distributed SCM'),
            isTrue);
        // print for travis debugging
        print('\$ ${hgVersionCmd()}');
        print(result.stdout);
      } else {
        print('hg not supported');
        if (checkHgSupportDisabled) {
          print('hg disabled by env TEKARTIK_HG_SUPPORT');
        }
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

    test('HgProject', () async {
      if (testIsHgSupported!) {
        final outPath = clearOutTestPath(testDescriptions);
        var prj = HgProject('https://bitbucket.org/alextk/hg_data_test',
            rootFolder: outPath);
        expect(await (isHgTopLevelPath(outPath)), isFalse);
        await runCmd(prj.cloneCmd(), verbose: true);
        expect(await (isHgTopLevelPath(outPath)), isTrue);
        var statusResult = await prj.status(verbose: true);
        expect(statusResult.nothingToCommit, true);
        var outgoingResult = await prj.outgoing();
        expect(outgoingResult.branchIsAhead, false);

        final tempFile = File(join(prj.path, 'temp_file.txt'));
        await tempFile.writeAsString('echo');
        statusResult = await prj.status();
        expect(statusResult.nothingToCommit, false);
        outgoingResult = await prj.outgoing();
        expect(outgoingResult.branchIsAhead, false);

        await runCmd(prj.addCmd(pathspec: '.'));
        await runCmd(prj.commitCmd('test'), verbose: true);
        statusResult = await prj.status(verbose: true);
        expect(statusResult.nothingToCommit, true);
        outgoingResult = await prj.outgoing();
        expect(outgoingResult.branchIsAhead, true);
      }
    }, skip: 'Bitbucket hg no longer supported');
    //skip: isRunningOnTravis());
  });
}

bool? _isRunningOnTravis;
bool isRunningOnTravis() => _isRunningOnTravis ??= () {
      var onTravis = parseBool(Platform.environment['TRAVIS']) ?? false;
      print('Running on travis: $onTravis');
      return onTravis;
    }();

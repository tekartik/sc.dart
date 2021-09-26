@TestOn('vm')
library tekartik_sc.test.bin_scpull_test;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/src/bin_version.dart';

import 'bin_test.dart';
import 'io_test_common.dart';

String get scppDartScript {
  return join(exampleBinPath, 'scpp.dart');
}

void main() {
  //useVMConfiguration();
  group('scpp', () {
    test('version', () async {
      final result = await runCmd(DartCmd([scppDartScript, '--version']));
      final parts =
          LineSplitter.split(result.stdout as String).first.split(' ');
      expect(parts.first, 'scpp');
      expect(Version.parse(parts.last), version);
    });
    if (isGitSupportedSync) {
      Future<bool> clone(GitProject prj) async {
        var result = await runCmd(prj.cloneCmd());
        //devPrint(result.exitCode);
        return result.exitCode == 0;
      }

      // skip with $env:TRAVIS = 'true'
      test('push no change', () async {
        final outPath = clearOutTestPath(testDescriptions);
        expect(await (isGitTopLevelPath(outPath)), isFalse);
        expect(await (isGitTopLevelPath(outPath)), isFalse);
        var prj =
            GitProject('git@gitlab.com:tkexp/branch_exp.git', path: outPath);
        if (await clone(prj)) {
          final result = await runCmd(DartCmd(['run', scppDartScript, '-v']));
          final output = result.stdout.toString();
          expect(output, contains('no push'));
          expect(output, contains('not ahead'));
        } else {
          stdout.writeln(
              'Cannot test scpp - write access require to git@gitlab.com:tkexp/branch_exp.git');
        }
      }, timeout: const Timeout(Duration(minutes: 2)), skip: runningInTravis);
    }
  });
}

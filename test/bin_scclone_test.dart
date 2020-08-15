@TestOn('vm')
library tekartik_sc.test.bin_scpull_test;

import 'dart:convert';
import 'dart:io';

import 'package:dev_test/test.dart';
import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:tekartik_sc/hg.dart' as hg;
import 'package:tekartik_sc/src/bin_version.dart';

import 'bin_test.dart';
import 'hg_test.dart';
import 'io_test_common.dart';

String get sccloneDartScript {
  return join(exampleBinPath, 'scclone.dart');
}

void main() {
  //useVMConfiguration();
  group('scclone', () {
    test('version', () async {
      final result = await runCmd(DartCmd([sccloneDartScript, '--version']));
      final parts =
          LineSplitter.split(result.stdout as String).first.split(' ');
      expect(parts.first, 'scclone');
      expect(Version.parse(parts.last), version);
    });
    test('scclone_hg', () async {
      if (await hg.isHgSupported && !isRunningOnTravis()) {
        // check hg location
        final outPath = clearOutTestPath(testDescriptions);
        final result = await runCmd(DartCmd(
            [sccloneDartScript, 'https://bitbucket.org/alextk/public_hg_test'])
          ..workingDirectory = outPath);
        expect(result.exitCode, 0);
        final file = File(join(outPath, 'hg', 'bitbucket.org', 'alextk',
            'public_hg_test', 'one_file.txt'));
        expect(file.existsSync(), isTrue);
      }
    }, skip: true); // No more hg
  });
}

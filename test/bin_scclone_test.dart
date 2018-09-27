@TestOn("vm")
library tekartik_sc.test.bin_scpull_test;

import 'dart:convert';
import 'dart:io';

import 'package:dev_test/test.dart';
import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:tekartik_pub/io.dart';
import 'package:tekartik_sc/hg.dart' as hg;
import 'package:tekartik_sc/src/bin_version.dart';

import 'io_test_common.dart';

String get _pubPackageRoot => normalize(absolute('.'));

String get sccloneDartScript {
  PubPackage pkg = PubPackage(_pubPackageRoot);
  return join(pkg.path, 'bin', 'scclone.dart');
}

void main() {
  //useVMConfiguration();
  group('scclone', () {
    test('version', () async {
      ProcessResult result =
          await runCmd(dartCmd([sccloneDartScript, '--version']));
      List<String> parts =
          LineSplitter.split(result.stdout as String).first.split(' ');
      expect(parts.first, 'scclone');
      expect(Version.parse(parts.last), version);
    });
    test('scclone_hg', () async {
      if (await hg.isHgSupported) {
        // check hg location
        String outPath = clearOutTestPath(testDescriptions);
        ProcessResult result = await runCmd(dartCmd(
            [sccloneDartScript, 'https://bitbucket.org/alextk/public_hg_test'])
          ..workingDirectory = outPath);
        expect(result.exitCode, 0);
        File file = File(join(outPath, 'hg', 'bitbucket.org', 'alextk',
            'public_hg_test', 'one_file.txt'));
        expect(await file.exists(), isTrue);
      }
    });
  });
}

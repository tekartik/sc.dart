@TestOn("vm")
library tekartik_sc.test.bin_scpull_test;

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:dev_test/test.dart';
import 'package:tekartik_pub/pub.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:tekartik_sc/src/bin_version.dart';
import 'dart:io';
import 'package:tekartik_sc/hg.dart' as hg;
import 'io_test_common.dart';
import 'dart:convert';

String get _pubPackageRoot => getPubPackageRootSync(testDirPath);

String get sccloneDartScript {
  PubPackage pkg = new PubPackage(_pubPackageRoot);
  return join(pkg.path, 'bin', 'scclone.dart');
}

void main() {
  //useVMConfiguration();
  group('scclone', () {
    test('version', () async {
      ProcessResult result =
          await runCmd(dartCmd([sccloneDartScript, '--version']));
      List<String> parts = LineSplitter.split(result.stdout).first.split(' ');
      expect(parts.first, 'scclone');
      expect(new Version.parse(parts.last), version);
    });
    test('scclone_hg', () async {
      if (await hg.isHgSupported) {
        // check hg location
        String outPath = clearOutTestPath(testDescriptions);
        ProcessResult result =
        await runCmd(dartCmd([sccloneDartScript, 'https://bitbucket.org/alextk/public_hg_test'])..workingDirectory = outPath);
        expect(result.exitCode, 0);
        File file = new File(join(outPath, 'hg', 'bitbucket.org', 'alextk', 'public_hg_test', 'one_file.txt'));
        expect(await file.exists(), isTrue);

      }

    });
  });
}

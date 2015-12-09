@TestOn("vm")
library tekartik_sc.test.bin_scpull_test;

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:dev_test/test.dart';
import 'package:tekartik_pub/pub.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:tekartik_sc/src/bin_version.dart';
import 'dart:io';
import 'io_test_common.dart';

String get _pubPackageRoot => getPubPackageRootSync(testDirPath);

String get scpullDartScript {
  PubPackage pkg = new PubPackage(_pubPackageRoot);
  return join(pkg.path, 'bin', 'scpp.dart');
}

void main() {
  //useVMConfiguration();
  group('scpp', () {
    test('version', () async {
      ProcessResult result =
          await runCmd(dartCmd([scpullDartScript, '--version']));
      List<String> parts = (result.stdout as String).split(' ');
      expect(parts.first, 'scpp');
      expect(new Version.parse(parts.last), version);
    });
  });
}

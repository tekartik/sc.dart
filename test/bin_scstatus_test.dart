@TestOn("vm")
library tekartik_sc.test.bin_scstatus_test;

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:dev_test/test.dart';
import 'package:tekartik_pub/pub.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:tekartik_sc/src/bin_version.dart';
import 'dart:io';
import 'io_test_common.dart';

String get _pubPackageRoot => getPubPackageRootSync(testDirPath);

String get scstatusDartScript {
  PubPackage pkg = new PubPackage(_pubPackageRoot);
  return join(pkg.path, 'bin', 'scstatus.dart');
}

void main() {
  //useVMConfiguration();
  group('scstatus', () {
    test('version', () async {
      ProcessResult result =
          await runCmd(dartCmd([scstatusDartScript, '--version']));
      List<String> parts = (result.stdout as String).split(' ');
      expect(parts.first, 'scstatus');
      expect(new Version.parse(parts.last), version);
    });
  });
}

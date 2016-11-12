@TestOn("vm")
library tekartik_sc.test.bin_scpull_test;

import 'dart:convert';
import 'dart:io';

import 'package:dev_test/test.dart';
import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:tekartik_pub/io.dart';
import 'package:tekartik_sc/src/bin_version.dart';

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
      List<String> parts = LineSplitter.split(result.stdout).first.split(' ');
      expect(parts.first, 'scpp');
      expect(new Version.parse(parts.last), version);
    });
  });
}

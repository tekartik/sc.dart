@TestOn("vm")
library tekartik_sc.test.bin_test;

import 'package:path/path.dart';
import 'package:dev_test/test.dart';
import 'package:tekartik_pub/pub.dart';
import 'package:tekartik_pub/pubspec.dart';
import 'package:tekartik_sc/src/bin_version.dart';
import 'io_test_common.dart';

String get _pubPackageRoot => getPubPackageRootSync(testDirPath);

String get pubTestDartScript {
  PubPackage pkg = new PubPackage(_pubPackageRoot);
  return join(pkg.path, 'bin', 'pubtest.dart');
}

void main() {
  //useVMConfiguration();
  group('pubtest', () {
    test('src.version', () async {
      expect(version, await extractPubspecYamlVersion(_pubPackageRoot));
    });
  });
}

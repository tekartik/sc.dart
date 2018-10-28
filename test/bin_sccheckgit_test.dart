@TestOn("vm")
library tekartik_sc.test.bin_sccheckgit_test;

import 'package:dev_test/test.dart';
import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_pub/io.dart';
import 'package:tekartik_sc/git.dart';

import 'io_test_common.dart';

String get _pubPackageRoot => normalize(absolute('.'));

String get sccheckgitDartScript {
  PubPackage pkg = PubPackage(_pubPackageRoot);
  return join(pkg.path, 'bin', 'sccheckgit.dart');
}

void main() {
  //useVMConfiguration();
  group('sccheckgit', () {
    test('run', () async {
      if (await isGitSupported) {
        await runCmd(DartCmd([sccheckgitDartScript]));
      }
    });
  });
}

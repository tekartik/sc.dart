import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''

  dartanalyzer --fatal-warnings --fatal-infos lib test tool
  dartfmt -w lib test tool --set-exit-if-changed

  pub run test -p vm -j 1
  # pub run build_runner test -- -p vm -j 1 test/multiplatform
  
  pub run test -p chrome -j 1
  ''');

  /*
  // Fails on Dart 2.1.1
  var dartVersion = parsePlatformVersion(Platform.version);
  if (dartVersion >= Version(2, 2, 0, pre: 'dev')) {
    await shell.run('''
    # pub run build_runner test -- -p vm -j 1 test/multiplatform test/vm
    # Currently running as 2 commands
    pub run build_runner test -- -p chrome -j 1 test/web
    pub run build_runner test -- -p chrome -j 1 test/multiplatform
  ''');
  }

  await shell.run('''
  # test dartdevc support
  pub run build_runner build example -o example:build/example_debug
  pub run build_runner build -r example -o example:build/example_release

  ''');

   */
}

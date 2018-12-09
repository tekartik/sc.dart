library tekartik_io_tools.io_common;

import 'package:path/path.dart';
import 'dart:io';
import 'package:dev_test/test.dart';
import 'package:tekartik_common_utils/bool_utils.dart';
export 'package:dev_test/test.dart';

String get outDataPath => getOutTestPath(testDescriptions);

String getOutTestPath([List<String> parts]) {
  if (parts == null) {
    parts = testDescriptions;
  }
  return join('.dart_tool', 'tekartik_sc', 'test', joinAll(parts));
}

String clearOutTestPath([List<String> parts]) {
  String outPath = getOutTestPath(parts);
  try {
    Directory(outPath).deleteSync(recursive: true);
  } catch (e) {}
  try {
    Directory(outPath).createSync(recursive: true);
  } catch (e) {}
  return outPath;
}

bool get runningInTravis {
  return parseBool(Platform.environment['TRAVIS']) == true;
}

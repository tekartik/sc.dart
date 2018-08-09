library tekartik_io_tools.io_common;

import 'package:path/path.dart';
import 'dart:io';
import 'package:dev_test/test.dart';
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
    new Directory(outPath).deleteSync(recursive: true);
  } catch (e) {}
  try {
    new Directory(outPath).createSync(recursive: true);
  } catch (e) {}
  return outPath;
}

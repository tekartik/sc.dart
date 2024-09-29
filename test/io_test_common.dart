library;

import 'dart:io';

import 'package:path/path.dart';

export 'package:test/test.dart';

String get outDataPath => join('.dart_tool', 'tekartik', 'sc.dart', 'test');

String getOutTestPath(String path) {
  return join(outDataPath, path);
}

String clearOutTestPath(String path) {
  final outPath = getOutTestPath(path);
  try {
    Directory(outPath).deleteSync(recursive: true);
  } catch (_) {}
  try {
    Directory(outPath).createSync(recursive: true);
  } catch (_) {}
  return outPath;
}

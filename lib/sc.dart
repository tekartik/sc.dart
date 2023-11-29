library tekartik_sc.sc;

import 'dart:async';

import 'package:tekartik_sc/src/scpath.dart';

import 'git.dart';
import 'hg.dart';

export 'src/scpath.dart' show handleScPath;

String git = 'git';
String hg = 'hg';

///
/// Check whether the path is a mercurial or git path
///
Future<bool> isScTopLevelPath(String path) async {
  return ((await getScName(path)) != null);
}

///
/// Only valid at the current path
///
Future<String?> getScName(String path) async {
  if (await isGitTopLevelPath(path)) {
    return git;
  }
  if (await isHgTopLevelPath(path)) {
    return hg;
  }
  return null;
}

///
/// checking recursively the parent for any hg or git directory
///
Future<String?> findScTopLevelPath(String path) async {
  return await pathFindTopLevelPath(path, pathIsTopLevel: isScTopLevelPath);
}

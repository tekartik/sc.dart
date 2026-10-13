library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:pool/pool.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/hg.dart';
import 'package:tekartik_sc/sc.dart';

/// Convert a uri to a convenient path part
/// removing user information and scheme
List<String> scUriToPathParts(String uri) {
  List<String> parts;
  String domain;
  try {
    final parseUri = Uri.parse(uri);
    parts = posix.split(parseUri.path);
    domain = parseUri.host;
  } on FormatException catch (_) {
    // ssh? something like git@github.com:tekartik/sc.dart.git
    // find first part (before :)
    final domainParts = uri.split(':');
    domain = domainParts[0];
    parts = posix.split(domainParts[1]);
  }

  // remove root if any
  if (parts[0] == '/') {
    parts = parts.sublist(1);
  }
  // remove user information from domain

  final userInfoIndex = domain.indexOf('@');
  if (userInfoIndex != -1) {
    domain = domain.substring(userInfoIndex + 1);
  }

  parts.insert(0, domain);

  // remove tilde ~ which causes issue
  final tildeIndex = parts.indexOf('~');
  if (tildeIndex != -1) {
    parts.removeAt(tildeIndex);
  }
  return parts;
}

int _recursiveHandleScPathPoolSize = 10;

/// Must be called before running any command.
int get recursiveHandleScPathPoolSize => _recursiveHandleScPathPoolSize;

/// Update the pool size.
set recursiveHandleScPathPoolSize(int value) {
  _recursiveHandleScPathPoolSize = value;
  _pool = Pool(recursiveHandleScPathPoolSize);
}

/// Needed for MacOS...
var _pool = Pool(recursiveHandleScPathPoolSize);

/// Handles source control paths recursively or at the top level.
///
/// When going recursive, an error thrown by [handleScDir] for a sub path is
/// reported on stderr and the other paths are still handled.
Future handleScPath(
  String dir,
  dynamic Function(String dir) handleScDir, {
  bool? recursive,
}) => _handleScPath(dir, handleScDir, recursive: recursive ?? false);

Future<void> _handleScPath(
  String dir,
  dynamic Function(String dir) handleScDir, {
  required bool recursive,
}) async {
  dir = normalize(absolute(dir));
  var topDir = await findScTopLevelPath(dir);

  // We are in a git, don't recurse)
  if (topDir != null) {
    await _pool.withResource(() async => await handleScDir(topDir));
  } else {
    if (recursive) {
      List<FileSystemEntity> entities;
      try {
        entities = await Directory(dir).list().toList();
      } on FileSystemException catch (_) {
        // Not readable, ignore
        return;
      }
      await Future.wait(
        entities
            .map((entity) => entity.path)
            // Ignore folder starting with .
            // don't event go below
            .where(
              (path) =>
                  !basename(path).startsWith('.') &&
                  FileSystemEntity.isDirectorySync(path),
            )
            .map((path) => _handleSubScPath(path, handleScDir)),
      );
    } else {
      stderr.writeln('$dir does not belong to source control');
    }
  }
}

/// A sub path error is reported, the other paths are still handled.
Future<void> _handleSubScPath(
  String path,
  dynamic Function(String dir) handleScDir,
) async {
  try {
    await _handleScPath(path, handleScDir, recursive: true);
  } catch (e, st) {
    stderr.writeln('error: $path: $e');
    stderr.writeln(st);
  }
}

/// Checks if the path is a git repository and git is supported.
Future<bool> isGitPathAndSupported(String path) async {
  return await isGitSupported && await isGitTopLevelPath(path);
}

/// Checks if the path is a git repository, supported, and not skipped.
Future<bool> isGitPathAndScSupported(String path) async {
  if (await isGitPathAndSupported(path)) {
    var skipRunCiFilePath = join(path, '.local', '.skip_sc');
    if (File(skipRunCiFilePath).existsSync()) {
      stderr.writeln('Skipping $path');
    } else {
      return true;
    }
  }
  return false;
}

/// Checks if the path is an hg repository and hg is supported.
Future<bool> isHgPathAndSupported(String path) async {
  return await isHgSupported && await isHgTopLevelPath(path);
}

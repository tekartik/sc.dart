library tekartik_io_tools.src.scpath;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:pool/pool.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/hg.dart';
import 'package:tekartik_sc/sc.dart';

///
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

Future handleScPath(String dir, dynamic Function(String dir) handleScDir,
    {bool? recursive}) async {
  recursive ??= false;
  dir = normalize(absolute(dir));
  var topDir = await findScTopLevelPath(dir);

  // We are in a git, don't recurse)
  if (topDir != null) {
    await _pool.withResource(() => handleScDir(topDir));
  } else {
    if (recursive) {
      try {
        final sub = <Future>[];
        await Directory(dir).list().listen((FileSystemEntity fse) {
          sub.add(() async {
            var path = fse.path;
            // Ignore folder starting with .
            // don't event go below
            if (!basename(path).startsWith('.') &&
                (FileSystemEntity.isDirectorySync(dir))) {
              await handleScPath(fse.path, handleScDir, recursive: recursive);
            }
          }());
        }).asFuture<void>();
        await Future.wait(sub);
      } catch (_) {}
    } else {
      stderr.writeln('$dir does not belong to source control');
    }
  }
}

Future<bool> isGitPathAndSupported(String path) async {
  return await isGitSupported && await isGitTopLevelPath(path);
}

Future<bool> isGitPathAndScSupported(String path) async {
  if (await isGitPathAndSupported(path)) {
    var skipRunCiFilePath = join(path, '.local', '.skip_sc');
    if (File(skipRunCiFilePath).existsSync()) {
      stderr.writeln('Skipping $path');
      return true;
    }
  }
  return false;
}

Future<bool> isHgPathAndSupported(String path) async {
  return await isHgSupported && await isHgTopLevelPath(path);
}

///
/// checking recursively the parent for any hg or git directory
///
Future<String?> pathFindTopLevelPath(String path,
    {FutureOr<bool> Function(String path)? pathIsTopLevel}) async {
  path = normalize(absolute(path));
  String parent;
  var checkFn = pathIsTopLevel ?? isScTopLevelPath;
  while (true) {
    if (FileSystemEntity.isDirectorySync(path)) {
      if (await checkFn(path)) {
        return path;
      }
    }
    parent = dirname(path);
    if (parent == path) {
      break;
    }
    path = parent;
  }
  return null;
}

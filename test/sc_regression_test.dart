@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/process_run.dart' show runExecutableArguments;
import 'package:process_run/shell.dart' show dartExecutable;
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/sc.dart';
import 'package:test/test.dart';

/// Run git in [dir], with a test identity, failing on error.
Future<void> _git(String dir, List<String> args) async {
  var result = await runExecutableArguments('git', [
    '-c',
    'user.name=test',
    '-c',
    'user.email=test@example.com',
    '-c',
    'init.defaultBranch=main',
    ...args,
  ], workingDirectory: dir);
  if (result.exitCode != 0) {
    throw StateError('git $args in $dir failed: ${result.stderr}');
  }
}

/// Create a git repository in [dir] with one commit.
Future<String> _createRepo(String dir) async {
  await Directory(dir).create(recursive: true);
  await _git(dir, ['init', '-b', 'main']);
  await File(join(dir, 'f')).writeAsString('1');
  await _git(dir, ['add', 'f']);
  await _git(dir, ['commit', '-m', 'init']);
  return dir;
}

/// The repositories handled by [handleScPath] from [dir] (recursive).
Future<List<String>> _handledPaths(String dir) async {
  var paths = <String>[];
  await handleScPath(dir, (path) {
    paths.add(path);
  }, recursive: true).timeout(const Duration(seconds: 20));
  return paths..sort();
}

/// Regression tests, local repositories only (no network).
void main() {
  late Directory temp;
  late String top;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('tekartik_sc_regression_');
    // Resolved, /tmp is a link on macOS
    top = join(temp.resolveSymbolicLinksSync(), 'top');
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });

  group('worktree', () {
    test('a .git file is a git top level', () async {
      var main = await _createRepo(join(top, 'main'));
      // Inside the main checkout (.claude/worktrees style) and outside
      var inside = join(main, 'worktrees', 'inside');
      var outside = join(top, 'outside');
      await _git(main, ['worktree', 'add', '-b', 'inside', inside]);
      await _git(main, ['worktree', 'add', '-b', 'outside', outside]);
      expect(File(join(inside, '.git')).existsSync(), isTrue);

      expect(isGitTopLevelPathSync(inside), isTrue);
      // Not the main checkout (screset would reset it)
      expect(await findGitTopLevelPath(inside), inside);
      expect(await findScTopLevelPath(join(inside, 'f')), inside);
      // Found by the recursive tools
      expect(await _handledPaths(top), [main, outside]);
    }, timeout: const Timeout(Duration(minutes: 1)));
  });

  test(
    'handleScPath link loop',
    () async {
      var repo = await _createRepo(join(top, 'repo'));
      var other = await _createRepo(join(temp.path, 'other'));
      await Directory(join(top, 'sub')).create();
      // A single link to a parent keeps a broken implementation bounded
      // (40 levels, ELOOP), two would mean 2^40 paths.
      Link(join(top, 'sub', 'up')).createSync(top);
      // Other links are still followed
      Link(join(top, 'sub', 'other')).createSync(other);
      expect(await _handledPaths(top), [repo, join(top, 'sub', 'other')]);
    },
    timeout: const Timeout(Duration(minutes: 1)),
    skip: Platform.isWindows ? 'links need admin rights' : false,
  );

  test('GitBranchResult gone only in the upstream', () {
    expect(
      GitBranchResult.fromLine(
        '  feature 1234567 [origin/feature] fix [x: gone] check',
      ).gone,
      isFalse,
    );
    expect(
      GitBranchResult.fromLine(
        '  feature 1234567 fix [x: gone] no upstream',
      ).gone,
      isFalse,
    );
    expect(
      GitBranchResult.fromLine(
        '  feature 1234567 [origin/feature: gone] msg',
      ).gone,
      isTrue,
    );
    // A branch checked out in another worktree shows the worktree path
    var line = '+ wt 1234567 (/path/to/my wt) [origin/wt: gone] msg';
    expect(GitBranchResult.fromLine(line).name, 'wt');
    expect(GitBranchResult.fromLine(line).gone, isTrue);
    expect(
      GitBranchResult.fromLine(
        '+ wt 1234567 (/path/wt) [origin/wt] x: gone]',
      ).gone,
      isFalse,
    );
  });

  test('scpull reports a failed pull', () async {
    // No upstream: git pull fails
    var repo = await _createRepo(join(top, 'repo'));
    var result = await runExecutableArguments(dartExecutable!, [
      'run',
      join('example', 'bin', 'scpull.dart'),
      top,
    ]);
    expect(result.exitCode, 1);
    expect(result.stdout.toString(), contains('[0] project(s) updated'));
    expect(result.stderr.toString(), contains(repo));
  }, timeout: const Timeout(Duration(minutes: 2)));
}

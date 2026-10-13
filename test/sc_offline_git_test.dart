@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_sc/git.dart';
import 'package:tekartik_sc/sc.dart';
import 'package:tekartik_sc/src/git.dart'
    show gitPathGetCurrentBranchOrNull, gitPathGetRemoteOriginUrlOrNull;
import 'package:tekartik_sc/src/scrunci_args.dart';
import 'package:test/test.dart';

import 'bin_test.dart';

/// Run git in [dir], with a test identity, failing on error.
Future<void> _git(String dir, List<String> args) async {
  var result = await Process.run('git', [
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

/// Create a git repository in [dir] with one commit on [branch].
Future<String> _createRepo(String dir, {String branch = 'main'}) async {
  await Directory(dir).create(recursive: true);
  await _git(dir, ['init', '-b', branch]);
  await File(join(dir, 'f')).writeAsString('1');
  await _git(dir, ['add', 'f']);
  await _git(dir, ['commit', '-m', 'init']);
  return dir;
}

/// Local repositories only, no network.
void main() {
  group('sc offline git', () {
    late Directory temp;
    // Under top: a (main, modified, no origin), b (feat, modified, local
    // origin), c (detached HEAD), d/file.txt and d/e (git)
    late String top;
    late String bare;
    late String a;
    late String b;
    late String c;
    late String e;

    setUpAll(() async {
      temp = await Directory.systemTemp.createTemp('tekartik_sc_test_');
      top = join(temp.path, 'top');
      bare = join(temp.path, 'origin.git');
      await Directory(bare).create();
      await _git(bare, ['init', '--bare']);

      a = await _createRepo(join(top, 'a'));
      await File(join(a, 'f')).writeAsString('modified');

      b = await _createRepo(join(top, 'b'), branch: 'feat');
      await _git(b, ['remote', 'add', 'origin', bare]);
      await _git(b, ['push', '-u', 'origin', 'feat']);
      await File(join(b, 'f')).writeAsString('modified');

      c = await _createRepo(join(top, 'c'));
      await _git(c, ['checkout', '--detach']);

      await Directory(join(top, 'd')).create();
      await File(join(top, 'd', 'file.txt')).writeAsString('not a dir');
      e = await _createRepo(join(top, 'd', 'e'));
    });
    tearDownAll(() async {
      await temp.delete(recursive: true);
    });

    test('handleScPath', () async {
      var dirs = <String>[];
      await handleScPath(top, (dir) => dirs.add(dir), recursive: true);
      expect(dirs..sort(), [a, b, c, e]);

      dirs.clear();
      await handleScPath(top, (dir) => dirs.add(dir));
      expect(dirs, isEmpty);

      dirs.clear();
      await handleScPath(join(a, 'sub'), (dir) => dirs.add(dir));
      expect(dirs, [a]);
    });

    test('handleScPath errors', () async {
      var dirs = <String>[];
      // Sync error
      await handleScPath(top, (dir) {
        if (dir == a) {
          throw StateError('sync');
        }
        dirs.add(dir);
      }, recursive: true);
      expect(dirs..sort(), [b, c, e]);

      // Async error after a delay
      dirs.clear();
      await handleScPath(top, (dir) async {
        if (dir == b) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          throw StateError('async');
        }
        dirs.add(dir);
      }, recursive: true);
      expect(dirs..sort(), [a, c, e]);

      // Top level errors are not caught
      await expectLater(
        handleScPath(a, (dir) => throw StateError('top')),
        throwsStateError,
      );
    });

    test('origin and branch', () async {
      expect(await gitPathGetRemoteOriginUrlOrNull(GitPath(a)), isNull);
      expect(await gitPathGetRemoteOriginUrlOrNull(GitPath(b)), bare);
      expect(await GitPath(b).getRemoteOriginUrl(), bare);
      await expectLater(GitPath(a).getRemoteOriginUrl(), throwsStateError);

      expect(await gitPathGetCurrentBranchOrNull(GitPath(a)), 'main');
      expect(await GitPath(b).getCurrentBranch(), 'feat');
      expect(await gitPathGetCurrentBranchOrNull(GitPath(c)), isNull);
      await expectLater(GitPath(c).getCurrentBranch(), throwsStateError);

      // Detached HEAD, nothing to reset
      await GitPath(c).resetToOrigin(dryRun: true);
    });

    test('scstatus', () async {
      var result = await runCmd(
        DartCmd([join(exampleBinPath, 'scstatus.dart'), top]),
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());
      var out = result.stdout.toString();
      expect(out, contains('--- git $a'));
      expect(out, contains('Origin: none'));
      expect(out, contains('--- git $b'));
      expect(out, contains('Origin: $bare'));

      // Ignore main, detached HEAD handled
      result = await runCmd(
        DartCmd([join(exampleBinPath, 'scstatus.dart'), '-i', top]),
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());
      out = result.stdout.toString();
      expect(out, isNot(contains('--- git $a')));
      expect(out, contains('--- git $b'));
    });

    test('scpull', () async {
      var pullTop = join(temp.path, 'pull');
      await Directory(pullTop).create();
      await _git(pullTop, ['clone', '-b', 'feat', bare, 'clone']);
      var sw = Stopwatch()..start();
      var result = await runCmd(
        DartCmd([join(exampleBinPath, 'scpull.dart'), pullTop]),
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout.toString(), contains('[1] project(s) updated'));
      // It used to wait 15s before exiting
      expect(sw.elapsed, lessThan(const Duration(seconds: 14)));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  test('GitBranchesResult', () {
    var result = GitBranchesResult.fromStdout('''
* main                 1111111 [origin/main: gone] current
+ worktree             2222222 in another worktree
  other                3333333 [origin/other] msg
* (HEAD detached at 8f84608) 8f84608 msg
''');
    expect(result.branches.map((branch) => branch.name), [
      'main',
      'worktree',
      'other',
    ]);
    expect(result.branches.map((branch) => branch.gone), [true, false, false]);
  });

  test('scrunciSplitArguments', () {
    var split = scrunciSplitArguments([
      'https://github.com/tekartik/sc.dart',
      '-j',
      '2',
      '--min-sdk',
      '>=3.0.0',
      '--max-sdk=<4.0.0',
      '-b',
      'dev',
      'sub',
      '--no-test',
    ]);
    expect(split.scrunciArgs, [
      'https://github.com/tekartik/sc.dart',
      '-b',
      'dev',
      'sub',
    ]);
    expect(split.runCiArgs, [
      '-j',
      '2',
      '--min-sdk',
      '>=3.0.0',
      '--max-sdk=<4.0.0',
      '--no-test',
    ]);
  });
}

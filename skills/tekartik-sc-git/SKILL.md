---
name: tekartik-sc-git
description: >-
  Use when driving git from a Dart script with tekartik_sc: GitPath,
  GitProject, cloneCmd/pullOrClone, pushCmd/pullCmd/statusCmd/addCmd/
  commitCmd/checkoutCmd, runGit, status and GitStatusResult, branches,
  GitBranchesResult/GitBranchResult, the GitPathExt getters getCurrentBranch,
  getBranches, getRemoteOriginUrl, isGithubRepo, githubIsPrivate,
  resetToOrigin, recursiveGitRun, findGitTopLevelPath, isGitTopLevelPath,
  isGitSupported, gitCmd, gitUrlGetHostname and gitUrlToHttpsUri, via
  package:tekartik_sc/git.dart.
---

# Git from Dart (tekartik_sc)

`package:tekartik_sc/git.dart` wraps the `git` executable in `process_run`
`ProcessCmd` objects: a `GitPath` is a local checkout, a `GitProject` is a
remote url plus the local path to clone it into. It is a VM-only helper for
build, release and repo-maintenance scripts.

## Guidelines

* Dependency (git only, not on pub.dev - the repo root is the package, no
  `path:`):
  ```yaml
  dependencies:
    tekartik_sc:
      git:
        url: https://github.com/tekartik/sc.dart
      version: '>=0.7.0'
  ```
  Add `process_run` too: every command object is a `ProcessCmd` you run with
  `runCmd` from `package:process_run/cmd_run.dart`.
* `import 'package:tekartik_sc/git.dart';` is the only import needed; never
  import `package:tekartik_sc/src/...` (`scUriToPathParts`, `StdBuf`,
  `isGitPathAndScSupported` are internal).
* Availability: `await isGitSupported` / `isGitSupportedSync` (cached),
  `checkGitSupported(verbose: true)` / `checkGitSupportedSync()` to probe
  again. `checkGitSupported` retries with `runInShell` when the direct call
  fails, and every command built afterwards reuses that working invocation.
  `await isGithubCliInstalled()` tells whether `gh` is on the `PATH`.
* `GitPath(path)` is a local repository. Command builders return a
  `ProcessCmd` with `workingDirectory` already set: `cmd(args)` (anything),
  `pullCmd()`, `pushCmd()`, `statusCmd(short: true)`, `branchesCmd()`,
  `addCmd(pathspec: '.')`, `commitCmd('msg', all: true)`,
  `checkoutCmd(commit: 'main')` or `checkoutCmd(path: 'lib/x.dart')`. Run
  them with `await runCmd(cmd)` (add `verbose: true` to stream output);
  `runCmd` reports failures through `result.exitCode`, it does not throw.
* `await gitPath.runGit('branch --show-current', verbose: true)` runs an
  arbitrary git command line in the repo (the string is split into
  arguments) and returns the `ProcessResult`. `dryRun: true` prints
  `[dry-run] git <command> (in <path>)` and returns an empty successful
  result - thread it through your own `--dry-run` flag.
* Higher level helpers (extension `GitPathExt`, same import):
  `getCurrentBranch()`, `getBranches(remote: true)`, `getRemoteOriginUrl()`,
  `isGithubRepo()` and `githubIsPrivate()` (which shells out to `gh repo
  view`, so check `isGithubCliInstalled()` first).
* `await gitPath.status()` returns a `GitStatusResult` with `nothingToCommit`
  and `branchIsAhead` parsed from the English output (commands force
  `LC_ALL=C` through `gitEnvironment`), plus the raw `cmd` and `runResult`.
* `await gitPath.branches()` parses `git branch -vv` into a
  `GitBranchesResult` whose `branches` are `GitBranchResult(name:, gone:)` -
  `gone` marks a local branch whose upstream disappeared, the usual input of
  a cleanup script.
* `await gitPath.resetToOrigin(branch: 'main', dryRun: true)` force-switches
  the local branch to `origin/<branch>`; it detects the current branch when
  `branch` is omitted. It discards local commits, so gate it behind an
  explicit flag.
* `GitProject(src, path: dir)` extends `GitPath` with the remote url in
  `src`: `cloneCmd(depth: 1, branch: 'main', progress: true)` builds the
  clone command, `pullOrClone()` clones when `<path>/.git/config` is missing
  and pulls otherwise. Without `path:`, the local path is derived from the
  url (`github.com/tekartik/sc.dart`), which is what the `scclone` command
  does.
* Discovery: `isGitTopLevelPath(dir)` / `isGitTopLevelPathSync(dir)` test for
  a `.git` directory, `findGitTopLevelPath(dir)` walks up the parents,
  `isGitRepository(url)` probes a remote with `git ls-remote`.
* `recursiveGitRun(['.'], action: (path) async {...})` walks the directories,
  stops descending at each repository root and calls `action` on it, with at
  most `recursiveGitRunPoolSize` (default 10) running concurrently. Set the
  pool size before the first call.
* Url helpers: `gitUrlGetHostname('git@github.com:me/repo.git')` returns
  `github.com`, `gitUrlToHttpsUri` turns an ssh url into an https `Uri`.
  Do not use `Uri.parse` on `git@...` urls, it does not parse them.
* Mercurial, the source-control-agnostic layer and the `sc*` command line
  tools are in [../tekartik-sc-tools/SKILL.md](../tekartik-sc-tools/SKILL.md).

## Examples

### Branches and remote of the current checkout

```dart
import 'package:tekartik_sc/git.dart';

Future<void> main() async {
  var gitPath = GitPath('.');
  print('branch: ${await gitPath.getCurrentBranch()}');
  print('local: ${await gitPath.getBranches()}');
  print('remote: ${await gitPath.getBranches(remote: true)}');
  var url = await gitPath.getRemoteOriginUrl();
  print('origin: $url (${gitUrlGetHostname(url)}) ${gitUrlToHttpsUri(url)}');
}
```

### Status of every repository under a tree

```dart
import 'package:tekartik_sc/git.dart';

Future<void> main(List<String> args) async {
  if (!await isGitSupported) {
    throw StateError('git not found');
  }
  await recursiveGitRun(
    args.isEmpty ? ['.'] : args,
    action: (path) async {
      var status = await GitPath(path).status();
      if (!status.nothingToCommit || status.branchIsAhead) {
        print('$path: $status');
      }
    },
  );
}
```

### Add, commit and push

```dart
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_sc/git.dart';

Future<void> commitAll(String path, String message) async {
  var gitPath = GitPath(path);
  var status = await gitPath.status();
  if (status.nothingToCommit) {
    print('nothing to commit in $path');
    return;
  }
  await runCmd(gitPath.addCmd(pathspec: '.'), verbose: true);
  await runCmd(gitPath.commitCmd(message, all: true), verbose: true);
  var result = await runCmd(gitPath.pushCmd(), verbose: true);
  if (result.exitCode != 0) {
    throw StateError('push failed in $path');
  }
}
```

### Clone (or update) a repository

```dart
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_sc/git.dart';

Future<void> main() async {
  var project = GitProject(
    'https://github.com/tekartik/sc.dart',
    path: '.local/checkout/sc.dart',
  );
  if (await isGitRepository(project.src)) {
    await runCmd(project.cloneCmd(depth: 1, branch: 'main'), verbose: true);
  }
  // Later: pull if already cloned, clone otherwise.
  await project.pullOrClone();
}
```

### List branches whose upstream is gone

```dart
import 'package:tekartik_sc/git.dart';

Future<void> main() async {
  var gitPath = GitPath('.');
  var result = await gitPath.branches();
  for (var branch in result.branches) {
    if (branch.gone) {
      print('gone: ${branch.name}');
      // Destructive, opt in explicitly:
      // await gitPath.runGit('branch -D ${branch.name}', dryRun: true);
    }
  }
}
```

## Common mistakes

* Forgetting that `runCmd` never throws: always look at `exitCode`.
* Parsing localized git output: keep `gitEnvironment` (`LC_ALL=C`) by using
  `gitCmd` / `GitPath` command builders instead of raw `ProcessCmd('git',
  ...)`.
* Calling `githubIsPrivate()` without checking `isGithubCliInstalled()`.
* Using `resetToOrigin()` without a dry run first: it force-recreates the
  branch from `origin/<branch>` and drops local commits.
* Importing `package:tekartik_sc/src/scpath.dart` for `scUriToPathParts`:
  it is not part of the public API.

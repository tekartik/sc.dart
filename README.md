# tekartik_sc

Source control helpers for Dart scripts: drive `git` (and, legacy, `hg`) from
Dart with `GitPath`, walk a tree of checkouts with `handleScPath` /
`recursiveGitRun`, and the `sc*` command line tools built on them (`scstatus`,
`scpull`, `scpp`, `scinfo`, `scclone`, ...) to check or update every
repository under a folder at once.

Dart VM only (`dart:io`, Linux, macOS, Windows): the `git` executable must be
in the `PATH` (`hg` for mercurial, `gh` for the GitHub information of
`scinfo`).

## Getting started

The package is not on pub.dev, add it as a git dependency (`process_run` too
to run the command objects):

```yaml
dependencies:
  tekartik_sc:
    git:
      url: https://github.com/tekartik/sc.dart
  process_run: any
```

Report the checkouts with local changes or unpushed commits under the current
folder:

```dart
import 'package:tekartik_sc/git.dart';

Future<void> main() async {
  if (!await isGitSupported) {
    throw StateError('git not found');
  }
  // Calls action on each git top level found (it does not go below one).
  await recursiveGitRun(
    ['.'],
    action: (path) async {
      var gitPath = GitPath(path);
      var status = await gitPath.status();
      if (!status.nothingToCommit || status.branchIsAhead) {
        print('$path: $status');
      }
    },
  );
}
```

Commands are `ProcessCmd` objects (`gitPath.pullCmd()`, `pushCmd()`,
`commitCmd(...)`...) run with `runCmd` from
`package:process_run/cmd_run.dart`; `runCmd` does not throw when git fails,
check `result.exitCode`. [example/example.dart](example/example.dart) prints
the branches of the current checkout.

## Which API

| Need | Use | Import |
|---|---|---|
| one git checkout: status, branches, origin, commands | `GitPath(path)`, `GitPathExt` | `git.dart` |
| clone an url | `GitProject(url, path: ...)`, `cloneCmd`, `pullOrClone` | `git.dart` |
| every git checkout under a folder | `recursiveGitRun` | `git.dart` |
| git or hg checkouts under a folder | `handleScPath`, `getScName`, `findScTopLevelPath` | `sc.dart` |
| mercurial (legacy) | `HgPath`, `HgProject` | `hg.dart` |
| a command line tool from Dart | `main` of `bin/<tool>.dart` | `bin/<tool>.dart` |

## Command line tools

Each tool is a `main` in `package:tekartik_sc/bin/<tool>.dart`. The package
declares no `executables:`: from a clone of this repository run
`dart run example/bin/scstatus.dart`, or add a one line wrapper per tool in the
`bin/` of your own package (`export 'package:tekartik_sc/bin/scpull.dart';`,
as [example/bin](example/bin) does), list it under `executables:` and
`dart pub global activate -s path .`.

The tools walk the given folders (default: the current one) and handle every
repository found:

| Tool | What it does |
|---|---|
| `scstatus` | repositories with changes or unpushed commits (`-m` modified files only, `-i` skips main/master, `-l finer` lists all) |
| `scpull` | `git pull` everywhere; a failed pull is reported on stderr and the exit code is 1 |
| `scpp` | push when ahead, then pull |
| `scinfo` | url, GitHub visibility/archived/size (`gh` CLI, `-o` to skip), branch, status, last commit, counts and sizes |
| `sccleanup` | `git fetch --prune`, then delete (`git branch -D`) the local branches whose upstream is gone |
| `screvert <folder>` | revert the local changes (`git checkout <path>`) |
| `screset <folder>` | reset the current branch to `origin/<branch>` (drops unpushed commits; refuses when there are local changes) |
| `scclone <url>` | clone into `git/<host>/<owner>/<repo>` (`<host>/<owner>/<repo>` when run from a folder named `git`) |
| `scrunci <url> [<sub_paths>]` | clone in a temp folder and run `dev_build`'s `run_ci` there (other options go to `run_ci`) |
| `sccheckgit`, `sccheckhg` | check the git / hg installation |

Common options: `-h`, `--version`, `-v` (verbose), `-n` (dry run: print the
commands; `-d` for `scclone`), `-r` (recursive) for `screvert` and `screset`,
`-t <ms>` (timeout per repository) for `scpp` and `sccleanup`.

## Common pitfalls

* `runCmd` never throws: look at `exitCode` (the tools do).
* A repository holding a `.local/.skip_sc` file is skipped by `scstatus`,
  `scpull`, `scpp`, `sccleanup` and `scinfo`.
* Folders starting with `.` are not walked. Links to directories are
  followed, except a link to a folder being walked (a link loop).
* A linked worktree or a submodule (`.git` file) is a repository of its own:
  the tools act on it, not on the checkout that holds it.
* `screset` and `GitPathExt.resetToOrigin` force the branch to
  `origin/<branch>`: unpushed commits are dropped.
* `getCurrentBranch()` throws a `StateError` on a detached HEAD,
  `getRemoteOriginUrl()` when there is no origin.

Agent skills: [skills/tekartik-sc-git](skills/tekartik-sc-git/SKILL.md) (git
API) and [skills/tekartik-sc-tools](skills/tekartik-sc-tools/SKILL.md) (tree
walker, mercurial, command line tools).

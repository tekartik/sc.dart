/// scrunci help flag.
const String scrunciHelpFlag = 'help';

/// scrunci version flag.
const String scrunciVersionFlag = 'version';

/// scrunci verbose flag (also forwarded to run_ci).
const String scrunciVerboseFlag = 'verbose';

/// scrunci keep flag.
const String scrunciKeepFlag = 'keep';

/// scrunci branch option.
const String scrunciBranchOption = 'branch';

/// scrunci depth option.
const String scrunciDepthOption = 'depth';

/// Options handled by scrunci itself, everything else is forwarded to run_ci.
const _scrunciFlags = <String>{
  '-h',
  '--$scrunciHelpFlag',
  '--$scrunciVersionFlag',
  '--$scrunciKeepFlag',
};
const _scrunciOptions = <String>{
  '-b',
  '--$scrunciBranchOption',
  '--$scrunciDepthOption',
};

/// run_ci options taking a value (dev_build run_ci.dart), the value given
/// as the next argument is forwarded too.
const _runCiOptions = <String>{'-j', '--concurrency', '--min-sdk', '--max-sdk'};

/// Split the arguments between scrunci arguments and run_ci arguments.
///
/// run_ci arguments are the unknown options and the rest arguments
/// but the first one (the url).
({List<String> scrunciArgs, List<String> runCiArgs}) scrunciSplitArguments(
  List<String> arguments,
) {
  final scrunciArgs = <String>[];
  final runCiArgs = <String>[];
  var i = 0;
  while (i < arguments.length) {
    final arg = arguments[i++];
    if (_scrunciFlags.contains(arg)) {
      scrunciArgs.add(arg);
    } else if (_scrunciOptions.contains(arg)) {
      scrunciArgs.add(arg);
      if (i < arguments.length) {
        scrunciArgs.add(arguments[i++]);
      }
    } else if (_scrunciOptions.any((option) => arg.startsWith('$option='))) {
      scrunciArgs.add(arg);
    } else if (_runCiOptions.contains(arg)) {
      runCiArgs.add(arg);
      if (i < arguments.length) {
        runCiArgs.add(arguments[i++]);
      }
    } else if (arg == '-v' || arg == '--$scrunciVerboseFlag') {
      // Verbose applies to both
      scrunciArgs.add(arg);
      runCiArgs.add(arg);
    } else if (arg.startsWith('-')) {
      runCiArgs.add(arg);
    } else {
      // Positional argument (url first, then sub paths)
      scrunciArgs.add(arg);
    }
  }
  return (scrunciArgs: scrunciArgs, runCiArgs: runCiArgs);
}

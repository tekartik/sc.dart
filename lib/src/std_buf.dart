import 'dart:io';
import 'package:process_run/cmd_run.dart';

/// Utility class for buffering stdout and stderr.
class StdBuf {
  /// Buffer for stdout.
  StringBuffer out = StringBuffer();

  /// Buffer for stderr.
  StringBuffer err = StringBuffer();

  /// Appends an object to the stdout buffer.
  void outAppend(Object object) {
    if (out.length > 0) {
      out.writeln();
    }
    out.write(object);
  }

  /// Appends an object to the stderr buffer.
  void errAppend(Object object) {
    if (err.length > 0) {
      err.writeln();
    }
    err.write(object);
  }

  /// Appends a process result to the buffers.
  void appendResult(ProcessResult result) {
    if (result.stdout.toString().isNotEmpty) {
      outAppend('${result.stdout}');
    }
    if (result.stderr.toString().isNotEmpty) {
      errAppend('${result.stderr}');
    }
  }

  /// Appends a command and its result to the buffers for debugging.
  void appendCmdResult(ProcessCmd cmd, ProcessResult result) {
    outAppend('> $cmd');
    outAppend('=> ${result.exitCode}');
    if (result.stdout.toString().isNotEmpty) {
      outAppend('out: ${result.stdout}');
    }
    if (result.stderr.toString().isNotEmpty) {
      errAppend('err: ${result.stderr}');
    }
  }

  /// Prints the buffered output to stdout and stderr.
  void print([String? header]) {
    if (header != null &&
        (out.toString().isNotEmpty || err.toString().isNotEmpty)) {
      stdout.writeln(header);
    }
    if (out.toString().isNotEmpty) {
      stdout.writeln(out);
    }
    if (err.toString().isNotEmpty) {
      stderr.writeln(err);
    }
  }
}

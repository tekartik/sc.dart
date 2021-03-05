import 'dart:io';
import 'package:process_run/cmd_run.dart';

class StdBuf {
  StringBuffer out = StringBuffer();
  StringBuffer err = StringBuffer();

  void outAppend(Object object) {
    if (out.length > 0) {
      out.writeln();
    }
    out.write(object);
  }

  void errAppend(Object object) {
    if (err.length > 0) {
      err.writeln();
    }
    err.write(object);
  }

  void appendResult(ProcessResult result) {
    if (result.stdout.toString().isNotEmpty) {
      outAppend('${result.stdout}');
    }
    if (result.stderr.toString().isNotEmpty) {
      errAppend('${result.stderr}');
    }
  }

  // debug
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

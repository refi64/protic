import 'package:source_span/source_span.dart';

import 'compiler.dart' as compiler;
import 'platform.dart';

export 'platform.dart';

abstract class FileProvider {
  String read(String path);
  String readStdin() => '';
  bool write(String path, String data) => true;
}

class CompileError {
  SourceSpan at;
  String message;
  CompileError(this.at, this.message);
  String toString() => at.message(message);
}

class CompileResult {
  String code, sourceMap;
  List<CompileError> errors;
  CompileResult({this.code, this.sourceMap, this.errors});
}

CompileResult compile(String text, {Map<String, String> vars, url,
                      FileProvider fileProvider}) =>
  compiler.compile(text, vars: vars, url: url,
                   fileProvider: fileProvider ?? platformFileProvider());

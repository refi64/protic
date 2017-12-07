import 'package:source_span/source_span.dart';

abstract class FileProvider {
  String read(String path);
}

class CompileError {
  SourceSpan at;
  String message;
  CompileError(this.at, this.message);
  String toString() => at.message(message);
}

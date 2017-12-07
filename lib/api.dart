import 'package:source_span/source_span.dart';

export 'src/platform.dart'
  if (dart.library.io) 'src/platform_vm.dart'
  if (node) 'src/platform_node.dart';

abstract class FileProvider {
  String read(String path);
}

class CompileError {
  SourceSpan at;
  String message;
  CompileError(this.at, this.message);
  String toString() => at.message(message);
}

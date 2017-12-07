import 'src/compiler.dart' as compiler;
import 'api.dart';

export 'api.dart';

String compileString(String text, {Map<String, String> vars,
                                   List<CompileError> errors, url,
                                   FileProvider fileProvider}) =>
  compiler.compileString(text, vars: vars, errors: errors, url: url,
                         fileProvider: fileProvider);

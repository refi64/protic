@JS()
library ph.src.js.entrypoint;

import 'package:js/js.dart';
import 'package:js/js_util.dart';
import 'package:source_span/source_span.dart';

import '../../api.dart';
import '../driver.dart';

@JS()
class Exports {
  external set compile(Function);
}

@JS()
external Exports get exports;

@JS('Object.keys')
external List<String> objectKeys(dynamic obj);

@JS('require.main.exports')
external dynamic get requireMainExports;

@JS('process.argv')
external List<String> get processArgv;

@JS()
@anonymous
class JsSourceLocation {
  external int get line;
  external int get column;
  external int get offset;
  external String get url;
  external factory JsSourceLocation({int line, int column, int offset, String url});
}

JsSourceLocation sourceLocationToJs(SourceLocation loc) =>
  new JsSourceLocation(line: loc.line, column: loc.column, offset: loc.offset,
                       url: loc.sourceUrl?.toString());

@JS()
@anonymous
class JsSourceSpan {
  external JsSourceLocation get start;
  external JsSourceLocation get end;
  external String get text;
  external String get url;
  external factory JsSourceSpan({JsSourceLocation start, JsSourceLocation end,
                                 String text, String url});
}

@JS()
@anonymous
class JsCompileError {
  external JsSourceSpan get at;
  external String get message;
  external String get formattedMessage;
  external factory JsCompileError({JsSourceSpan at, String message,
                                   String formattedMessage});
}

@JS()
@anonymous
class JsCompileResult {
  external String get code;
  external String get sourceMap;
  external List<JsCompileError> get errors;
  external factory JsCompileResult({String code, String sourceMap,
                                    List<JsCompileError> errors});
}

@JS()
@anonymous
class JsCompileArgs {
  external dynamic get vars;
  external String get url;
  external Function get fileProvider;
}

class JsFileProviderWrapper extends FileProvider {
  Function reader;
  JsFileProviderWrapper(this.reader);
  String read(String path) => reader(path);
}

JsCompileResult jsCompile(String text, [JsCompileArgs args]) {
  var vars = <String, String>{};
  var url, fileProvider;

  if (args?.vars != null) {
    for (var key in objectKeys(args.vars)) {
      vars[key] = getProperty(args.vars, key);
    }
  }

  url = args?.url;

  if (args?.fileProvider != null) {
    fileProvider = new JsFileProviderWrapper(args.fileProvider);
  }

  var result = compile(text, vars: vars, url: url, fileProvider: fileProvider);
  var jsErrors = <JsCompileError>[];

  for (var error in result.errors) {
    jsErrors.add(new JsCompileError(
      at: new JsSourceSpan(
        start: sourceLocationToJs(error.at.start),
        end: sourceLocationToJs(error.at.end),
        text: error.at.text,
        url: error.at.sourceUrl?.toString(),
      ),
      message: error.message,
      formattedMessage: error.toString(),
    ));
  }

  return new JsCompileResult(
    code: result.code,
    sourceMap: result.sourceMap,
    errors: jsErrors,
  );
}

void main() {
  exports.compile = allowInterop(jsCompile);

  bool isMain = false;
  try {
    isMain = requireMainExports == exports;
  } catch (ex) {}

  if (isMain) {
    run(processArgv.sublist(2));
  }
}

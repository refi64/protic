@JS()
library ph.src.js.entrypoint;

import 'package:js/js.dart';
import 'package:js/js_util.dart';
import 'package:source_span/source_span.dart';

import '../../api.dart';
import '../../ph.dart';

@JS()
class Exports {
  external set compile(Function);
}

@JS()
external Exports get exports;

@JS('Object.keys')
external List<String> objectKeys(dynamic obj);

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
  external factory JsCompileError({JsSourceSpan at, String message});
}

@JS()
@anonymous
class JsCompileArgs {
  external dynamic get vars;
  external List<JsCompileError> get errors;
  external String get url;
  external Function get fileProvider;
}

class JsFileProviderWrapper implements FileProvider {
  Function reader;
  JsFileProviderWrapper(this.reader);
  String read(String path) => reader(path);
}

String jsCompileString(String text, [JsCompileArgs args]) {
  var vars = <String, String>{};
  var url, fileProvider;

  var errors = <CompileError>[];

  if (args?.vars != null) {
    for (var key in objectKeys(args.vars)) {
      vars[key] = getProperty(args.vars, key);
    }
  }

  url = args?.url;

  if (args?.fileProvider != null) {
    fileProvider = new JsFileProviderWrapper(args.fileProvider);
  }

  var result = compileString(text, vars: vars, errors: errors, url: url,
                             fileProvider: fileProvider);

  if (args?.errors != null) {
    var jsErrors = args.errors;

    for (var error in errors) {
      jsErrors.add(new JsCompileError(
        at: new JsSourceSpan(
          start: sourceLocationToJs(error.at.start),
          end: sourceLocationToJs(error.at.end),
          text: error.at.text,
          url: error.at.sourceUrl?.toString(),
        ),
        message: error.message,
      ));
    }
  }

  return result;
}

void main() {
  exports.compile = allowInterop(jsCompileString);
}

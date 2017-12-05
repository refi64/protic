import 'package:collection/collection.dart';
import 'package:ph/ph.dart';
import 'package:test/test.dart';

Description _describeValues(Description description, {String output,
                            List<String> errors}) {
  var sep = '';
  if (output != null) {
    description.add('output: $output');
    sep = ', ';
  }
  if (errors != null && errors.isNotEmpty) {
    description.add('${sep}errors: ${errors.join(', ')}');
  }
  return description;
}

class _CompileTest extends Matcher {
  String output;
  List<String> errors;
  FileProvider fileProvider;
  _CompileTest({this.output, this.errors, this.fileProvider});

  bool matches(item, Map matchState) {
    var actualErrors = <CompileError>[];
    var result = compileString(item, errors: actualErrors, fileProvider: fileProvider);
    var actualErrorMessages = actualErrors.map((e) => e.message).toList();

    matchState['output'] = result;
    matchState['errors'] = actualErrorMessages;

    if (output != null && result != output) {
      return false;
    }
    if (errors != null && !const ListEquality().equals(actualErrorMessages, errors)) {
      return false;
    }
    return true;
  }

  Description describe(Description description) =>
    _describeValues(description, output: output, errors: errors);

  Description describeMismatch(item, Description mismatchDescription, Map matchState,
                               bool verbose) =>
    _describeValues(mismatchDescription, output: matchState['output'],
                    errors: matchState['errors']);
}

class MockFileProvider implements FileProvider {
  Map<String, String> files;
  MockFileProvider(this.files);
  String read(String file) => files[file];
}

_CompileTest compilesTo(String output, {FileProvider fileProvider}) =>
  new _CompileTest(output: output, fileProvider: fileProvider);
_CompileTest compilesWithErrors(List<String> errors, {FileProvider fileProvider}) =>
  new _CompileTest(errors: errors, fileProvider: fileProvider);
_CompileTest compilesToWithErrors({String output, List<String> errors,
                                   FileProvider fileProvider}) =>
  new _CompileTest(output: output, errors: errors, fileProvider: fileProvider);

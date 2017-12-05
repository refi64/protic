import 'package:collection/collection.dart';
import 'package:petitparser/petitparser.dart';
import 'package:ph/ph.dart';
import 'package:ph/src/expression.dart';
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

Description _describeEvalResult(Description description, {String result,
                                String failure}) {
  if (failure != null) {
    return description..add('failure: $failure');
  } else if (result != null) {
    return description..add('result: ($result)');
  } else {
    return description..add('result: null');
  }
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

class _ParseTest extends Matcher {
  Expression expected;
  _ParseTest(this.expected);

  bool matches(item, Map matchState) {
    var result = new ExprParser().parse(item);
    matchState['result'] = result;
    if (result is Success && expected != null) {
      return result.value == expected;
    } else if (result is Failure && expected == null) {
      return true;
    } else {
      return false;
    }
  }

  Description describe(Description description) =>
    description..add(expected?.toString() ?? 'failure');
  Description describeMismatch(item, Description mismatchDescription, Map matchState,
                               bool verbose) =>
    mismatchDescription..add(matchState['result'] is Success ?
                             matchState['result'].value.toString() :
                             'failure');
}

_ParseTest parsesTo(Expression expected) => new _ParseTest(expected);
final parseFails = new _ParseTest(null);

class _EvalTest extends Matcher {
  String expected, failure;
  Map<String, String> vars, macroVars;
  _EvalTest({this.expected, this.failure, this.vars, this.macroVars});

  bool matches(item, Map matchState) {
    var ctx = new EvalContext(vars: this.vars ?? {}, macroVars: this.macroVars);
    String result;

    try {
      result = new ExprParser().parse(item).value.eval(ctx);
    } on EvalError catch (ex) {
      matchState['failure'] = ex.message;
      return failure == ex.message;
    }
    matchState['result'] = result;
    return result == expected;
  }

  Description describe(Description description) =>
    _describeEvalResult(description, result: expected, failure: failure);
  Description describeMismatch(item, Description mismatchDescription, Map matchState,
                               bool verbose) =>
    _describeEvalResult(mismatchDescription, result: matchState['result'],
                        failure: matchState['failure']);
}

_EvalTest evalsTo(String expected, {vars, macroVars}) =>
  new _EvalTest(expected: expected, vars: vars, macroVars: macroVars);
_EvalTest evalFails(String error, {vars, macroVars}) =>
  new _EvalTest(failure: error, vars: vars, macroVars: macroVars);

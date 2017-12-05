import 'package:html/dom_parsing.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

import 'src/custom_tokenizer.dart';
import 'src/expression.dart';

import 'dart:io';

class Maybe<T> {}
class Just<T> extends Maybe<T> {
  T value;
  Just(this.value);
}
class Nothing<T> extends Maybe<T> {}

class CompileError {
  SourceSpan at;
  String message;
  CompileError(this.at, this.message);
  String toString() => at.message(message);
}

class MovedSpan {
  SourceSpan original, target;
  MovedSpan({this.original, this.target});
}

abstract class FileProvider {
  String read(String path);
}

class FileSystemProvider implements FileProvider {
  String read(String path) {
    try {
      return new File(path).readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }
}

class PhWalker extends TreeVisitor {
  TextEditTransaction rewriter;
  List<CompileError> errors;
  Map<String, String> vars;
  FileProvider fileProvider;
  PhWalker(this.rewriter, {this.errors, this.vars, this.fileProvider}) {
    this.vars ??= {};
    this.fileProvider ??= new FileSystemProvider();
  }

  List<MovedSpan> moves = [];

  void error(SourceSpan at, String message) {
    errors.add(new CompileError(at, message));
  }

  void edit1(SourceSpan span, String contents) {
    rewriter.edit(span.start.offset, span.end.offset, contents);
  }

  void delete(SourceSpan span) {
    edit1(span, '');
  }

  void deleteNode(Node n, {bool contents: false}) {
    if (n is Element && n.endSourceSpan != null) {
      if (contents) {
        delete(n.sourceSpan.expand(n.endSourceSpan));
      } else {
        delete(n.sourceSpan);
        delete(n.endSourceSpan);
      }
    } else {
      delete(n.sourceSpan);
    }
  }

  void convertAttributes(Element el) {
    var classes = <String>[];
    var classSpan;

    if (el.attributes.containsKey('class')) {
      classes = el.attributes['class'].split(' ');
      classSpan = el.attributeSpans['class'];
    }

    for (var attr in el.attributes.keys) {
      if (!attr.startsWith('+')) {
        continue;
      }
      var span = el.attributeSpans[attr];

      if (attr.length < 3 || !'#.'.contains(attr[1])) {
        error(span, 'invalid attribute');
        continue;
      }

      if (el.attributes[attr].isNotEmpty) {
        error(span, '${attr} should not have a value');
      }

      var value = attr.substring(2);

      if (attr[1] == '#') {
        edit1(span, 'id="$value"');
      } else if (attr[1] == '.') {
        classes.add(value);
        if (classSpan == null) {
          classSpan = span;
        } else {
          delete(span);
        }
      }
    }

    if (classes.isNotEmpty) {
      assert(classSpan != null);
      edit1(classSpan, 'class="${classes.join(' ')}"');
    }
  }

  Maybe<String> runExpression(SourceSpan at, String expr) {
    var ctx = new EvalContext(vars: vars);

    var result = parseExpression(expr);
    if (result == null) {
      error(at, 'syntax error in expression');
      return new Nothing();
    }

    try {
      return new Just<String>(result.eval(ctx));
    } on EvalError catch (ex) {
      error(at, 'error evaluating expression: $ex');
      return new Nothing();
    }
  }

  void visitElement(Element el) {
    convertAttributes(el);

    if (el.localName != '+') {
      visitChildren(el);
      return;
    }

    initAttributeSpans(el);
    bool invalidated = false, deleted = false;

    for (var attr in el.attributes.keys) {
      var value = el.attributes[attr];
      var attrSpan = el.attributeSpans[attr];
      var valueSpan = el.attributeValueSpans[attr];

      if (invalidated) {
        error(el.sourceSpan, 'multiple transforms cannot be applied to one + tag');
        break;
      }

      if (attr.startsWith('set:')) {
        var v = attr.substring(4);
        vars[v] = value;
        invalidated = true;
        continue;
      }

      switch (attr) {
      case 'value':
        var result = runExpression(valueSpan, value);
        if (result is Just<String>) {
          edit1(el.sourceSpan, result.value);
        }
        invalidated = deleted = true;
        break;
      case 'include':
        var result = runExpression(valueSpan, value);
        if (result is Nothing) {
          continue;
        }

        var path = (result as Just<String>).value;
        if (path == null) {
          error(valueSpan, 'expression resulted in a null value');
        }

        var contents = fileProvider.read(path);
        if (contents == null) {
          error(valueSpan, '$path does not exist');
          continue;
        }

        var includedFile = new SourceFile.fromString(contents, url: value);

        contents = compileString(contents, errors: errors, url: value,
                                 fileProvider: fileProvider);

        edit1(el.sourceSpan, contents);
        moves.add(new MovedSpan(original: includedFile.span(0, includedFile.length),
                                target: el.sourceSpan));
        invalidated = deleted = true;
        break;
      case 'if':
        var result = runExpression(valueSpan, value);
        if (result is Just<String> && isTruthy(result.value)) {
          break;
        } else {
          deleteNode(el, contents: true);
          return;
        }
        break;
      case 'do':
        visitChildren(el);
        break;
      default:
        error(attrSpan, 'unknown attribute $attr');
      }
    }

    if (!deleted) {
      deleteNode(el);
    }
  }
}

String compileString(String text, {Map<String, String> vars,
                                   List<CompileError> errors, url,
                                   FileProvider fileProvider}) {
  var source = new SourceFile.fromString(text, url: url);
  var rewriter = new TextEditTransaction(text, source);

  var tokenizer = new CustomHtmlTokenizer(text, generateSpans: true,
                                          sourceUrl: url);
  var tree = new CustomTreeBuilder(true);

  var parser = new html.HtmlParser(tokenizer, tree: tree);
  var dom = parser.parse();

  var walker = new PhWalker(rewriter, errors: errors ?? [], vars: vars,
                            fileProvider: fileProvider);
  walker.visit(dom);
  var printer = rewriter.commit();
  printer.build(null);
  return printer.text;
}
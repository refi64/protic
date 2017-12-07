import 'package:html/dom_parsing.dart';
import 'package:html/dom.dart';
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

import 'src/html_parsing.dart' as html;
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
    this.scopes.add(vars);
    this.scopes.add(<String, String>{});
  }

  var moves = <MovedSpan>[];
  var scopes = <Map<String, String>>[];
  bool lastIfStatus = null;

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
    var currentScope = <String, String>{};
    for (var scope in scopes) {
      currentScope.addAll(scope);
    }

    var ctx = new EvalContext(vars: currentScope);

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

  Map<String, String> getAttributesAfter(Map attributes, String key) {
    var keys = attributes.keys.toList();
    var values = attributes.values.toList();
    var index = keys.indexOf(key);

    return new Map.fromIterables(keys.sublist(index + 1), values.sublist(index + 1));
  }

  void visitElement(Element el) {
    convertAttributes(el);

    if (el.localName != '+') {
      visitChildren(el);
      return;
    }

    html.initAttributeSpans(el);
    bool invalidated = false, deleted = false;

    outer:for (var attr in el.attributes.keys) {
      var value = el.attributes[attr];
      var attrSpan = el.attributeSpans[attr];
      var valueSpan = el.attributeValueSpans[attr];

      if (invalidated) {
        error(el.sourceSpan, 'multiple transforms cannot be applied to one + tag');
        break;
      }

      switch (attr) {
      case 'set':
        scopes.last..addAll(getAttributesAfter(el.attributes, 'set'));
        break outer;
      case 'value':
        var result = runExpression(valueSpan, value);
        if (result is Just<String>) {
          edit1(el.sourceSpan, result.value);
        }
        invalidated = deleted = true;
        break;
      case 'print':
        var result = runExpression(valueSpan, value);
        if (result is Just<String>) {
          print(result.value);
        }
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

        var extraVars = getAttributesAfter(el.attributes, 'include');

        contents = compileString(contents, vars: new Map.from(vars)..addAll(extraVars),
                                 errors: errors, url: value, fileProvider: fileProvider);

        edit1(el.sourceSpan, contents);
        moves.add(new MovedSpan(original: includedFile.span(0, includedFile.length),
                                target: el.sourceSpan));

        deleted = true;
        break outer;
      case 'if':
        var orelseIndexes = <int>[];

        for (var childIndex = 0; childIndex < el.nodes.length; childIndex++) {
          var child = el.nodes[childIndex];
          if (child is Element && child.localName == '+' &&
              child.attributes.containsKey('orelse')) {
            orelseIndexes.add(childIndex);
          }
        }

        var elseNodes = <Node>[];

        if (orelseIndexes.isNotEmpty) {
          var childrenCopy = new List.from(el.nodes);
          // Shorten the children to just until the first orelse.
          el.nodes.removeRange(orelseIndexes[0], el.nodes.length);

          for (var i = 0; i < orelseIndexes.length; i++) {
            var isLast = i + 1 == orelseIndexes.length;

            var orelseIndex = orelseIndexes[i];
            var lastChildIndex = isLast ? childrenCopy.length : orelseIndexes[i + 1];
            var lastChild = childrenCopy[lastChildIndex - 1];

            childrenCopy[orelseIndex].nodes.addAll(childrenCopy.sublist(
              orelseIndex + 1, lastChildIndex));

            var elseEndSpan =
              (lastChild is Element ? lastChild.endSourceSpan : null) ??
              lastChild.sourceSpan;
            childrenCopy[orelseIndex].endSourceSpan = elseEndSpan.file.span(
              elseEndSpan.end.offset, elseEndSpan.end.offset);

            elseNodes.add(childrenCopy[orelseIndex]);
          }
        }

        var result = runExpression(valueSpan, value);
        if (result is Just<String>) {
          lastIfStatus = isTruthy(result.value);
          if (lastIfStatus) {
            for (var node in elseNodes) {
              deleteNode(node, contents: true);
            }
            break;
          }
        }

        for (var node in elseNodes) {
          visit(node);
        }

        for (var child in el.nodes) {
          deleteNode(child, contents: true);
        }
        deleteNode(el);
        return;
      case 'orelse':
      case 'else':
        if (lastIfStatus == false) {
          break;
        }
        lastIfStatus = null;
        deleteNode(el, contents: true);
        return;
      case 'do':
        visitChildren(el);
        break;
      default:
        error(attrSpan, 'unknown attribute $attr');
      }
    }

    lastIfStatus = null;

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

  var dom = html.parse(text, url: url);
  var walker = new PhWalker(rewriter, errors: errors ?? [], vars: vars,
                            fileProvider: fileProvider);
  walker.visit(dom);
  var printer = rewriter.commit();
  printer.build(null);
  return printer.text;
}

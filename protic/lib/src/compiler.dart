import 'dart:collection';

import 'package:html/dom_parsing.dart';
import 'package:html/dom.dart';
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

import 'api.dart' hide compile;
import 'expression.dart';
import 'html_parsing.dart' as html;

class Maybe<T> {}
class Just<T> extends Maybe<T> {
  T value;
  Just(this.value);
}
class Nothing<T> extends Maybe<T> {}

class MovedSpan {
  SourceSpan original, target;
  MovedSpan({this.original, this.target});
}

class Macro {
  String contents;
  List<Map<String, String>> scopes;
  bool slot;
  Macro({this.contents, this.scopes, this.slot});
}

class PhWalker extends TreeVisitor {
  TextEditTransaction rewriter;
  Map<String, String> vars, macroVars;
  Map<String, Macro> macros;
  FileProvider fileProvider;
  String slot;
  PhWalker(this.rewriter, {this.vars, this.macroVars, this.macros, this.fileProvider,
           this.slot}) {
    this.vars ??= <String, String>{};
    this.macroVars ??= <String, String>{};
    this.macros ??= <String, Macro>{};
    this.scopes.add(vars);
    this.scopes.add(<String, String>{});
  }

  var errors = <CompileError>[];
  var moves = <MovedSpan>[];
  var scopes = <Map<String, String>>[];
  bool lastIfStatus = null;

  SourceSpan getInnerHtmlSpan(Element el) =>
    el.sourceSpan.file.span(el.sourceSpan.end.offset, el.endSourceSpan.start.offset);

  SourceSpan getFullElementSpan(Element el) =>
    el.endSourceSpan != null ? el.sourceSpan.expand(el.endSourceSpan) : el.sourceSpan;

  void error(SourceSpan at, String message) {
    errors.add(new CompileError(at, message));
  }

  void edit(SourceSpan span, String contents) {
    rewriter.edit(span.start.offset, span.end.offset, contents);
  }

  void delete(SourceSpan span) {
    edit(span, '');
  }

  void deleteNode(Node n, {bool contents: false}) {
    if (n is Element && n.endSourceSpan != null) {
      if (contents) {
        delete(getFullElementSpan(n));
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

      if (attr.length < 2) {
        error(span, 'invalid attribute');
        continue;
      }

      if ('#.'.contains(attr[1])) {
        if (attr.length < 3) {
          error(span, 'invalid attribute');
          continue;
        }

        if (el.attributes[attr].isNotEmpty) {
          error(span, '$attr should not have a value');
        }

        var value = attr.substring(2);

        if (attr[1] == '#') {
          edit(span, 'id="$value"');
        } else if (attr[1] == '.') {
          classes.add(value);
          if (classSpan == null) {
            classSpan = span;
          } else {
            delete(span);
          }
        }
      } else {
        if (el.attributes[attr].isEmpty) {
          error(span, '$attr should have a value');
          continue;
        }

        var actualAttr = attr.substring(1);
        var valueSpan = el.attributeValueSpans[attr];
        var result = runExpression(valueSpan, el.attributes[attr]);

        if (result is Just<String>) {
          edit(span, '$actualAttr="${result.value}"');
        }
      }
    }

    if (classes.isNotEmpty) {
      assert(classSpan != null);
      edit(classSpan, 'class="${classes.join(' ')}"');
    }
  }

  Maybe<String> runExpression(SourceSpan at, String expr) {
    var currentScope = <String, String>{};
    for (var scope in scopes) {
      currentScope.addAll(scope);
    }

    var ctx = new EvalContext(vars: currentScope, macroVars: macroVars);

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

    return new LinkedHashMap.fromIterables(
      keys.sublist(index + 1).map((x) => x as String),
      values.sublist(index + 1).map((x) => x as String));
  }

  void compilePlus(Element el) {
    html.initAttributeSpans(el);
    bool invalidated = false, deleted = false;

    outer:for (var attr in el.attributes.keys) {
      var value = el.attributes[attr];
      var attrSpan = el.attributeSpans[attr];
      var valueSpan = el.attributeValueSpans[attr];

      if (invalidated && !(el.attributes.containsKey('macro') && attr == 'slot')) {
        error(el.sourceSpan, 'multiple transforms cannot be applied to one + tag');
        break;
      }

      switch (attr) {
      case 'set':
        var assignments = getAttributesAfter(el.attributes, 'set');
        for (var name in assignments.keys) {
          if (assignments[name].isEmpty) {
            scopes.last[name] = '';
          } else {
            var result = runExpression(el.attributeValueSpans[name], assignments[name]);
            if (result is Just<String>) {
              scopes.last[name] = result.value;
            }
          }
        }
        break outer;
      case 'value':
        var result = runExpression(valueSpan, value);
        if (result is Just<String>) {
          edit(el.sourceSpan, result.value);
        }
        invalidated = deleted = true;
        break;
      case 'print':
        var result = runExpression(valueSpan, value);
        if (result is Just<String>) {
          print(attrSpan.message('print: ${result.value}'));
        }
        break;
      case 'include':
      case 'require':
        var maybePath = runExpression(valueSpan, value);
        if (maybePath is Nothing) {
          continue;
        }

        var path = (maybePath as Just<String>).value;
        if (path == null) {
          error(valueSpan, 'expression resulted in a null value');
          continue;
        }

        if (fileProvider == null) {
          error(valueSpan, 'protic does not have a file provider; includes are disabled');
          continue;
        }

        var contents = fileProvider.read(path);
        if (contents == null) {
          error(valueSpan, '$path does not exist');
          continue;
        }

        var includedFile = new SourceFile.fromString(contents, url: value);

        var extraVars = getAttributesAfter(el.attributes, attr);

        var requiredMacros = <String, Macro>{};
        var result = compile(contents, vars: new Map.from(vars)..addAll(extraVars),
                             macros: requiredMacros, url: value,
                             fileProvider: fileProvider);

        if (attr == 'require') {
          macros.addAll(requiredMacros);
        }

        edit(el.sourceSpan, result.code);
        moves.add(new MovedSpan(original: includedFile.span(0, includedFile.length),
                                target: el.sourceSpan));
        errors..addAll(result.errors);

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
      case 'for':
        if (el.endSourceSpan == null) {
          error(attrSpan, 'for statement must have a body');
          return;
        }

        var attrs = getAttributesAfter(el.attributes, 'for');
        if (attrs.length != 2) {
          error(attrSpan, 'invalid for statement');
          return;
        }

        if (attrs.values.first.isNotEmpty) {
          error(el.attributeValueSpans[attrs.keys.first],
                'for statement variable attribute must not have a value');
        }

        var target = attrs.keys.elementAt(0);
        var exprKind = attrs.keys.elementAt(1);
        var expr = attrs.values.elementAt(1);
        var exprKindSpan = el.attributeSpans[exprKind];
        var exprSpan = el.attributeValueSpans[exprKind];

        if (expr.isEmpty) {
          error(exprKindSpan, 'for statement expression must not be empty');
          return;
        }

        if (exprKind != 'in' && exprKind != 'upto') {
          error(exprKindSpan, 'for statement expression kind must be in or upto');
          return;
        }

        var exprResult = runExpression(exprSpan, expr);
        if (exprResult is Nothing) {
          return;
        }
        var exprString = (exprResult as Just<String>).value;
        Iterable<String> values;

        if (exprKind == 'upto') {
          var exprNum = int.parse(exprString, onError: (_) => null);
          if (exprNum == null) {
            error(exprSpan, 'expression is not a valid integer');
            return;
          }

          values = new Iterable<String>.generate(exprNum, (i) => i.toString());
        } else if (exprKind == 'in') {
          values = exprString.split(' ');
        }

        var contentSpan = getInnerHtmlSpan(el);
        var contents = contentSpan.text;

        var htmlBuffer = new StringBuffer();

        for (var value in values) {
          var loopVars = new Map.from(vars);
          loopVars[target] = value;
          var result = compile(contents, vars: loopVars, macroVars: macroVars,
                               url: rewriter.file.url, fileProvider: fileProvider);

          for (var error in result.errors) {
            var properSpan = rewriter.file.span(
                contentSpan.start.offset + error.at.start.offset,
                contentSpan.start.offset + error.at.end.offset);
            errors.add(new CompileError(properSpan, error.message));
          }

          htmlBuffer.writeln(result.code);
        }

        edit(getFullElementSpan(el), htmlBuffer.toString());
        return;
      case 'do':
        visitChildren(el);
        break;
      case 'macro':
        if (value.isEmpty) {
          error(attrSpan, 'macro name cannot be empty');
          continue;
        }

        macros[value] = new Macro(contents: getInnerHtmlSpan(el).text, scopes: scopes,
                                  slot: el.attributes.containsKey('slot'));

        deleteNode(el, contents: true);
        invalidated = deleted = true;
        break;
      case 'slot':
        if (el.attributes.containsKey('macro')) {
          continue;
        }

        if (slot == null) {
          error(el.sourceSpan, 'slot cannot be used outside a macro');
          continue;
        }

        var result = compile(slot, vars: vars, macros: macros,
                             url: rewriter.file.url, fileProvider: fileProvider);
        errors.addAll(result.errors);

        edit(el.sourceSpan, result.code);
        invalidated = deleted = true;
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

  void compileMacroExpansion(Element el) {
    html.initAttributeSpans(el);

    if (el.attributes.length == 0) {
      error(el.sourceSpan, 'macro expansion requires a macro name to expand');
      return;
    }

    var name = el.attributes.keys.first;
    var nameSpan = el.attributeSpans[name];
    if (el.attributes.values.first.isNotEmpty) {
      error(nameSpan, 'macro name should not have a value');
      return;
    }

    var macro = macros[name];
    if (macro == null) {
      error(nameSpan, 'undefined macro $name');
      return;
    }

    if (macro.slot && el.endSourceSpan == null) {
      error(el.sourceSpan, 'macro requires a slot, but none was given');
      return;
    }

    var originalScopes = scopes;
    scopes = macro.scopes;

    var macroVars = getAttributesAfter(el.attributes, name);

    var result = compile(macro.contents, vars: vars, macros: macros,
                         macroVars: macroVars, url: rewriter.file.url,
                         fileProvider: fileProvider,
                         slot: macro.slot ? getInnerHtmlSpan(el).text : '');

    for (var error in result.errors) {
      errors.add(new CompileError(el.sourceSpan, error.message));
    }

    edit(getFullElementSpan(el), result.code);

    scopes = originalScopes;
  }

  void visitElement(Element el) {
    convertAttributes(el);

    if (el.localName == '+') {
      compilePlus(el);
    } else if (el.localName == '+@') {
      compileMacroExpansion(el);
    } else {
      visitChildren(el);
    }
  }
}

CompileResult compile(String text, {Map<String, String> vars,
                      Map<String, String> macroVars, Map<String, Macro> macros,
                      url, FileProvider fileProvider, String slot}) {
  var source = new SourceFile.fromString(text, url: url);
  var rewriter = new TextEditTransaction(text, source);

  var dom = html.parse(text, url: url, fileProvider: fileProvider);
  var walker = new PhWalker(rewriter, vars: vars, macroVars: macroVars, macros: macros,
                            fileProvider: fileProvider, slot: slot);
  walker.visit(dom);
  var printer = rewriter.commit();
  printer.build(null);
  return new CompileResult(
    code: printer.text,
    sourceMap: printer.map,
    errors: walker.errors,
  );
}

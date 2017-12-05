import 'package:html/dom_parsing.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

import 'src/custom_tokenizer.dart';

import 'dart:io';

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
  FileProvider fileProvider;
  PhWalker(this.rewriter, this.errors, {this.fileProvider}) {
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

  void visitElement(Element el) {
    convertAttributes(el);

    if (el.localName != '+') {
      visitChildren(el);
      return;
    }

    initAttributeSpans(el);
    bool invalidated = false;

    for (var attr in el.attributes.keys) {
      var value = el.attributes[attr];

      if (invalidated) {
        error(el.sourceSpan, 'multiple transforms cannot be applied to one + tag');
        break;
      }

      switch (attr) {
      case 'include':
        var contents = fileProvider.read(value);
        if (contents == null) {
          error(el.attributeSpans['include'], '$value does not exist');
          continue;
        }

        var includedFile = new SourceFile.fromString(contents, url: value);

        contents = compileString(contents, errors: errors, url: value,
                                 fileProvider: fileProvider);

        edit1(el.sourceSpan, contents);
        moves.add(new MovedSpan(original: includedFile.span(0, includedFile.length),
                                target: el.sourceSpan));
        invalidated = true;
        break;
      }
    }
  }
}

String compileString(String text, {List<CompileError> errors, url,
                                   FileProvider fileProvider}) {
  var source = new SourceFile.fromString(text, url: url);
  var rewriter = new TextEditTransaction(text, source);

  var tokenizer = new CustomHtmlTokenizer(text, generateSpans: true,
                                          sourceUrl: url);
  var dom = html.parse(tokenizer);

  var walker = new PhWalker(rewriter, errors ?? [], fileProvider: fileProvider);
  walker.visit(dom);
  var printer = rewriter.commit();
  printer.build(null);
  return printer.text;
}

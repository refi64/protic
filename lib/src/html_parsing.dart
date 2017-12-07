import 'package:html/src/tokenizer.dart';
import 'package:html/src/token.dart';
import 'package:html/src/treebuilder.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:source_span/source_span.dart' show SourceFile;

class CustomHtmlTokenizer extends HtmlTokenizer {
  CustomHtmlTokenizer(String text, {bool generateSpans, bool attributeSpans: false,
                                    String sourceUrl}):
    super(text, generateSpans: generateSpans, attributeSpans: attributeSpans,
                sourceUrl: sourceUrl);

  bool tagOpenState() {
    var data = stream.char();
    if (data == '+') {
      state = tagNameState;
      currentToken = new StartTagToken(data);
      return true;
    } else {
      stream.unget(data);
      return super.tagOpenState();
    }
  }

  bool closeTagOpenState() {
    var data = stream.char();
    if (data == '+') {
      state = tagNameState;
      currentToken = new EndTagToken(data);
      return true;
    } else {
      stream.unget(data);
      return super.tagOpenState();
    }
  }
}

class CustomTreeBuilder extends TreeBuilder {
  CustomTreeBuilder(bool namespaceHTMLElements): super(namespaceHTMLElements);

  Element insertElement(StartTagToken token) {
    var result = super.insertElement(token);
    if (token.name == '+' && token.data != null &&
        !(token.data.containsKey('do') && !token.data.containsKey('orelse'))) {
      openElements.removeLast();
    }
    return result;
  }
}

// Since + isn't normally a valid StartTagToken, _ensureAttributeSpans will crash. This
// is a workaround to ensure the node's attribute spans are initialized, working around
// _ensureAttributeSpans.
void initAttributeSpans(Node n) {
  var fakeFile = new SourceFile.fromString('<div> ');

  // Make sure _ensureAttributeSpans is called with an empty span.
  var sourceSpan = n.sourceSpan;
  n.sourceSpan = fakeFile.span(0);
  n.attributeSpans;

  // Based on Node._ensureAttributeSpans.
  var tokenizer = new CustomHtmlTokenizer(sourceSpan.text,
                                          generateSpans: true,
                                          attributeSpans: true);

  tokenizer.moveNext();
  var token = tokenizer.current as StartTagToken;

  if (token.attributeSpans == null) return; // no attributes

  for (var attr in token.attributeSpans) {
    var offset = sourceSpan.start.offset;
    n.attributeSpans[attr.name] =
        sourceSpan.file.span(offset + attr.start, offset + attr.end);
    if (attr.startValue != null) {
      n.attributeValueSpans[attr.name] = sourceSpan.file
          .span(offset + attr.startValue, offset + attr.endValue);
    }
  }

  // Restore the correct source span.
  n.sourceSpan = sourceSpan;
}

Document parse(String text, {url}) {
  var tokenizer = new CustomHtmlTokenizer(text, generateSpans: true,
                                          sourceUrl: url);
  var tree = new CustomTreeBuilder(true);

  var parser = new HtmlParser(tokenizer, tree: tree);
  return parser.parse();
}

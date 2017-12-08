import 'package:html/src/tokenizer.dart';
import 'package:html/src/token.dart';
import 'package:html/src/treebuilder.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:source_span/source_span.dart' show SourceFile;

bool _isSingleLinePlus(StartTagToken token, Set<String> slotMacros) =>
  (token.name == '+' && token.data != null &&
   !((token.data.containsKey('do') && !token.data.containsKey('orelse')) ||
     token.data.containsKey('macro') || token.data.containsKey('for'))) ||
  (token.name == '+@' && (token.data?.isNotEmpty ?? false) &&
   !slotMacros.contains(token.data.keys.first));

class CustomHtmlTokenizer extends HtmlTokenizer {
  Set<String> slotMacros;
  CustomHtmlTokenizer(String text, {bool generateSpans, bool attributeSpans: false,
                      String sourceUrl, this.slotMacros}):
    super(text, generateSpans: generateSpans, attributeSpans: attributeSpans,
                sourceUrl: sourceUrl);

  void emitCurrentToken() {
    super.emitCurrentToken();

    var token = tokenQueue.last;
    if (token is StartTagToken && _isSingleLinePlus(token, slotMacros)) {
      token.selfClosing = true;
    } else if (token is StartTagToken && token.name == '+' && token.data != null &&
               token.data.containsKey('macro') && token.data.containsKey('slot')) {
      slotMacros.add(token.data['macro']);
    }
  }

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
      return super.closeTagOpenState();
    }
  }
}

class CustomTreeBuilder extends TreeBuilder {
  Set<String> slotMacros;
  CustomTreeBuilder(bool namespaceHTMLElements, {this.slotMacros}):
                    super(namespaceHTMLElements);

  Element insertElement(StartTagToken token) {
    var result = super.insertElement(token);
    if (_isSingleLinePlus(token, slotMacros)) {
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
                                          attributeSpans: true,
                                          slotMacros: new Set<String>());

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
  var slotMacros = new Set<String>();
  var tokenizer = new CustomHtmlTokenizer(text, generateSpans: true, sourceUrl: url,
                                          slotMacros: slotMacros);
  var tree = new CustomTreeBuilder(true, slotMacros: slotMacros);

  var parser = new HtmlParser(tokenizer, tree: tree);
  return parser.parse();
}

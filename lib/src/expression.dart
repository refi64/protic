import 'package:petitparser/petitparser.dart';

class Expression {}

enum RelationOp { and, or }

class Relation extends Expression {
  Expression left, right;
  RelationOp op;
  Relation({this.left, this.right, this.op});
  String toString() => 'Relation(left: $left, right: $right, op: $op)';
  bool operator==(other) => other is Relation && left == other.left &&
                            right == other.right && op == other.op;
}

enum ComparisonOp { eq, ne }

class Comparison extends Expression {
  Expression left, right;
  ComparisonOp op;
  Comparison({this.left, this.right, this.op});
  String toString() => 'Comparison(left: $left, right: $right, op: $op)';
  bool operator==(other) => other is Comparison && left == other.left &&
                            right == other.right && op == other.op;
}

class Var extends Expression {
  String name;
  bool isMacroVar;
  Var(this.name, {this.isMacroVar: false});
  String toString() => 'Var($name, isMacroVar: $isMacroVar)';
  bool operator==(other) => other is Var && name == other.name &&
                            isMacroVar == other.isMacroVar;
}

class Text extends Expression {
  String value;
  Text(this.value);
  String toString() => 'Text($value)';
  bool operator==(other) => other is Text && value == other.value;
}

class ExprGrammar extends GrammarParser {
  ExprGrammar(): super(const ExprGrammarDefinition());
}

class ExprGrammarDefinition extends GrammarDefinition {
  const ExprGrammarDefinition();

  start() => ref(expr).end();
  token(Parser p) => p.flatten().trim();

  expr() => ref(relExpr);

  relExpr() => ref(cmpExpr) & (ref(relOp) & ref(cmpExpr)).optional();
  relOp() => ref(token, string('and') | string('or'));

  cmpExpr() => ref(simpleExpr) & (ref(cmpOp) & ref(simpleExpr)).optional();
  cmpOp() => ref(token, string('==') | string('!='));

  simpleExpr() => ref(parenExpr) | variable() | value();

  variable() => (var_() | macroVar()).trim();
  var_() => char(r'$') & ref(id);
  macroVar() => string(r'$@') & ref(id);
  id() => letter() & (word() | char('_')).star();

  value() => ref(qstring) | ref(bareword);

  qstring() => (mkqstring("'") | mkqstring('"')).trim();
  mkqstring(delim) => string(delim) & mkchar(delim).star() & string(delim);
  mkchar(delim) => ((char('\\') & any()).pick(1) | string(delim).neg());

  bareword() => ref(token, noneOf('\$"\'') & whitespace().neg().star());

  parenExpr() => (char('(') & ref(expr) & char(')')).pick(1);
}

class ExprParser extends GrammarParser {
  ExprParser(): super(const ExprParserDefinition());
}

class ExprParserDefinition extends ExprGrammarDefinition {
  const ExprParserDefinition();

  static const relOpMap = const {
    'and': RelationOp.and,
    'or': RelationOp.or,
  };

  static const cmpOpMap = const {
    '==': ComparisonOp.eq,
    '!=': ComparisonOp.ne,
  };

  relExpr() => super.relExpr().map((p) => p[1] == null ? p[0] :
                                            new Relation(left: p[0], right: p[1][1],
                                                         op: p[1][0]));
  relOp() => super.relOp().map((p) => relOpMap[p]);

  cmpExpr() => super.cmpExpr().map((p) => p[1] == null ? p[0] :
                                            new Comparison(left: p[0], right: p[1][1],
                                                           op: p[1][0]));
  cmpOp() => super.cmpOp().map((p) => cmpOpMap[p]);

  var_() => super.var_().pick(1).map((p) => new Var(p));
  macroVar() => super.macroVar().pick(1).map((p) => new Var(p, isMacroVar: true));
  id() => super.id().flatten();

  qstring() => super.qstring().map((p) => new Text(p[1].join("")));
  bareword() => super.bareword().map((p) => new Text(p));
}

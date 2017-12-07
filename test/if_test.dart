import 'package:test/test.dart';
import 'utils.dart';

void main() {
  test('if works', () {
    expect(r'<+ if="$var" do>abc</+>', compilesTo('abc', vars: {'var': '1'}));
    expect(r'<+ if="$?var" do>abc</+>', compilesTo(''));
    expect(r'<+ if="$var" value="abc">', compilesTo('abc', vars: {'var': '1'}));
    expect(r'<+ if="$?var" value="abc">', compilesTo(''));
  });

  test('else works', () {
    expect(r'<+ if="$var" do>abc</+><+ else do>def</+>', compilesTo('abc', vars: {'var': '1'}));
    expect(r'<+ if="$?var" do>abc</+><+ else do>def</+>', compilesTo('def'));
    expect(r'<+ if="$var" value="abc"><+ else value="def">', compilesTo('abc', vars: {'var': '1'}));
    expect(r'<+ if="$?var" value="abc"><+ else value="def">', compilesTo('def'));
  });

  test('orelse works', () {
    expect(r'<+ if="$var" do>abc<+ orelse if="$var" do>def<+ orelse do>ghi</+>',
      compilesTo('abc', vars: {'var': '1'}));
    expect(r'<+ if="$?empty" do>abc<+ orelse if="$var" do>def<+ orelse do>ghi</+>',
      compilesTo('def', vars: {'var': '1'}));
    expect(r'<+ if="$?empty" do>abc<+ orelse if="$?empty" do>def<+ orelse do>ghi</+>',
      compilesTo('ghi', vars: {'var': '1'}));
  });
}

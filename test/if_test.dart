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
}

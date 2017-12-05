import 'package:test/test.dart';
import 'utils.dart';

void main() {
  test('if tests work', () {
    expect(r'<+ if="$var" do>abc</+>', compilesTo('abc', vars: {'var': '1'}));
    expect(r'<+ if="$?var" do>abc</+>', compilesTo(''));
  });
}

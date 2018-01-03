import 'package:test/test.dart';
import 'utils.dart';

void main() {
  test('set and value work', () {
    expect(r'<+ set a="v-a" b="v-b" c><+ value="$a $b $c">', compilesTo('v-a v-b '));
    expect(r'<+ set a="123" b="$a 456"><+ value="$b">', compilesTo('123 456'));
  });
}

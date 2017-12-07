import 'package:test/test.dart';
import 'utils.dart';

void main() {
  test('set: and value work', () {
    expect(r'<+ set a="v-a" b="v-b"><+ value="$a $b">', compilesTo('v-a v-b'));
  });
}

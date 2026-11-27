import 'package:flutter_test/flutter_test.dart';
import 'package:gia_su_tu_duy/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GiaSuTuDuyApp());
    expect(find.text('Gia Sư Tư Duy'), findsWidgets);
  });
}

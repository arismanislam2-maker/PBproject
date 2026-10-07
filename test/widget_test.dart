import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/main.dart';

void main() {
  testWidgets('MyFinance App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:trans_prism/main.dart';

void main() {
  testWidgets('app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const TransToolboxApp());
    await tester.pump();

    expect(find.byType(TransToolboxApp), findsOneWidget);
  });
}

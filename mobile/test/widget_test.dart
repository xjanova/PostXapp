import 'package:flutter_test/flutter_test.dart';
import 'package:postxapp/main.dart';

void main() {
  testWidgets('PostX App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PostXApp());
    expect(find.text('Dashboard'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:nbe_payment_flutter_plugin_example/main.dart';

void main() {
  testWidgets('always shows the test environment warning', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.textContaining('MTF TEST ENVIRONMENT'), findsOneWidget);
  });
}

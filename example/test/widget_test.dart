import 'package:flutter_test/flutter_test.dart';
import 'package:nbe_payment_flutter_plugin/nbe_payment_flutter_plugin.dart';
import 'package:nbe_payment_flutter_plugin_example/main.dart';

void main() {
  testWidgets('shows the bundled versions', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(
      find.textContaining('Plugin ${NbePaymentVersions.plugin}'),
      findsOneWidget,
    );
  });
}

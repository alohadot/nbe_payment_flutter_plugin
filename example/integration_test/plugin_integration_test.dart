// Runs inside the example app on a device or emulator.
//
// Real native tests (initialization against the MTF test environment, card update,
// 3DS authentication) are added once the native implementations exist. This file does not
// fake any of them.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nbe_payment_flutter_plugin/nbe_payment_flutter_plugin.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the gateway starts uninitialized', (tester) async {
    expect(NbePaymentGateway().isInitialized, isFalse);
  });
}

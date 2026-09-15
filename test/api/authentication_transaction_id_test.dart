import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nbe_payment_flutter_plugin/src/api/authentication_transaction_id.dart';

void main() {
  final uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('produces RFC 4122 version 4 UUIDs', () {
    for (var seed = 0; seed < 50; seed++) {
      expect(
        generateAuthenticationTransactionId(random: Random(seed)),
        matches(uuidV4),
      );
    }
  });

  test('produces a different id on every call', () {
    final ids = List.generate(
      1000,
      (_) => generateAuthenticationTransactionId(),
    );

    expect(ids.toSet(), hasLength(1000));
  });
}

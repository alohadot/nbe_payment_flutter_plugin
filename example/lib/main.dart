import 'package:flutter/material.dart';

import 'payment_test_page.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NBE Payment Plugin',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF006A4E)),
      home: const PaymentTestPage(),
    );
  }
}

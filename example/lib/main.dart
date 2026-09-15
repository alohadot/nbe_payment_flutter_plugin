import 'package:flutter/material.dart';
import 'package:nbe_payment_flutter_plugin/nbe_payment_flutter_plugin.dart';

// Placeholder until the full demo app is built. It only uses the public plugin API.
void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final gateway = NbePaymentGateway();
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('NBE Payment Plugin')),
        body: Center(
          child: Text(
            'Plugin ${NbePaymentVersions.plugin}\n'
            'Android SDK ${NbePaymentVersions.androidGatewaySdk}\n'
            'iOS SDK ${NbePaymentVersions.iosGatewaySdk}\n'
            'Initialized: ${gateway.isInitialized}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

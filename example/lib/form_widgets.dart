import 'package:flutter/material.dart';
import 'package:nbe_payment_flutter_plugin/nbe_payment_flutter_plugin.dart';

class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    this.description,
    required this.children,
  });

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(description!, style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

/// Always visible at the top of the screen, so nobody runs payments without knowing whether
/// real money can move.
class EnvironmentBanner extends StatelessWidget {
  const EnvironmentBanner({
    super.key,
    required this.region,
    required this.isInitialized,
  });

  final GatewayRegion region;
  final bool isInitialized;

  @override
  Widget build(BuildContext context) {
    final isTest = region == GatewayRegion.mtf;
    final headline = isTest
        ? 'MTF TEST ENVIRONMENT — no real money moves'
        : 'PRODUCTION REGION (${region.name.toUpperCase()}) — REAL MONEY';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTest ? Colors.amber.shade100 : Colors.red.shade100,
        border: Border.all(
          color: isTest ? Colors.amber.shade700 : Colors.red.shade700,
          width: isTest ? 1 : 3,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$headline\nGateway initialized: ${isInitialized ? 'yes' : 'no'}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }
}

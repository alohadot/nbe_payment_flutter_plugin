import 'package:flutter/material.dart';

enum OperationStatus { idle, processing, success, failed, cancelled }

/// What the last operation produced, as shown on screen.
class OperationOutcome {
  const OperationOutcome(this.status, this.message);

  const OperationOutcome.success(String message)
    : this(OperationStatus.success, message);

  const OperationOutcome.cancelled(String message)
    : this(OperationStatus.cancelled, message);

  static const idle = OperationOutcome(
    OperationStatus.idle,
    'No operation yet.',
  );

  final OperationStatus status;
  final String message;
}

class OperationOutcomeView extends StatelessWidget {
  const OperationOutcomeView({super.key, required this.outcome});

  final OperationOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (outcome.status) {
      OperationStatus.idle => ('IDLE', Colors.grey),
      OperationStatus.processing => ('PROCESSING', Colors.blue),
      OperationStatus.success => ('SUCCESS', Colors.green),
      OperationStatus.failed => ('FAILED', theme.colorScheme.error),
      OperationStatus.cancelled => ('CANCELLED', Colors.orange),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Chip(
            label: Text(label),
            labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
            side: BorderSide(color: color),
          ),
        ),
        if (outcome.status == OperationStatus.processing)
          const LinearProgressIndicator(),
        const SizedBox(height: 4),
        SelectableText(outcome.message, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

import 'package:flutter/material.dart';

/// One line in the on-screen event log. Never holds card data.
class EventLogEntry {
  EventLogEntry(this.message, {this.isError = false}) : time = DateTime.now();

  final DateTime time;
  final String message;
  final bool isError;
}

class EventLogView extends StatelessWidget {
  const EventLogView({super.key, required this.entries, required this.onClear});

  final List<EventLogEntry> entries;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Events', style: theme.textTheme.titleMedium),
            const Spacer(),
            TextButton(onPressed: onClear, child: const Text('Clear events')),
          ],
        ),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No events yet.'),
          ),
        for (final entry in entries.reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${_formatTime(entry.time)}  ${entry.message}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: entry.isError ? theme.colorScheme.error : null,
              ),
            ),
          ),
      ],
    );
  }

  static String _formatTime(DateTime time) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final millis = time.millisecond.toString().padLeft(3, '0');
    return '${twoDigits(time.hour)}:${twoDigits(time.minute)}:${twoDigits(time.second)}.$millis';
  }
}

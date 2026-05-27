import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/timer_provider.dart';

class ProductivityTimerScreen extends ConsumerWidget {
  const ProductivityTimerScreen({super.key});

  Future<void> _addTimer(BuildContext context, WidgetRef ref, {int? presetMinutes}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _AddTimerSheet(presetMinutes: presetMinutes),
    );
    if (result == null) return;
    ref.read(timerProvider.notifier).addTimer(
          result['title'] as String,
          result['minutes'] as int,
        );
  }

  void _showRunningConflict(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stop the running timer before starting another one.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timers = ref.watch(timerProvider).timers;
    final hasRunning = ref.watch(timerProvider).runningTimer != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Focus timer'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Stay productive', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Add multiple timers, but only one can run at a time.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          Text('Quick add', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [15, 25, 45, 60].map((m) {
              return OutlinedButton(
                onPressed: () => _addTimer(context, ref, presetMinutes: m),
                child: Text('$m min'),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your timers', style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(
                onPressed: () => _addTimer(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add timer'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (timers.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text('No timers yet. Tap Add timer to get started.', style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ...timers.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TimerCard(
                    entry: t,
                    onToggle: () {
                      final ok = ref.read(timerProvider.notifier).toggleTimer(t.id);
                      if (!ok) _showRunningConflict(context);
                    },
                    onReset: () => ref.read(timerProvider.notifier).resetTimer(t.id),
                    onRemove: () => ref.read(timerProvider.notifier).removeTimer(t.id),
                  ),
                )),
          if (hasRunning) ...[
            const SizedBox(height: 8),
            Text(
              'A running timer stays active while you browse other tabs.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({
    required this.entry,
    required this.onToggle,
    required this.onReset,
    required this.onRemove,
  });

  final FocusTimer entry;
  final VoidCallback onToggle;
  final VoidCallback onReset;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final progress = entry.totalSeconds == 0 ? 0.0 : entry.remainingSeconds / entry.totalSeconds;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: entry.running ? AppColors.black : AppColors.border, width: entry.running ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: AppColors.textTertiary),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatTimerSeconds(entry.remainingSeconds),
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -1),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: AppColors.surface, color: AppColors.black),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onToggle,
                  icon: Icon(entry.running ? Icons.pause : Icons.play_arrow, size: 20),
                  label: Text(entry.running ? 'Pause' : 'Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: entry.running ? AppColors.black : AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onReset,
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddTimerSheet extends StatefulWidget {
  const _AddTimerSheet({this.presetMinutes});

  final int? presetMinutes;

  @override
  State<_AddTimerSheet> createState() => _AddTimerSheetState();
}

class _AddTimerSheetState extends State<_AddTimerSheet> {
  final _title = TextEditingController(text: 'Study session');
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _minutes = widget.presetMinutes ?? 25;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('New timer', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          TextField(
            controller: _title,
            decoration: const InputDecoration(hintText: 'Timer name'),
          ),
          const SizedBox(height: 16),
          Text('Duration: $_minutes min', style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: _minutes.toDouble(),
            min: 5,
            max: 120,
            divisions: 23,
            activeColor: AppColors.black,
            onChanged: (v) => setState(() => _minutes = v.round()),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                final title = _title.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(context, {'title': title, 'minutes': _minutes});
              },
              child: const Text('Add timer'),
            ),
          ),
        ],
      ),
    );
  }
}

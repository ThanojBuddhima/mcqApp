import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class FocusTimer {
  FocusTimer({
    required this.id,
    required this.title,
    required this.totalSeconds,
    required this.remainingSeconds,
    this.running = false,
  });

  final String id;
  final String title;
  final int totalSeconds;
  int remainingSeconds;
  bool running;

  FocusTimer copyWith({int? remainingSeconds, bool? running}) {
    return FocusTimer(
      id: id,
      title: title,
      totalSeconds: totalSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      running: running ?? this.running,
    );
  }
}

class TimerState {
  const TimerState({this.timers = const [], this.completionMessage});

  final List<FocusTimer> timers;
  final String? completionMessage;

  FocusTimer? get runningTimer {
    for (final t in timers) {
      if (t.running) return t;
    }
    return null;
  }

  TimerState copyWith({List<FocusTimer>? timers, String? completionMessage, bool clearCompletion = false}) {
    return TimerState(
      timers: timers ?? this.timers,
      completionMessage: clearCompletion ? null : (completionMessage ?? this.completionMessage),
    );
  }
}

class TimerNotifier extends StateNotifier<TimerState> {
  TimerNotifier() : super(const TimerState()) {
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  Timer? _tick;
  int _idSeq = 0;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _onTick() {
    final running = state.runningTimer;
    if (running == null || running.remainingSeconds <= 0) return;

    final updated = running.remainingSeconds - 1;
    if (updated <= 0) {
      _updateTimer(running.id, remainingSeconds: 0, running: false);
      state = state.copyWith(completionMessage: '"${running.title}" timer finished');
    } else {
      _updateTimer(running.id, remainingSeconds: updated);
    }
  }

  void clearCompletionMessage() {
    if (state.completionMessage != null) {
      state = state.copyWith(clearCompletion: true);
    }
  }

  void addTimer(String title, int minutes) {
    final seconds = minutes * 60;
    final timer = FocusTimer(
      id: '${++_idSeq}',
      title: title,
      totalSeconds: seconds,
      remainingSeconds: seconds,
    );
    state = state.copyWith(timers: [timer, ...state.timers]);
  }

  void removeTimer(String id) {
    state = state.copyWith(timers: state.timers.where((t) => t.id != id).toList());
  }

  void resetTimer(String id) {
    _updateTimer(id, running: false, resetRemaining: true);
  }

  bool toggleTimer(String id) {
    final timer = state.timers.firstWhere((t) => t.id == id);
    if (timer.running) {
      _updateTimer(id, running: false);
      return true;
    }

    if (state.runningTimer != null) {
      return false;
    }

    var remaining = timer.remainingSeconds;
    if (remaining <= 0) {
      remaining = timer.totalSeconds;
    }
    _updateTimer(id, remainingSeconds: remaining, running: true);
    return true;
  }

  void _updateTimer(String id, {int? remainingSeconds, bool? running, bool resetRemaining = false}) {
    state = state.copyWith(
      timers: state.timers.map((t) {
        if (t.id != id) {
          if (running == true) {
            return t.copyWith(running: false);
          }
          return t;
        }
        return t.copyWith(
          remainingSeconds: resetRemaining ? t.totalSeconds : remainingSeconds,
          running: running,
        );
      }).toList(),
    );
  }
}

final timerProvider = StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  return TimerNotifier();
});

String formatTimerSeconds(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

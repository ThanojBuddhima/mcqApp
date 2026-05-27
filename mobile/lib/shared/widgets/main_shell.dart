import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../features/productivity/providers/timer_provider.dart';
import '../../routing/page_transitions.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<TimerState>(timerProvider, (prev, next) {
      final msg = next.completionMessage;
      if (msg != null && msg != prev?.completionMessage) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        ref.read(timerProvider.notifier).clearCompletionMessage();
      }
    });

    final running = ref.watch(timerProvider).runningTimer;

    final topInset = MediaQuery.paddingOf(context).top + 16;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          AnimatedTabBody(navigationShell: navigationShell),
          Positioned(
            top: topInset,
            right: 20,
            child: running != null
                ? _RunningTimerBadge(
                    timer: running,
                    onTap: () => context.push('/timer'),
                    onPause: () => ref.read(timerProvider.notifier).toggleTimer(running.id),
                  )
                : _TimerBellButton(onTap: () => context.push('/timer')),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Expanded(child: _NavItem(icon: Icons.home_outlined, label: 'Home', selected: navigationShell.currentIndex == 0, onTap: () => _onTap(0))),
                Expanded(child: _NavItem(icon: Icons.menu_book_outlined, label: 'Courses', selected: navigationShell.currentIndex == 1, onTap: () => _onTap(1))),
                _CenterUploadButton(onTap: () => context.push('/upload')),
                Expanded(child: _NavItem(icon: Icons.bar_chart_outlined, label: 'Progress', selected: navigationShell.currentIndex == 2, onTap: () => _onTap(2))),
                Expanded(child: _NavItem(icon: Icons.person_outline, label: 'Profile', selected: navigationShell.currentIndex == 3, onTap: () => _onTap(3))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimerBellButton extends StatelessWidget {
  const _TimerBellButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: const SizedBox(
          width: 46,
          height: 46,
          child: Center(
            child: Icon(Icons.notifications_none_outlined, color: AppColors.textPrimary, size: 22),
          ),
        ),
      ),
    );
  }
}

class _RunningTimerBadge extends StatelessWidget {
  const _RunningTimerBadge({
    required this.timer,
    required this.onTap,
    required this.onPause,
  });

  final FocusTimer timer;
  final VoidCallback onTap;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.black,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined, color: AppColors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  formatTimerSeconds(timer.remainingSeconds),
                  style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onPause,
                  child: const Icon(Icons.pause, color: AppColors.white, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterUploadButton extends StatelessWidget {
  const _CenterUploadButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: AppColors.accent,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 52,
            height: 52,
            child: Icon(Icons.add, color: AppColors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.black : AppColors.textTertiary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1,
              duration: AppDurations.fast,
              curve: AppCurves.emphasized,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: AppDurations.fast,
              curve: AppCurves.emphasized,
              style: TextStyle(color: color, fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
              child: Text(label, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

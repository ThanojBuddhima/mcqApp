import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppDurations {
  static const fast = Duration(milliseconds: 220);
  static const normal = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 400);
}

class AppCurves {
  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const emphasized = Curves.easeOutQuart;
}

/// Wraps [StatefulNavigationShell] with a fade + slide when bottom tabs change.
class AnimatedTabBody extends StatelessWidget {
  const AnimatedTabBody({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(navigationShell.currentIndex),
      tween: Tween(begin: 0, end: 1),
      duration: AppDurations.fast,
      curve: AppCurves.emphasized,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: navigationShell,
    );
  }
}

class AppPageTransitions {
  static CustomTransitionPage<T> fadeSlide<T>({
    required GoRouterState state,
    required Widget child,
    Duration duration = AppDurations.normal,
    Offset begin = const Offset(0.05, 0),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: AppCurves.enter, reverseCurve: AppCurves.exit);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static CustomTransitionPage<T> slideUp<T>({
    required GoRouterState state,
    required Widget child,
    Duration duration = AppDurations.normal,
  }) {
    return fadeSlide<T>(
      state: state,
      child: child,
      duration: duration,
      begin: const Offset(0, 0.06),
    );
  }

  static CustomTransitionPage<T> fade<T>({
    required GoRouterState state,
    required Widget child,
    Duration duration = AppDurations.fast,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppCurves.enter, reverseCurve: AppCurves.exit),
          child: child,
        );
      },
    );
  }

  static CustomTransitionPage<T> sharedAxis<T>({
    required GoRouterState state,
    required Widget child,
    Duration duration = AppDurations.normal,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: AppCurves.enter, reverseCurve: AppCurves.exit);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Instant transition for shell tab roots (animated by [AnimatedTabBody]).
  static CustomTransitionPage<T> none<T>({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (_, __, ___, child) => child,
    );
  }
}

enum AppTransition { fadeSlide, slideUp, fade, sharedAxis, none }

GoRoute appRoute({
  required String path,
  String? name,
  Widget Function(BuildContext, GoRouterState)? builder,
  Page Function(BuildContext, GoRouterState)? pageBuilder,
  List<RouteBase> routes = const [],
  AppTransition transition = AppTransition.fadeSlide,
}) {
  return GoRoute(
    path: path,
    name: name,
    routes: routes,
    pageBuilder: pageBuilder ??
        (context, state) {
          final child = builder!(context, state);
          return switch (transition) {
            AppTransition.fadeSlide => AppPageTransitions.fadeSlide(state: state, child: child),
            AppTransition.slideUp => AppPageTransitions.slideUp(state: state, child: child),
            AppTransition.fade => AppPageTransitions.fade(state: state, child: child),
            AppTransition.sharedAxis => AppPageTransitions.sharedAxis(state: state, child: child),
            AppTransition.none => AppPageTransitions.none(state: state, child: child),
          };
        },
  );
}

GoRoute shellTabRoute(String path, Widget child) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => AppPageTransitions.none(state: state, child: child),
  );
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_screens.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/engagement/presentation/engagement_screens.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/past_papers/presentation/past_papers_screen.dart';
import '../../features/productivity/presentation/timer_screen.dart';
import '../../features/quiz/presentation/create_quiz_screen.dart';
import '../../features/quiz/presentation/quiz_detail_screen.dart';
import '../../features/quiz/presentation/quiz_screens.dart';
import '../../features/upload/presentation/upload_screen.dart';
import '../../shared/widgets/main_shell.dart';
import 'page_transitions.dart';

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this.ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }

  final Ref ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = ref.read(authProvider);
    final location = state.uri.path;
    final isAuth = auth.isAuthenticated;
    final role = auth.user?['role'] as String?;
    final isAdmin = role == 'admin';
    final isPublic = location == '/login' || location == '/register' || location == '/';
    final isAdminRoute = location.startsWith('/admin');

    if (!isAuth && !isPublic) return '/login';
    if (isAuth && isAdmin && !isAdminRoute && location != '/login' && location != '/register') return '/admin';
    if (isAuth && !isAdmin && isAdminRoute) return '/home';
    if (isAuth && (location == '/login' || location == '/register' || location == '/')) {
      return isAdmin ? '/admin' : '/home';
    }
    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  final n = RouterNotifier(ref);
  ref.onDispose(n.dispose);
  return n;
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/', redirect: (_, __) => '/login'),
      appRoute(path: '/login', transition: AppTransition.fade, builder: (_, __) => const LoginScreen()),
      appRoute(path: '/register', transition: AppTransition.slideUp, builder: (_, __) => const RegisterScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AdminShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [shellTabRoute('/admin', const AdminOverviewScreen())]),
          StatefulShellBranch(routes: [shellTabRoute('/admin/users', const AdminUsersScreen())]),
          StatefulShellBranch(routes: [shellTabRoute('/admin/jobs', const AdminJobsScreen())]),
          StatefulShellBranch(routes: [shellTabRoute('/admin/activity', const AdminActivityScreen())]),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [shellTabRoute('/home', const HomeScreen())]),
          StatefulShellBranch(routes: [shellTabRoute('/quizzes', const QuizListScreen())]),
          StatefulShellBranch(routes: [shellTabRoute('/analytics', const AnalyticsScreen())]),
          StatefulShellBranch(routes: [shellTabRoute('/profile', const ProfileScreen())]),
        ],
      ),
      appRoute(path: '/upload', transition: AppTransition.slideUp, builder: (_, __) => const UploadScreen()),
      appRoute(path: '/timer', transition: AppTransition.slideUp, builder: (_, __) => const ProductivityTimerScreen()),
      appRoute(path: '/my-quizzes', builder: (_, __) => const MyQuizzesScreen()),
      appRoute(path: '/favorites', builder: (_, __) => const FavoritesScreen()),
      appRoute(path: '/classes', builder: (_, __) => const ClassesScreen()),
      appRoute(
        path: '/classes/:classId/analytics',
        builder: (_, s) => ClassAnalyticsScreen(classId: s.pathParameters['classId']!),
      ),
      appRoute(path: '/past-papers', builder: (_, __) => const PastPapersScreen()),
      appRoute(path: '/quiz/create', transition: AppTransition.slideUp, builder: (_, __) => const CreateQuizScreen()),
      appRoute(
        path: '/quiz/edit/:id',
        transition: AppTransition.sharedAxis,
        builder: (_, s) => QuizEditorScreen(quizId: s.pathParameters['id']!),
      ),
      appRoute(
        path: '/quiz/:id/take',
        transition: AppTransition.sharedAxis,
        builder: (_, s) => TakeQuizScreen(quizId: s.pathParameters['id']!),
      ),
      appRoute(
        path: '/quiz/:id',
        transition: AppTransition.sharedAxis,
        builder: (_, s) => QuizDetailScreen(quizId: s.pathParameters['id']!),
      ),
      appRoute(
        path: '/leaderboard/:quizId',
        builder: (_, s) => LeaderboardScreen(quizId: s.pathParameters['quizId']!),
      ),
      appRoute(
        path: '/review/:attemptId',
        transition: AppTransition.sharedAxis,
        builder: (_, s) => ReviewScreen(attemptId: s.pathParameters['attemptId']!),
      ),
      appRoute(path: '/ai', transition: AppTransition.slideUp, builder: (_, __) => const AiAssistantScreen()),
    ],
  );
});

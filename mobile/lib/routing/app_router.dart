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
import '../../features/quiz/presentation/quiz_screens.dart';
import '../../features/upload/presentation/upload_screen.dart';
import '../../shared/widgets/main_shell.dart';

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
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AdminShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/admin', builder: (_, __) => const AdminOverviewScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/users', builder: (_, __) => const AdminUsersScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/jobs', builder: (_, __) => const AdminJobsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/activity', builder: (_, __) => const AdminActivityScreen())]),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/quizzes', builder: (_, __) => const QuizListScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen())]),
        ],
      ),
      GoRoute(path: '/upload', builder: (_, __) => const UploadScreen()),
      GoRoute(path: '/my-quizzes', builder: (_, __) => const MyQuizzesScreen()),
      GoRoute(path: '/favorites', builder: (_, __) => const FavoritesScreen()),
      GoRoute(path: '/classes', builder: (_, __) => const ClassesScreen()),
      GoRoute(path: '/classes/:classId/analytics', builder: (_, s) => ClassAnalyticsScreen(classId: s.pathParameters['classId']!)),
      GoRoute(path: '/past-papers', builder: (_, __) => const PastPapersScreen()),
      GoRoute(path: '/quiz/create', builder: (_, __) => const CreateQuizScreen()),
      GoRoute(path: '/quiz/edit/:id', builder: (_, s) => QuizEditorScreen(quizId: s.pathParameters['id']!)),
      GoRoute(path: '/quiz/:id', builder: (_, s) => TakeQuizScreen(quizId: s.pathParameters['id']!)),
      GoRoute(path: '/leaderboard/:quizId', builder: (_, s) => LeaderboardScreen(quizId: s.pathParameters['quizId']!)),
      GoRoute(path: '/review/:attemptId', builder: (_, s) => ReviewScreen(attemptId: s.pathParameters['attemptId']!)),
      GoRoute(path: '/ai', builder: (_, __) => const AiAssistantScreen()),
    ],
  );
});

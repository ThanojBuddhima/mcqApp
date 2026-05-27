import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/section_header.dart';
import '../utils/grade_categories.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/visible_level_provider.dart';
import '../../quiz/quiz_subjects.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Map<String, dynamic>? _analytics;
  List<dynamic> _quizzes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dio = ref.read(dioProvider);
      final analytics = await dio.get('/classes/me/analytics');
      final quizzes = await dio.get('/quizzes', queryParameters: {'status': 'published', 'limit': 5});
      if (mounted) {
        setState(() {
          _analytics = Map<String, dynamic>.from(analytics.data);
          _quizzes = quizzes.data['items'] ?? [];
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final visibleLevels = ref.watch(visibleLevelProvider);
    final name = (user?['display_name'] as String?)?.split(' ').first ?? 'Student';
    final progress = (_analytics?['avg_percentage'] as num?)?.toInt() ?? 0;
    final attempts = _analytics?['total_attempts'] ?? 0;
    final levelQuizzes = _quizzes.where((q) {
      final metadata = q['metadata_extra'] as Map<String, dynamic>?;
      return QuizSubjects.matchesLevels(metadata, visibleLevels.levelSet);
    }).toList();
    final firstQuiz = levelQuizzes.isNotEmpty ? levelQuizzes.first : null;
    final categories = GradeCategories.forLevels(visibleLevels.levelSet);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.black,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    _iconBtn(Icons.menu_outlined, () {}),
                    const Spacer(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hello, $name', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    Text('Ready to learn today?', style: Theme.of(context).textTheme.headlineMedium),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 88,
                        height: 88,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 88,
                              height: 88,
                              child: CircularProgressIndicator(
                                value: progress / 100,
                                strokeWidth: 4,
                                backgroundColor: AppColors.border,
                                color: AppColors.black,
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$progress%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                const Text('Progress', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Your progress', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            const Text('Keep it up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            const SizedBox(height: 16),
                            _statRow('Quizzes done', '$attempts'),
                            const SizedBox(height: 8),
                            _statRow('Avg score', '${_analytics?['avg_score'] ?? 0}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (firstQuiz != null) ...[
                SectionHeader(title: 'Continue learning', onSeeAll: () => context.go('/quizzes')),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ContinueCard(
                    title: firstQuiz['title'] ?? 'Quiz',
                    subtitle: '${firstQuiz['total_marks'] ?? 0} marks · ${firstQuiz['time_limit_minutes'] ?? 30} min',
                    onTap: () => context.push('/quiz/${firstQuiz['id']}'),
                  ),
                ),
              ],
              SectionHeader(title: 'Categories', onSeeAll: () => context.push('/past-papers')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: categories
                      .map((c) => _CategoryCard(c.title, c.subtitle, c.icon, () => context.push('/past-papers')))
                      .toList(),
                ),
              ),
              SectionHeader(title: 'Recent quizzes', onSeeAll: () => context.go('/quizzes')),
              ...levelQuizzes.take(3).map((q) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _RecentCard(
                      title: q['title'] ?? '',
                      marks: '${q['total_marks']} marks',
                      onTap: () => context.push('/quiz/${q['id']}'),
                    ),
                  )),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _chip('Upload paper', Icons.upload_outlined, () => context.push('/upload')),
                    _chip('Past papers', Icons.menu_book_outlined, () => context.push('/past-papers')),
                    _chip('AI assistant', Icons.auto_awesome_outlined, () => context.push('/ai')),
                    _chip('Classes', Icons.groups_outlined, () => context.push('/classes')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(padding: const EdgeInsets.all(12), child: Icon(icon, color: AppColors.textPrimary, size: 22)),
        ),
      );

  Widget _statRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
        ],
      );

  Widget _chip(String label, IconData icon, VoidCallback onTap) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.title, required this.subtitle, required this.onTap});
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.play_lesson_outlined, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(value: 0.66, minHeight: 4, backgroundColor: AppColors.surface, color: AppColors.black),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(100),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(100),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.play_arrow, color: AppColors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard(this.title, this.count, this.icon, this.onTap);
  final String title;
  final String count;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subjectKey = QuizSubjects.filterKey(title);
    final color = QuizSubjects.subjectColor(subjectKey);
    final surface = QuizSubjects.subjectSurface(subjectKey);

    return Material(
      color: subjectKey != null ? surface : AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: subjectKey != null ? color : AppColors.textPrimary, size: 26),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
              Text(count, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.title, required this.marks, required this.onTap});
  final String title;
  final String marks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.quiz_outlined, color: AppColors.textPrimary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(marks, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

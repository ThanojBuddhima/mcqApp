import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../productivity/providers/timer_provider.dart';
import '../providers/quiz_list_provider.dart';
import '../quiz_subjects.dart';
import '../../profile/providers/visible_level_provider.dart';

class QuizListScreen extends ConsumerStatefulWidget {
  const QuizListScreen({super.key});

  @override
  ConsumerState<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends ConsumerState<QuizListScreen> {
  List<dynamic> _quizzes = [];
  bool _loading = true;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/quizzes', queryParameters: {'status': 'published'});
      setState(() {
        _quizzes = res.data['items'] ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<dynamic> get _levelQuizzes {
    final levels = ref.read(visibleLevelProvider).levelSet;
    return _quizzes.where((q) {
      final metadata = q['metadata_extra'] as Map<String, dynamic>?;
      return QuizSubjects.matchesLevels(metadata, levels);
    }).toList();
  }

  List<dynamic> get _visibleQuizzes {
    final levelQuizzes = _levelQuizzes;
    if (_filter == 'All') return levelQuizzes;
    return levelQuizzes.where((q) {
      final metadata = q['metadata_extra'] as Map<String, dynamic>?;
      return QuizSubjects.matchesFilter(metadata, _filter);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleLevels = ref.watch(visibleLevelProvider);
    final courseFilters = QuizSubjects.courseFiltersForLevels(visibleLevels.levelSet);

    ref.listen<VisibleLevels>(visibleLevelProvider, (prev, next) {
      if (prev != next) setState(() => _filter = 'All');
    });

    ref.listen<int>(quizListRefreshProvider, (prev, next) {
      if (prev != next) _load();
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Courses', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text('Browse and practice quizzes', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${visibleLevels.label} content',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: courseFilters.map((f) {
                        final sel = _filter == f;
                        final subjectKey = QuizSubjects.filterKey(f);
                        if (subjectKey == null) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: FilterChip(
                              label: Text(f),
                              selected: sel,
                              onSelected: (_) => setState(() => _filter = f),
                              backgroundColor: AppColors.white,
                              selectedColor: AppColors.white,
                              side: BorderSide(color: sel ? AppColors.borderStrong : AppColors.border, width: sel ? 1.5 : 1),
                              labelStyle: TextStyle(color: AppColors.textPrimary, fontWeight: sel ? FontWeight.w600 : FontWeight.w400),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                              showCheckmark: false,
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: SubjectChip(
                            label: f,
                            subjectKey: subjectKey,
                            selected: sel,
                            onTap: () => setState(() => _filter = f),
                            compact: true,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _visibleQuizzes.isEmpty
                      ? Center(child: Text(_levelQuizzes.isEmpty ? 'No quizzes yet' : 'No quizzes for $_filter'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: _visibleQuizzes.length,
                          itemBuilder: (context, i) => _QuizListTile(quiz: _visibleQuizzes[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizListTile extends StatelessWidget {
  const _QuizListTile({required this.quiz});

  final Map<String, dynamic> quiz;

  @override
  Widget build(BuildContext context) {
    final questionCount = (quiz['questions'] as List?)?.length ?? 0;
    final metadata = quiz['metadata_extra'] as Map<String, dynamic>? ?? {};
    final subjectKey = metadata['subject'] as String?;
    final level = QuizSubjects.levelLabel(metadata['level'] as String?);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => context.push('/quiz/${quiz['id']}'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                SubjectIcon(subjectKey: subjectKey),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(quiz['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (level.isNotEmpty) level,
                          '$questionCount questions',
                          '${quiz['total_marks']} marks',
                          if (quiz['time_limit_minutes'] != null) '${quiz['time_limit_minutes']} min',
                        ].join(' · '),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(100),
                  child: InkWell(
                    onTap: () => context.push('/quiz/${quiz['id']}/take'),
                    borderRadius: BorderRadius.circular(100),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.play_arrow, color: AppColors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TakeQuizScreen extends ConsumerStatefulWidget {
  const TakeQuizScreen({super.key, required this.quizId});
  final String quizId;

  @override
  ConsumerState<TakeQuizScreen> createState() => _TakeQuizScreenState();
}

class _TakeQuizScreenState extends ConsumerState<TakeQuizScreen> {
  Map<String, dynamic>? _quiz;
  String? _attemptId;
  final Map<String, String> _answers = {};
  bool _loading = true;
  bool _submitting = false;
  Timer? _quizTimer;
  int? _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _quizTimer?.cancel();
    super.dispose();
  }

  void _startQuizTimer(int? minutes) {
    _quizTimer?.cancel();
    if (minutes == null || minutes <= 0) return;

    setState(() => _remainingSeconds = minutes * 60);
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _remainingSeconds == null) return;
      if (_remainingSeconds! <= 1) {
        _quizTimer?.cancel();
        setState(() => _remainingSeconds = 0);
        _submit(timedOut: true);
        return;
      }
      setState(() => _remainingSeconds = _remainingSeconds! - 1);
    });
  }

  Future<void> _init() async {
    try {
      final dio = ref.read(dioProvider);
      final quizRes = await dio.get('/quizzes/${widget.quizId}');
      final attemptRes = await dio.post('/quizzes/${widget.quizId}/attempts');
      if (!mounted) return;
      final quiz = Map<String, dynamic>.from(quizRes.data);
      setState(() {
        _quiz = quiz;
        _attemptId = attemptRes.data['id'];
        _loading = false;
      });
      _startQuizTimer(_parseMinutes(quiz['time_limit_minutes']));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not start quiz')));
      context.pop();
    }
  }

  int? _parseMinutes(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  Future<void> _submit({bool timedOut = false}) async {
    if (_attemptId == null || _submitting) return;
    _submitting = true;
    _quizTimer?.cancel();

    try {
      final dio = ref.read(dioProvider);
      final questions = _quiz?['questions'] as List? ?? [];
      await dio.put('/attempts/$_attemptId/answers', data: {
        'answers': questions.map((q) => {
              'question_id': q['id'],
              'selected_answer': _answers[q['id']],
            }).toList(),
      });
      final res = await dio.post('/attempts/$_attemptId/submit');
      if (!mounted) return;
      if (timedOut) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Time is up! Quiz submitted.')));
      }
      context.push('/review/$_attemptId', extra: res.data);
    } catch (_) {
      if (mounted) {
        _submitting = false;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not submit quiz')));
      }
    }
  }

  int _answeredCount(List questions) {
    return questions.where((q) {
      final id = q['id'];
      final answer = _answers[id];
      return answer != null && answer.isNotEmpty;
    }).length;
  }

  int _progressPercent(List questions) {
    if (questions.isEmpty) return 0;
    return ((_answeredCount(questions) / questions.length) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final questions = _quiz?['questions'] as List? ?? [];
    final answered = _answeredCount(questions);
    final progress = _progressPercent(questions);

    return Scaffold(
      appBar: AppBar(
        title: Text(_quiz?['title'] ?? 'Quiz'),
        actions: [
          if (_remainingSeconds != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: _QuizTimerBadge(remainingSeconds: _remainingSeconds!),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () async {
              await ref.read(dioProvider).post('/quizzes/${widget.quizId}/favorite');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to favorites')));
              }
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: questions.length,
        itemBuilder: (context, i) {
          final q = questions[i];
          final options = q['options'] as List? ?? [];
          final selected = _answers[q['id']];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Question ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text(q['question_text'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  if (q['question_image_url'] != null) ...[
                    const SizedBox(height: 12),
                    Image.network(q['question_image_url'], height: 120, fit: BoxFit.contain),
                  ],
                  const SizedBox(height: 16),
                  ...options.map((o) {
                    final opt = o as Map<String, dynamic>;
                    final label = opt['label'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(opt['option_text'] ?? '', style: const TextStyle(fontSize: 15))),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: options.map((o) {
                      final opt = o as Map<String, dynamic>;
                      final label = opt['label'] as String? ?? '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _AnswerSelectButton(
                          label: label,
                          selected: selected == label,
                          onTap: () => setState(() {
                            if (selected == label) {
                              _answers.remove(q['id']);
                            } else {
                              _answers[q['id']] = label;
                            }
                          }),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 52,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: Material(
                color: AppColors.accent.withValues(alpha: 0.3),
                child: InkWell(
                  onTap: _submitting ? null : _submit,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress / 100,
                        child: const ColoredBox(color: AppColors.accent),
                      ),
                      Center(
                        child: Text(
                          progress == 100
                              ? 'Submit quiz · 100%'
                              : 'Submit quiz · $progress% ($answered/${questions.length})',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizTimerBadge extends StatelessWidget {
  const _QuizTimerBadge({required this.remainingSeconds});

  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    final urgent = remainingSeconds <= 60;
    return Material(
      color: urgent ? AppColors.error : AppColors.black,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, color: AppColors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              formatTimerSeconds(remainingSeconds),
              style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerSelectButton extends StatelessWidget {
  const _AnswerSelectButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.black : AppColors.white,
      shape: CircleBorder(
        side: BorderSide(color: selected ? AppColors.black : AppColors.border, width: selected ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key, required this.attemptId});
  final String attemptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(dioProvider).get('/attempts/$attemptId/review'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final data = snapshot.data!.data;
        final attempt = data['attempt'];
        final questions = data['questions'] as List;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('Review Answers')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text('Score: ${attempt['score']} / ${attempt['total_marks']}', style: Theme.of(context).textTheme.headlineSmall),
                      Text('Duration: ${attempt['duration_seconds'] ?? 0}s'),
                    ],
                  ),
                ),
              ),
              ...questions.map((q) => Card(
                    margin: const EdgeInsets.only(top: 12),
                    child: ListTile(
                      title: Text(q['question_text']),
                      subtitle: Text('Your answer: ${q['user_answer'] ?? '-'} · Correct: ${q['correct_answer'] ?? '-'}'),
                      trailing: Icon(
                        q['is_correct'] == true ? Icons.check_circle_outline : Icons.cancel_outlined,
                        color: q['is_correct'] == true ? AppColors.success : AppColors.error,
                      ),
                    ),
                  )),
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Go home'),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

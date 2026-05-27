import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Courses', style: Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 4),
                          Text('Browse and practice quizzes', style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 16),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: ['All', 'Physics', 'Math'].map((f) {
                                final sel = _filter == f;
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
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _quizzes.isEmpty
                      ? const SliverFillRemaining(child: Center(child: Text('No quizzes yet')))
                      : SliverPadding(
                          padding: const EdgeInsets.all(20),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final q = _quizzes[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Material(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    child: InkWell(
                                      onTap: () => context.push('/quiz/${q['id']}'),
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
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                                              child: const Icon(Icons.quiz_outlined, color: AppColors.textPrimary),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(q['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                                  Text('${q['total_marks']} marks · ${q['time_limit_minutes'] ?? '-'} min',
                                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                                ],
                                              ),
                                            ),
                                            Material(
                                              color: AppColors.accent,
                                              borderRadius: BorderRadius.circular(100),
                                              child: InkWell(
                                                onTap: () => context.push('/quiz/${q['id']}'),
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
                              },
                              childCount: _quizzes.length,
                            ),
                          ),
                        ),
                ],
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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final dio = ref.read(dioProvider);
    final quizRes = await dio.get('/quizzes/${widget.quizId}');
    final attemptRes = await dio.post('/quizzes/${widget.quizId}/attempts');
    setState(() {
      _quiz = Map<String, dynamic>.from(quizRes.data);
      _attemptId = attemptRes.data['id'];
      _loading = false;
    });
  }

  Future<void> _submit() async {
    if (_attemptId == null) return;
    final dio = ref.read(dioProvider);
    final questions = _quiz?['questions'] as List? ?? [];
    await dio.put('/attempts/$_attemptId/answers', data: {
      'answers': questions.map((q) => {
            'question_id': q['id'],
            'selected_answer': _answers[q['id']],
          }).toList(),
    });
    final res = await dio.post('/attempts/$_attemptId/submit');
    if (mounted) context.push('/review/$_attemptId', extra: res.data);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final questions = _quiz?['questions'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_quiz?['title'] ?? 'Quiz'),
        actions: [
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
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder: (context, i) {
          final q = questions[i];
          final options = q['options'] as List? ?? [];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Q${i + 1}. ${q['question_text']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  if (q['question_image_url'] != null) ...[
                    const SizedBox(height: 8),
                    Image.network(q['question_image_url'], height: 120, fit: BoxFit.contain),
                  ],
                  const SizedBox(height: 12),
                  ...options.map((o) => RadioListTile<String>(
                        title: Text(o['option_text'] ?? ''),
                        value: o['label'],
                        groupValue: _answers[q['id']],
                        onChanged: (v) => setState(() => _answers[q['id']] = v!),
                      )),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(onPressed: _submit, child: const Text('Submit Quiz')),
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
          appBar: AppBar(title: const Text('Review Answers')),
          body: ListView(
            padding: const EdgeInsets.all(16),
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
        );
      },
    );
  }
}

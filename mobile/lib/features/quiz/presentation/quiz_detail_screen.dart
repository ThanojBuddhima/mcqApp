import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';

class QuizDetailScreen extends ConsumerStatefulWidget {
  const QuizDetailScreen({super.key, required this.quizId});

  final String quizId;

  @override
  ConsumerState<QuizDetailScreen> createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends ConsumerState<QuizDetailScreen> {
  Map<String, dynamic>? _quiz;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/quizzes/${widget.quizId}');
      setState(() {
        _quiz = Map<String, dynamic>.from(res.data);
        _loading = false;
      });
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      setState(() {
        _error = detail is String ? detail : 'Could not load quiz';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not load quiz';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _quiz == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Quiz not found', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final quiz = _quiz!;
    final questions = quiz['questions'] as List? ?? [];
    final metadata = quiz['metadata_extra'] as Map<String, dynamic>? ?? {};
    final topic = metadata['topic'] as String? ?? quiz['description'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Quiz details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Text(quiz['title'] ?? 'Untitled', style: Theme.of(context).textTheme.headlineSmall),
          if (topic != null && topic.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(topic, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatChip(icon: Icons.help_outline, label: '${questions.length} questions'),
              _StatChip(icon: Icons.star_outline, label: '${quiz['total_marks'] ?? 0} marks'),
              _StatChip(icon: Icons.timer_outlined, label: '${quiz['time_limit_minutes'] ?? '-'} min'),
            ],
          ),
          const SizedBox(height: 28),
          Text('Questions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (questions.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
              child: const Text('No questions in this quiz yet.', style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ...questions.asMap().entries.map((entry) {
              final index = entry.key;
              final q = entry.value as Map<String, dynamic>;
              final options = q['options'] as List? ?? [];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
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
                      Text('Question ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Text(q['question_text'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      if (options.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...options.map((o) {
                          final opt = o as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
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
                                  child: Text(
                                    opt['label'] ?? '',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(opt['option_text'] ?? '', style: const TextStyle(fontSize: 14))),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              );
            }),
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
              onPressed: questions.isEmpty ? null : () => context.push('/quiz/${widget.quizId}/take'),
              child: const Text('Start quiz'),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

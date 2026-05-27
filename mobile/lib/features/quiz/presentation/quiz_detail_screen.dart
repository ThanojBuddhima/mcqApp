import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../quiz_subjects.dart';

class QuizDetailScreen extends ConsumerStatefulWidget {
  const QuizDetailScreen({super.key, required this.quizId});

  final String quizId;

  @override
  ConsumerState<QuizDetailScreen> createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends ConsumerState<QuizDetailScreen> {
  Map<String, dynamic>? _quiz;
  List<dynamic> _attempts = [];
  Map<String, dynamic>? _selectedReview;
  String? _selectedAttemptId;
  bool _loading = true;
  bool _loadingReview = false;
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
      final results = await Future.wait([
        dio.get('/quizzes/${widget.quizId}'),
        dio.get('/quizzes/${widget.quizId}/attempts/me'),
      ]);
      final attempts = results[1].data as List? ?? [];
      setState(() {
        _quiz = Map<String, dynamic>.from(results[0].data);
        _attempts = attempts;
        _loading = false;
      });
      if (attempts.isNotEmpty) {
        await _loadReview(attempts.first['id'] as String);
      }
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

  Future<void> _loadReview(String attemptId) async {
    setState(() {
      _loadingReview = true;
      _selectedAttemptId = attemptId;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/attempts/$attemptId/review');
      setState(() => _selectedReview = Map<String, dynamic>.from(res.data));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load attempt history')));
      }
    } finally {
      if (mounted) setState(() => _loadingReview = false);
    }
  }

  String? _displayDescription(Map<String, dynamic> quiz) {
    final description = (quiz['description'] as String?)?.trim();
    if (description == null || description.isEmpty) return null;
    final topic = (quiz['metadata_extra'] as Map<String, dynamic>?)?['topic'] as String? ?? quiz['title'] as String?;
    if (topic != null && description == 'Topic: $topic') return null;
    return description;
  }

  String _formatAttemptDate(String? iso) {
    if (iso == null) return 'Unknown date';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MMM d, yyyy · h:mm a').format(dt);
    } catch (_) {
      return iso;
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
    final topic = metadata['topic'] as String? ?? quiz['title'] as String?;
    final description = _displayDescription(quiz);
    final level = QuizSubjects.levelLabel(metadata['level'] as String?);
    final subjectKey = metadata['subject'] as String?;
    final hasHistory = _attempts.isNotEmpty;
    final reviewAttempt = _selectedReview?['attempt'] as Map<String, dynamic>?;
    final reviewQuestions = _selectedReview?['questions'] as List? ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Quiz details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Text(quiz['title'] ?? 'Untitled', style: Theme.of(context).textTheme.headlineSmall),
          if (subjectKey != null) ...[
            const SizedBox(height: 12),
            SubjectIcon(subjectKey: subjectKey, size: 40, iconSize: 20, radius: 12),
          ],
          if (topic != null && topic.isNotEmpty && topic != quiz['title']) ...[
            const SizedBox(height: 6),
            Text('Topic: $topic', style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (level.isNotEmpty) _StatChip(icon: Icons.school_outlined, label: level),
              _StatChip(icon: Icons.help_outline, label: '${questions.length} questions'),
              _StatChip(icon: Icons.star_outline, label: '${quiz['total_marks'] ?? 0} marks'),
              _StatChip(
                icon: Icons.timer_outlined,
                label: quiz['time_limit_minutes'] != null ? '${quiz['time_limit_minutes']} min' : 'No time limit',
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text('Description', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              description ?? 'No description provided for this quiz.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: description != null ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          if (hasHistory) ...[
            const SizedBox(height: 28),
            Text('Your history', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (_attempts.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _attempts.asMap().entries.map((entry) {
                    final attempt = entry.value as Map<String, dynamic>;
                    final id = attempt['id'] as String;
                    final selected = id == _selectedAttemptId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text('Attempt ${_attempts.length - entry.key} · ${attempt['score'] ?? 0}/${attempt['total_marks'] ?? 0}'),
                        selected: selected,
                        onSelected: (_) => _loadReview(id),
                        backgroundColor: AppColors.white,
                        selectedColor: AppColors.white,
                        side: BorderSide(color: selected ? AppColors.borderStrong : AppColors.border, width: selected ? 1.5 : 1),
                        labelStyle: TextStyle(color: AppColors.textPrimary, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                        showCheckmark: false,
                      ),
                    );
                  }).toList(),
                ),
              ),
            if (_attempts.length > 1) const SizedBox(height: 12),
            if (_loadingReview)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (reviewAttempt != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Score: ${reviewAttempt['score'] ?? 0} / ${reviewAttempt['total_marks'] ?? 0}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatAttemptDate(reviewAttempt['submitted_at'] as String?)} · ${reviewAttempt['duration_seconds'] ?? 0}s',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...reviewQuestions.asMap().entries.map((entry) {
                final index = entry.key;
                final q = entry.value as Map<String, dynamic>;
                final isCorrect = q['is_correct'] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Question ${index + 1}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text(q['question_text'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              const SizedBox(height: 8),
                              Text(
                                'Your answer: ${q['user_answer'] ?? '-'} · Correct: ${q['correct_answer'] ?? '-'}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isCorrect ? Icons.check_circle_outline : Icons.cancel_outlined,
                          color: isCorrect ? AppColors.success : AppColors.error,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ] else ...[
            const SizedBox(height: 20),
            Text(
              'Questions are hidden until you start the quiz.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
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
              child: Text(hasHistory ? 'Start quiz again' : 'Start quiz'),
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

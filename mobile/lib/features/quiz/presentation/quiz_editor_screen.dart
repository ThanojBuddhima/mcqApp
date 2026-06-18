import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/quiz_list_provider.dart';

/// Editable quiz editor screen for tutor review of OCR-generated quizzes.
/// Supports editing question text, option text, marking correct answers,
/// deleting questions, saving drafts, and publishing.
class QuizEditorScreen extends ConsumerStatefulWidget {
  const QuizEditorScreen({super.key, required this.quizId});
  final String quizId;

  @override
  ConsumerState<QuizEditorScreen> createState() => _QuizEditorScreenState();
}

class _QuizEditorScreenState extends ConsumerState<QuizEditorScreen> {
  Map<String, dynamic>? _quiz;
  List<_EditableQuestion> _questions = [];
  List<dynamic> _pages = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/quizzes/${widget.quizId}');
      final quiz = Map<String, dynamic>.from(res.data);
      final rawQuestions = quiz['questions'] as List? ?? [];

      List<dynamic> pages = [];
      try {
        final pagesRes = await dio.get('/documents/by-quiz/${widget.quizId}/pages');
        pages = pagesRes.data as List;
      } catch (_) {
        // Ignored if no document job exists for this quiz (e.g. manual creation)
      }

      _titleController.text = quiz['title'] ?? '';

      final editableQuestions = rawQuestions.asMap().entries.map((entry) {
        final q = entry.value as Map<String, dynamic>;
        final options = (q['options'] as List? ?? []).cast<Map<String, dynamic>>();
        return _EditableQuestion.fromJson(q, options);
      }).toList();

      setState(() {
        _quiz = quiz;
        _questions = editableQuestions;
        _pages = pages;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load quiz';
        _loading = false;
      });
    }
  }

  void _deleteQuestion(int index) {
    if (_questions.length <= 1) return;
    setState(() {
      _questions[index].dispose();
      _questions.removeAt(index);
    });
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/quizzes/${widget.quizId}', data: _buildPayload());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft saved')),
        );
      }
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      final message = detail is String ? detail : 'Failed to save';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _publish() async {
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/quizzes/${widget.quizId}', data: _buildPayload());
      await dio.post('/quizzes/${widget.quizId}/publish');
      ref.read(quizListRefreshProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz published!')),
        );
        context.go('/quizzes');
      }
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      final message = detail is String ? detail : 'Failed to publish';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _buildPayload() {
    const labels = ['A', 'B', 'C', 'D', 'E'];
    return {
      'title': _titleController.text.trim(),
      'questions': _questions.asMap().entries.map((entry) {
        final i = entry.key;
        final q = entry.value;
        return {
          'order_index': i,
          'type': 'mcq',
          'question_text': q.questionController.text.trim(),
          'layout_refs': q.layoutRefs ?? {},
          'marks': 1,
          'options': q.optionControllers.asMap().entries.map((oe) {
            final oi = oe.key;
            final oc = oe.value;
            return {
              'label': labels[oi],
              'option_text': oc.text.trim(),
              'is_correct': oi == q.correctIndex,
            };
          }).toList(),
        };
      }).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.black)));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Quiz')),
        body: Center(child: Text(_error!)),
      );
    }

    final isDraft = _quiz?['status'] == 'draft';
    final questionCount = _questions.where((q) => q.isComplete).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Quiz'),
        actions: [
          if (isDraft)
            TextButton(
              onPressed: _saving ? null : _saveDraft,
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Title
          Text('Quiz title', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(hintText: 'Quiz title'),
            enabled: isDraft,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDraft ? AppColors.surface : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isDraft ? Icons.edit_outlined : Icons.check_circle_outline,
                  size: 18,
                  color: isDraft ? AppColors.textSecondary : AppColors.success,
                ),
                const SizedBox(width: 8),
                Text(
                  isDraft
                      ? 'Draft · $questionCount complete questions'
                      : 'Published · $questionCount questions',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDraft ? AppColors.textSecondary : AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Questions
          Text('Questions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ..._questions.asMap().entries.map((entry) {
            final index = entry.key;
            final q = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _EditableQuestionCard(
                index: index,
                question: q,
                pages: _pages,
                canRemove: _questions.length > 1 && isDraft,
                enabled: isDraft,
                onRemove: () => _deleteQuestion(index),
                onCorrectChanged: (i) => setState(() => q.correctIndex = i),
                onFieldsChanged: () => setState(() {}),
              ),
            );
          }),

          const SizedBox(height: 16),

          // Publish button
          if (isDraft)
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _publish,
                child: const Text('Publish Quiz'),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditableQuestion {
  _EditableQuestion({
    required this.questionController,
    required this.optionControllers,
    this.correctIndex,
    this.questionId,
    this.layoutRefs,
  });

  final String? questionId;
  final TextEditingController questionController;
  final List<TextEditingController> optionControllers;
  final Map<String, dynamic>? layoutRefs;
  int? correctIndex;

  bool get isComplete {
    if (questionController.text.trim().isEmpty) return false;
    for (final c in optionControllers) {
      if (c.text.trim().isEmpty) return false;
    }
    return correctIndex != null;
  }

  void dispose() {
    questionController.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
  }

  factory _EditableQuestion.fromJson(
    Map<String, dynamic> q,
    List<Map<String, dynamic>> options,
  ) {
    final questionController = TextEditingController(text: q['question_text'] ?? '');
    final optionControllers = options.map((o) {
      return TextEditingController(text: o['option_text'] ?? '');
    }).toList();

    // Ensure at least 4 option controllers
    while (optionControllers.length < 4) {
      optionControllers.add(TextEditingController());
    }

    // Find which option is marked correct
    int? correctIndex;
    for (var i = 0; i < options.length; i++) {
      if (options[i]['is_correct'] == true) {
        correctIndex = i;
        break;
      }
    }

    return _EditableQuestion(
      questionId: q['id'],
      questionController: questionController,
      optionControllers: optionControllers,
      correctIndex: correctIndex,
      layoutRefs: q['layout_refs'],
    );
  }
}

class _EditableQuestionCard extends StatelessWidget {
  const _EditableQuestionCard({
    required this.index,
    required this.question,
    required this.pages,
    required this.canRemove,
    required this.enabled,
    required this.onRemove,
    required this.onCorrectChanged,
    required this.onFieldsChanged,
  });

  final int index;
  final _EditableQuestion question;
  final List<dynamic> pages;
  final bool canRemove;
  final bool enabled;
  final VoidCallback onRemove;
  final ValueChanged<int> onCorrectChanged;
  final VoidCallback onFieldsChanged;

  Widget? _buildOriginalImage() {
    if (pages.isEmpty) return null;
    final refs = question.layoutRefs;
    if (refs == null || refs.isEmpty) return null;

    final blockIds = refs.values.expand((v) => (v as List).cast<String>()).toSet();
    if (blockIds.isEmpty) return null;

    // Find the page containing these blocks
    for (final page in pages) {
      final layoutJson = page['layout_json'] as List? ?? [];
      for (final block in layoutJson) {
        if (blockIds.contains(block['block_id'])) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              page['image_url'],
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter, // Rough approximation
            ),
          );
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['A', 'B', 'C', 'D', 'E'];
    final optionCount = question.optionControllers.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Question ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              if (question.isComplete)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                ),
              if (question.correctIndex == null && question.questionController.text.trim().isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.warning_amber_outlined, size: 16, color: Color(0xFFFF9800)),
                ),
              const Spacer(),
              if (canRemove)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          if (_buildOriginalImage() case final img?) ...[
            Text('Original text', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            img,
            const SizedBox(height: 16),
          ],

          TextField(
            controller: question.questionController,
            decoration: const InputDecoration(hintText: 'Question text'),
            maxLines: 3,
            minLines: 1,
            enabled: enabled,
            onChanged: (_) => onFieldsChanged(),
          ),
          const SizedBox(height: 16),
          Text(
            'Answers — tap letter to mark correct',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ...List.generate(optionCount, (i) {
            final isCorrect = question.correctIndex == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: enabled ? () => onCorrectChanged(i) : null,
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCorrect ? AppColors.black : AppColors.border,
                          width: isCorrect ? 2 : 1,
                        ),
                        color: isCorrect ? AppColors.black : AppColors.white,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isCorrect ? AppColors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: question.optionControllers[i],
                      decoration: InputDecoration(hintText: 'Answer ${labels[i]}'),
                      enabled: enabled,
                      onChanged: (_) => onFieldsChanged(),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

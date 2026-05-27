import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/quiz_list_provider.dart';

class _QuestionDraft {
  _QuestionDraft({required this.optionCount})
      : optionControllers = List.generate(optionCount, (_) => TextEditingController());

  final TextEditingController questionController = TextEditingController();
  final List<TextEditingController> optionControllers;
  int correctIndex = 0;
  bool correctAnswerConfirmed = false;
  final int optionCount;

  bool get isComplete {
    if (questionController.text.trim().isEmpty) return false;
    for (final c in optionControllers) {
      if (c.text.trim().isEmpty) return false;
    }
    return true;
  }

  void dispose() {
    questionController.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
  }

  Map<String, dynamic> toJson(int orderIndex) {
    const labels = ['A', 'B', 'C', 'D', 'E'];
    return {
      'order_index': orderIndex,
      'type': 'mcq',
      'question_text': questionController.text.trim(),
      'marks': 1,
      'options': List.generate(optionCount, (i) {
        return {
          'label': labels[i],
          'option_text': optionControllers[i].text.trim(),
          'is_correct': i == correctIndex,
        };
      }),
    };
  }
}

class CreateQuizScreen extends ConsumerStatefulWidget {
  const CreateQuizScreen({super.key});

  @override
  ConsumerState<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends ConsumerState<CreateQuizScreen> {
  final _topicController = TextEditingController();
  final _scrollController = ScrollController();
  final _questions = <_QuestionDraft>[];
  final _questionKeys = <GlobalKey>[];
  int _optionCount = 4;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _addQuestion();
  }

  @override
  void dispose() {
    _topicController.dispose();
    _scrollController.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  void _setOptionCount(int count) {
    if (count == _optionCount) return;
    setState(() {
      final existing = _questions.length;
      for (final q in _questions) {
        q.dispose();
      }
      _optionCount = count;
      _questions
        ..clear()
        ..addAll(List.generate(existing, (_) => _QuestionDraft(optionCount: count)));
      _questionKeys
        ..clear()
        ..addAll(List.generate(existing, (_) => GlobalKey()));
    });
  }

  void _addQuestion({bool scrollToNew = false}) {
    setState(() {
      _questions.add(_QuestionDraft(optionCount: _optionCount));
      _questionKeys.add(GlobalKey());
    });
    if (scrollToNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = _questionKeys.last;
        final context = key.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    }
  }

  void _removeQuestion(int index) {
    if (_questions.length <= 1) return;
    setState(() {
      _questions[index].dispose();
      _questions.removeAt(index);
      _questionKeys.removeAt(index);
    });
  }

  void _handleCorrectSelected(int questionIndex, int correctIndex) {
    setState(() {
      final q = _questions[questionIndex];
      q.correctIndex = correctIndex;
      q.correctAnswerConfirmed = true;
    });
    _maybeAutoAddQuestion(questionIndex);
  }

  void _maybeAutoAddQuestion(int questionIndex) {
    if (questionIndex != _questions.length - 1) return;
    final q = _questions[questionIndex];
    if (!q.correctAnswerConfirmed || !q.isComplete) return;
    _addQuestion(scrollToNew: true);
  }

  List<_QuestionDraft> get _completeQuestions =>
      _questions.where((q) => q.isComplete && q.correctAnswerConfirmed).toList();

  String? _validate() {
    if (_topicController.text.trim().isEmpty) return 'Enter a topic';
    final complete = _completeQuestions;
    if (complete.isEmpty) return 'Add at least one complete question';
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (!q.isComplete && !q.correctAnswerConfirmed) continue;
      if (q.questionController.text.trim().isEmpty) return 'Question ${i + 1} text is required';
      for (var j = 0; j < q.optionControllers.length; j++) {
        if (q.optionControllers[j].text.trim().isEmpty) {
          return 'Fill all answers for question ${i + 1}';
        }
      }
      if (!q.correctAnswerConfirmed) return 'Mark the correct answer for question ${i + 1}';
    }
    return null;
  }

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final topic = _topicController.text.trim();
      final complete = _completeQuestions;
      final res = await dio.post('/quizzes', data: {
        'title': topic,
        'description': 'Topic: $topic',
        'visibility': 'public',
        'time_limit_minutes': 30,
        'metadata_extra': {'topic': topic, 'option_count': _optionCount},
        'questions': complete.asMap().entries.map((e) => e.value.toJson(e.key)).toList(),
      });
      final quizId = res.data['id'];
      await dio.post('/quizzes/$quizId/publish');

      ref.read(quizListRefreshProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quiz saved successfully')));
        context.go('/quizzes');
      }
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      final message = detail is String ? detail : 'Failed to save quiz';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New quiz'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text('Create a quiz', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Add your topic, questions, and mark the correct answer for each.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          TextFormField(
            controller: _topicController,
            decoration: const InputDecoration(hintText: 'Topic', prefixIcon: Icon(Icons.topic_outlined, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 24),
          Text('Answers per question', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              _OptionCountChip(label: '4 options', selected: _optionCount == 4, onTap: () => _setOptionCount(4)),
              const SizedBox(width: 10),
              _OptionCountChip(label: '5 options', selected: _optionCount == 5, onTap: () => _setOptionCount(5)),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Questions', style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(onPressed: () => _addQuestion(scrollToNew: true), icon: const Icon(Icons.add, size: 18), label: const Text('Add question')),
            ],
          ),
          const SizedBox(height: 8),
          ..._questions.asMap().entries.map((entry) {
            final index = entry.key;
            final q = entry.value;
            return Padding(
              key: _questionKeys[index],
              padding: const EdgeInsets.only(bottom: 16),
              child: _QuestionEditor(
                index: index,
                draft: q,
                canRemove: _questions.length > 1,
                onRemove: () => _removeQuestion(index),
                onCorrectChanged: (i) => _handleCorrectSelected(index, i),
                onFieldsChanged: () => setState(() {}),
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(onPressed: _saving ? null : _save, child: const Text('Save quiz')),
          ),
        ],
      ),
    );
  }
}

class _OptionCountChip extends StatelessWidget {
  const _OptionCountChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? AppColors.borderStrong : AppColors.border, width: selected ? 2 : 1),
        ),
        child: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}

class _QuestionEditor extends StatelessWidget {
  const _QuestionEditor({
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onRemove,
    required this.onCorrectChanged,
    required this.onFieldsChanged,
  });

  final int index;
  final _QuestionDraft draft;
  final bool canRemove;
  final VoidCallback onRemove;
  final ValueChanged<int> onCorrectChanged;
  final VoidCallback onFieldsChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['A', 'B', 'C', 'D', 'E'];

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
              Text('Question ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              if (draft.isComplete && draft.correctAnswerConfirmed)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                ),
              const Spacer(),
              if (canRemove)
                IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary, size: 20)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: draft.questionController,
            decoration: const InputDecoration(hintText: 'Enter question'),
            maxLines: 2,
            onChanged: (_) => onFieldsChanged(),
          ),
          const SizedBox(height: 16),
          Text('Answers — tap letter to mark correct', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          ...List.generate(draft.optionCount, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => onCorrectChanged(i),
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: draft.correctIndex == i ? AppColors.black : AppColors.border, width: draft.correctIndex == i ? 2 : 1),
                        color: draft.correctIndex == i ? AppColors.black : AppColors.white,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: draft.correctIndex == i ? AppColors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: draft.optionControllers[i],
                      decoration: InputDecoration(hintText: 'Answer ${labels[i]}'),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class MyQuizzesScreen extends ConsumerStatefulWidget {
  const MyQuizzesScreen({super.key});

  @override
  ConsumerState<MyQuizzesScreen> createState() => _MyQuizzesScreenState();
}

class _MyQuizzesScreenState extends ConsumerState<MyQuizzesScreen> {
  List<dynamic> _quizzes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dio = ref.read(dioProvider);
    final res = await dio.get('/quizzes', queryParameters: {'mine': true});
    setState(() {
      _quizzes = res.data['items'] ?? [];
      _loading = false;
    });
  }

  Future<void> _publish(String id) async {
    final dio = ref.read(dioProvider);
    await dio.post('/quizzes/$id/publish');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Quizzes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _quizzes.length,
              itemBuilder: (context, i) {
                final q = _quizzes[i];
                final isDraft = q['status'] == 'draft';
                return ListTile(
                  title: Text(q['title'] ?? ''),
                  subtitle: Text('${q['status']} · ${q['total_marks']} marks'),
                  trailing: isDraft
                      ? TextButton(onPressed: () => _publish(q['id']), child: const Text('Publish'))
                      : IconButton(
                          icon: const Icon(Icons.leaderboard),
                          onPressed: () => context.push('/leaderboard/${q['id']}'),
                        ),
                  onTap: () => context.push('/quiz/edit/${q['id']}'),
                );
              },
            ),
    );
  }
}

class QuizEditorScreen extends ConsumerStatefulWidget {
  const QuizEditorScreen({super.key, required this.quizId});
  final String quizId;

  @override
  ConsumerState<QuizEditorScreen> createState() => _QuizEditorScreenState();
}

class _QuizEditorScreenState extends ConsumerState<QuizEditorScreen> {
  Map<String, dynamic>? _quiz;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dio = ref.read(dioProvider);
    final res = await dio.get('/quizzes/${widget.quizId}');
    setState(() {
      _quiz = Map<String, dynamic>.from(res.data);
      _loading = false;
    });
  }

  Future<void> _publish() async {
    final dio = ref.read(dioProvider);
    await dio.post('/quizzes/${widget.quizId}/publish');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quiz published!')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final questions = _quiz?['questions'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_quiz?['title'] ?? 'Edit Quiz'),
        actions: [
          if (_quiz?['status'] == 'draft')
            TextButton(onPressed: _publish, child: const Text('Publish', style: TextStyle(color: Colors.white))),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder: (context, i) {
          final q = questions[i];
          return Card(
            child: ListTile(
              title: Text('Q${i + 1}: ${q['question_text']}'),
              subtitle: Text('${q['type']} · ${q['marks']} marks'),
            ),
          );
        },
      ),
    );
  }
}

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key, required this.quizId});
  final String quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: FutureBuilder(
        future: ref.read(dioProvider).get('/quizzes/$quizId/leaderboard'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final entries = snapshot.data!.data as List;
          if (entries.isEmpty) return const Center(child: Text('No scores yet'));
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              return ListTile(
                leading: CircleAvatar(child: Text('#${e['rank']}')),
                title: Text(e['display_name'] ?? 'Student'),
                trailing: Text('${e['score']} pts', style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            },
          );
        },
      ),
    );
  }
}

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dio = ref.read(dioProvider);
    final res = await dio.get('/quizzes/favorites/list');
    setState(() {
      _items = res.data as List;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No favorites yet'))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final q = _items[i];
                    return ListTile(
                      title: Text(q['title'] ?? ''),
                      onTap: () => context.push('/quiz/${q['id']}'),
                    );
                  },
                ),
    );
  }
}

class ClassesScreen extends ConsumerStatefulWidget {
  const ClassesScreen({super.key});

  @override
  ConsumerState<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends ConsumerState<ClassesScreen> {
  List<dynamic> _classes = [];
  final _codeController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    final isTutor = user?['role'] == 'tutor';
    if (isTutor) {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/classes');
      setState(() {
        _classes = res.data as List;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _createClass() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('New Class'),
          content: TextField(controller: c, decoration: const InputDecoration(hintText: 'Class name')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Create')),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    final dio = ref.read(dioProvider);
    await dio.post('/classes', data: {'name': name});
    _load();
  }

  Future<void> _enroll() async {
    final dio = ref.read(dioProvider);
    await dio.post('/classes/enroll', data: {'enrollment_code': _codeController.text.trim()});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enrolled successfully!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTutor = ref.watch(authProvider).user?['role'] == 'tutor';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes'),
        actions: [
          if (isTutor) IconButton(icon: const Icon(Icons.add), onPressed: _createClass),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : isTutor
              ? ListView.builder(
                  itemCount: _classes.length,
                  itemBuilder: (context, i) {
                    final c = _classes[i];
                    return ListTile(
                      title: Text(c['name']),
                      subtitle: Text('Code: ${c['enrollment_code']}'),
                      onTap: () => context.push('/classes/${c['id']}/analytics'),
                    );
                  },
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      TextField(
                        controller: _codeController,
                        decoration: const InputDecoration(labelText: 'Enrollment Code'),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _enroll, child: const Text('Join Class')),
                    ],
                  ),
                ),
    );
  }
}

class ClassAnalyticsScreen extends ConsumerWidget {
  const ClassAnalyticsScreen({super.key, required this.classId});
  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Class Analytics')),
      body: FutureBuilder(
        future: ref.read(dioProvider).get('/classes/$classId/analytics'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text('${data['student_count']} students'),
                      Text('Avg score: ${data['avg_score']}'),
                      Text('${data['attempts_count']} attempts'),
                    ],
                  ),
                ),
              ),
              ...(data['students'] as List).map((s) => ListTile(
                    title: Text(s['display_name']),
                    subtitle: Text('${s['attempts']} attempts'),
                    trailing: Text('Avg: ${s['avg_score'].toStringAsFixed(1)}'),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  Map<String, dynamic>? _data;
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
      final res = await ref.read(dioProvider).get('/classes/me/analytics');
      if (mounted) {
        setState(() {
          _data = Map<String, dynamic>.from(res.data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load progress. Pull down to retry.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.black,
          onRefresh: _load,
          child: _loading
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: AppColors.black))),
                  ],
                )
              : _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text('Your progress', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 40),
                        Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary))),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Text('Your progress', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Column(
                            children: [
                              Text('${_data?['avg_percentage'] ?? 0}%', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                              const Text('Overall average', style: TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _statCard('Quizzes completed', '${_data?['total_attempts'] ?? 0}', Icons.check_circle_outline),
                        const SizedBox(height: 12),
                        _statCard('Average score', '${_data?['avg_score'] ?? 0}', Icons.star_outline),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        ],
      ),
    );
  }
}

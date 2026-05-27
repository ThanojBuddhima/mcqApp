import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class PastPapersScreen extends ConsumerStatefulWidget {
  const PastPapersScreen({super.key});

  @override
  ConsumerState<PastPapersScreen> createState() => _PastPapersScreenState();
}

class _PastPapersScreenState extends ConsumerState<PastPapersScreen> {
  List<dynamic> _papers = [];
  List<dynamic> _subjects = [];
  String? _grade;
  String? _subjectId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dio = ref.read(dioProvider);
    final subjects = await dio.get('/past-papers/subjects');
    final params = <String, dynamic>{};
    if (_grade != null) params['grade'] = _grade;
    if (_subjectId != null) params['subject_id'] = _subjectId;
    final papers = await dio.get('/past-papers', queryParameters: params);
    setState(() {
      _subjects = subjects.data;
      _papers = papers.data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Past Papers')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ...['6', '7', '8', '9', '10', '11', '12', '13'].map((g) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text('Grade $g'),
                        selected: _grade == g,
                        onSelected: (_) {
                          setState(() => _grade = _grade == g ? null : g);
                          _load();
                        },
                      ),
                    )),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _papers.length,
                    itemBuilder: (context, i) {
                      final p = _papers[i];
                      return ListTile(
                        title: Text(p['quiz_title'] ?? 'Past Paper'),
                        subtitle: Text('Grade ${p['grade']} · ${p['subject_name']} · ${p['year']} · ${p['medium']}'),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () => context.push('/quiz/${p['quiz_id']}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.white,
                    child: Text(
                      (user?['display_name'] as String?)?.substring(0, 1).toUpperCase() ?? 'S',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?['display_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                        Text(user?['email'] ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                        if (user?['grade'] != null) ...[
                          const SizedBox(height: 4),
                          Text('Grade ${user?['grade']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text('${user?['role']}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _profileMenu(context, Icons.favorite_border, 'Favorites', () => context.push('/favorites')),
            _profileMenu(context, Icons.groups_outlined, 'Classes', () => context.push('/classes')),
            _profileMenu(context, Icons.upload_file_outlined, 'Upload Paper', () => context.push('/upload')),
            _profileMenu(context, Icons.smart_toy_outlined, 'AI Assistant', () => context.push('/ai')),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                child: const Text('Sign Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _profileMenu(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: ListTile(
            leading: Icon(icon, color: AppColors.textPrimary),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _controller = TextEditingController();
  final _messages = <Map<String, String>>[];
  bool _loading = false;

  Future<void> _send() async {
    if (_controller.text.isEmpty) return;
    final text = _controller.text;
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _loading = true;
    });
    _controller.clear();
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/ai/chat', data: {
        'messages': _messages,
        'language': 'sinhala',
      });
      setState(() => _messages.add({'role': 'assistant', 'content': res.data['reply'] ?? ''}));
    } catch (e) {
      setState(() => _messages.add({'role': 'assistant', 'content': 'Error: $e'}));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Study Assistant')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final isUser = m['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.textPrimary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      m['content'] ?? '',
                      style: TextStyle(color: isUser ? AppColors.white : AppColors.textPrimary),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: 'Ask a question...'))),
                IconButton(onPressed: _send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final container = ProviderScope.containerOf(context);
              await container.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.dashboard_outlined, label: 'Overview', selected: navigationShell.currentIndex == 0, onTap: () => _onTap(0)),
                _NavItem(icon: Icons.people_outline, label: 'Users', selected: navigationShell.currentIndex == 1, onTap: () => _onTap(1)),
                _NavItem(icon: Icons.upload_file_outlined, label: 'Uploads', selected: navigationShell.currentIndex == 2, onTap: () => _onTap(2)),
                _NavItem(icon: Icons.timeline_outlined, label: 'Activity', selected: navigationShell.currentIndex == 3, onTap: () => _onTap(3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.black : AppColors.textTertiary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

class AdminOverviewScreen extends ConsumerStatefulWidget {
  const AdminOverviewScreen({super.key});

  @override
  ConsumerState<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends ConsumerState<AdminOverviewScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get('/admin/overview');
      if (mounted) setState(() => _data = Map<String, dynamic>.from(res.data));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.black));
    final stats = _data?['stats'] as Map<String, dynamic>? ?? {};
    final activity = _data?['recent_activity'] as List? ?? [];

    return RefreshIndicator(
      color: AppColors.black,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text('Platform overview', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _StatCard('Users', '${stats['total_users'] ?? 0}', '${stats['active_users'] ?? 0} active'),
              _StatCard('Quizzes', '${stats['total_quizzes'] ?? 0}', _formatMap(stats['quizzes_by_status'])),
              _StatCard('Attempts', '${stats['total_attempts'] ?? 0}', '${stats['submitted_attempts'] ?? 0} submitted'),
              _StatCard('Upload jobs', '${stats['total_document_jobs'] ?? 0}', _formatMap(stats['document_jobs_by_status'])),
              _StatCard('Classes', '${stats['total_classes'] ?? 0}', 'Tutor groups'),
              _StatCard('Past papers', '${stats['total_past_papers'] ?? 0}', 'Catalog items'),
            ],
          ),
          const SizedBox(height: 28),
          Text('Users by role', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _RoleBreakdown(stats['users_by_role'] as Map<String, dynamic>? ?? {}),
          const SizedBox(height: 28),
          Text('Recent activity', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (activity.isEmpty)
            const Text('No activity yet', style: TextStyle(color: AppColors.textSecondary))
          else
            ...activity.map((item) => _ActivityTile(item: Map<String, dynamic>.from(item))),
        ],
      ),
    );
  }

  String _formatMap(dynamic map) {
    if (map is! Map || map.isEmpty) return '—';
    return map.entries.map((e) => '${e.key}: ${e.value}').join(' · ');
  }
}

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  List<dynamic> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get('/admin/users');
      if (mounted) setState(() => _users = res.data['items'] ?? []);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleActive(String id, bool active) async {
    await ref.read(dioProvider).patch('/admin/users/$id', data: {'is_active': !active});
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.black));

    return RefreshIndicator(
      color: AppColors.black,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final u = _users[i];
          final active = u['is_active'] == true;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u['display_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(u['email'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text('${u['role']} · Grade ${u['grade'] ?? '—'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Switch(
                  value: active,
                  activeThumbColor: AppColors.black,
                  onChanged: (_) => _toggleActive(u['id'], active),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AdminJobsScreen extends ConsumerStatefulWidget {
  const AdminJobsScreen({super.key});

  @override
  ConsumerState<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends ConsumerState<AdminJobsScreen> {
  List<dynamic> _jobs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get('/admin/document-jobs');
      if (mounted) setState(() => _jobs = res.data as List? ?? []);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.black));

    return RefreshIndicator(
      color: AppColors.black,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _jobs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final j = _jobs[i];
          final failed = j['status'] == 'failed';
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: failed ? AppColors.error : AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(j['source_filename'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${j['user_name']} · ${j['user_email']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatusChip(j['status'] ?? ''),
                    const Spacer(),
                    Text('${j['progress_percent'] ?? 0}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                if (j['error_log'] != null) ...[
                  const SizedBox(height: 8),
                  Text(j['error_log'], style: const TextStyle(color: AppColors.error, fontSize: 12)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class AdminActivityScreen extends ConsumerStatefulWidget {
  const AdminActivityScreen({super.key});

  @override
  ConsumerState<AdminActivityScreen> createState() => _AdminActivityScreenState();
}

class _AdminActivityScreenState extends ConsumerState<AdminActivityScreen> {
  List<dynamic> _attempts = [];
  List<dynamic> _quizzes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final attempts = await dio.get('/admin/attempts');
      final quizzes = await dio.get('/admin/quizzes');
      if (mounted) {
        setState(() {
          _attempts = attempts.data as List? ?? [];
          _quizzes = quizzes.data as List? ?? [];
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.black));

    return RefreshIndicator(
      color: AppColors.black,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text('Quiz attempts', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_attempts.isEmpty)
            const Text('No attempts yet', style: TextStyle(color: AppColors.textSecondary))
          else
            ..._attempts.take(20).map((a) => _AttemptTile(attempt: a)),
          const SizedBox(height: 28),
          Text('All quizzes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_quizzes.isEmpty)
            const Text('No quizzes yet', style: TextStyle(color: AppColors.textSecondary))
          else
            ..._quizzes.take(20).map((q) => _QuizTile(quiz: q)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.subtitle);
  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _RoleBreakdown extends StatelessWidget {
  const _RoleBreakdown(this.roles);
  final Map<String, dynamic> roles;

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) return const Text('No users', style: TextStyle(color: AppColors.textSecondary));
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: roles.entries
          .map((e) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text('${e.key}: ${e.value}', style: const TextStyle(fontWeight: FontWeight.w500)),
              ))
          .toList(),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
            child: Icon(_iconForType(item['type']), size: 20, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(item['subtitle'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (item['status'] != null) _StatusChip(item['status']),
        ],
      ),
    );
  }

  IconData _iconForType(String? type) {
    return switch (type) {
      'user_registered' => Icons.person_add_outlined,
      'quiz_attempt' => Icons.quiz_outlined,
      'document_upload' => Icons.upload_file_outlined,
      'quiz_created' => Icons.note_add_outlined,
      _ => Icons.circle_outlined,
    };
  }
}

class _AttemptTile extends StatelessWidget {
  const _AttemptTile({required this.attempt});
  final dynamic attempt;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(attempt['quiz_title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${attempt['user_name']} · ${attempt['status']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text('${attempt['score'] ?? 0}/${attempt['total_marks'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _QuizTile extends StatelessWidget {
  const _QuizTile({required this.quiz});
  final dynamic quiz;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quiz['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${quiz['creator_name']} · ${quiz['status']} · ${quiz['total_marks']} marks',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final isFailed = status == 'failed';
    final isCompleted = status == 'completed' || status == 'submitted' || status == 'published';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isFailed ? AppColors.error.withValues(alpha: 0.1) : (isCompleted ? AppColors.success.withValues(alpha: 0.1) : AppColors.surface),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isFailed ? AppColors.error : (isCompleted ? AppColors.success : AppColors.textPrimary),
        ),
      ),
    );
  }
}

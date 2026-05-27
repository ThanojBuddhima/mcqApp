import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../auth/providers/auth_provider.dart';
import '../../quiz/quiz_subjects.dart';

const _storageKey = 'visible_levels';

class VisibleLevels {
  const VisibleLevels({this.ol = false, this.al = false});

  final bool ol;
  final bool al;

  bool get isValid => ol || al;

  bool get hasBoth => ol && al;

  String? get singleLevel {
    if (ol && !al) return QuizSubjects.ol;
    if (al && !ol) return QuizSubjects.al;
    return null;
  }

  Set<String> get levelSet => {if (ol) QuizSubjects.ol, if (al) QuizSubjects.al};

  String get label {
    if (ol && al) return 'O/L & A/L';
    if (ol) return 'O/L';
    if (al) return 'A/L';
    return 'None';
  }

  VisibleLevels copyWith({bool? ol, bool? al}) => VisibleLevels(ol: ol ?? this.ol, al: al ?? this.al);

  VisibleLevels toggle(String level) {
    if (level == QuizSubjects.ol) {
      final next = copyWith(ol: !ol);
      return next.isValid ? next : this;
    }
    if (level == QuizSubjects.al) {
      final next = copyWith(al: !al);
      return next.isValid ? next : this;
    }
    return this;
  }

  static VisibleLevels fromUserGrade(String? grade) {
    if (grade == 'A/L') return const VisibleLevels(al: true);
    return const VisibleLevels(ol: true);
  }

  static VisibleLevels fromStorage(String? raw) {
    if (raw == null || raw.isEmpty) return const VisibleLevels(ol: true);
    if (raw == QuizSubjects.ol) return const VisibleLevels(ol: true);
    if (raw == QuizSubjects.al) return const VisibleLevels(al: true);
    final parts = raw.split(',');
    return VisibleLevels(
      ol: parts.contains(QuizSubjects.ol),
      al: parts.contains(QuizSubjects.al),
    );
  }

  String toStorage() => levelSet.join(',');

  @override
  bool operator ==(Object other) => other is VisibleLevels && other.ol == ol && other.al == al;

  @override
  int get hashCode => Object.hash(ol, al);
}

class VisibleLevelNotifier extends StateNotifier<VisibleLevels> {
  VisibleLevelNotifier(this._ref) : super(const VisibleLevels(ol: true)) {
    _load();
  }

  final Ref _ref;
  static const _storage = FlutterSecureStorage();

  Future<void> _load() async {
    final stored = await _storage.read(key: _storageKey);
    if (stored != null && stored.isNotEmpty) {
      state = VisibleLevels.fromStorage(stored);
      return;
    }
    _applyUserGradeDefault();
  }

  void _applyUserGradeDefault() {
    final grade = _ref.read(authProvider).user?['grade'] as String?;
    state = VisibleLevels.fromUserGrade(grade);
  }

  Future<void> applyDefaultIfUnset() async {
    final stored = await _storage.read(key: _storageKey);
    if (stored != null && stored.isNotEmpty) return;
    _applyUserGradeDefault();
  }

  Future<void> applyLevels(VisibleLevels levels) async {
    if (!levels.isValid) return;
    state = levels;
    await _storage.write(key: _storageKey, value: levels.toStorage());
  }

  Future<void> syncWithUserGrade() async {
    await _storage.delete(key: _storageKey);
    _applyUserGradeDefault();
  }

  Future<void> clear() async {
    await _storage.delete(key: _storageKey);
    state = const VisibleLevels(ol: true);
  }
}

final visibleLevelProvider = StateNotifierProvider<VisibleLevelNotifier, VisibleLevels>((ref) {
  final notifier = VisibleLevelNotifier(ref);

  ref.listen<AuthState>(authProvider, (prev, next) {
    if (prev?.user != null && next.user == null) {
      notifier.clear();
    } else if (prev?.user == null && next.user != null) {
      notifier.applyDefaultIfUnset();
    } else if (prev?.user?['grade'] != next.user?['grade'] && next.user != null) {
      notifier.syncWithUserGrade();
    }
  });

  return notifier;
});

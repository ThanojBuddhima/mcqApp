import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class QuizSubjects {
  static const ol = 'ol';
  static const al = 'al';

  static const alSubjects = ['physics', 'chemistry', 'biology'];
  static const olSubjects = ['science', 'maths'];

  static const courseFilters = ['All', 'Physics', 'Chemistry', 'Biology', 'Science', 'Maths'];

  /// Maps registration grade (6–9, O/L, A/L) to quiz track level.
  static String levelForUserGrade(String? grade) {
    if (grade == 'A/L') return al;
    return ol;
  }

  static List<String> courseFiltersForLevel(String level) {
    return ['All', ...subjectsForLevel(level).map(subjectLabel)];
  }

  static List<String> courseFiltersForLevels(Set<String> levels) {
    if (levels.contains(al) && levels.contains(ol)) return courseFilters;
    if (levels.contains(al)) return courseFiltersForLevel(al);
    return courseFiltersForLevel(ol);
  }

  static String? quizLevel(Map<String, dynamic>? metadata) {
    return (metadata?['level'] as String?)?.toLowerCase();
  }

  static bool matchesLevel(Map<String, dynamic>? metadata, String level) {
    final quizLevel = (metadata?['level'] as String?)?.toLowerCase();
    if (quizLevel == null) return level == ol;
    return quizLevel == level;
  }

  static bool matchesLevels(Map<String, dynamic>? metadata, Set<String> levels) {
    if (levels.isEmpty) return true;
    final quizLevel = (metadata?['level'] as String?)?.toLowerCase();
    if (quizLevel == null) return levels.contains(ol);
    return levels.contains(quizLevel);
  }

  static String levelLabel(String? level) {
    return switch (level) {
      ol => 'O/L',
      al => 'A/L',
      _ => '',
    };
  }

  static List<String> subjectsForLevel(String? level) {
    return switch (level) {
      al => alSubjects,
      ol => olSubjects,
      _ => const [],
    };
  }

  static String subjectLabel(String? subject) {
    return switch (subject) {
      'physics' => 'Physics',
      'chemistry' => 'Chemistry',
      'biology' => 'Biology',
      'science' => 'Science',
      'maths' => 'Maths',
      _ => subject ?? '',
    };
  }

  static IconData subjectIcon(String? subject) {
    return switch (subject) {
      'physics' => Icons.science_outlined,
      'chemistry' => Icons.water_drop_outlined,
      'biology' => Icons.biotech_outlined,
      'maths' => Icons.calculate_outlined,
      'science' => Icons.science_outlined,
      _ => Icons.quiz_outlined,
    };
  }

  static Color subjectColor(String? subject) {
    return switch (subject) {
      'physics' => AppColors.alPhysicsBlue,
      'chemistry' => AppColors.alChemistryYellow,
      'biology' => AppColors.alBiologyGreen,
      'maths' => AppColors.olMathsBlue,
      'science' => AppColors.olScienceGreen,
      _ => AppColors.textPrimary,
    };
  }

  static Color subjectSurface(String? subject) => subjectColor(subject).withValues(alpha: 0.14);

  static Color? colorForFilter(String filter) {
    final key = filterKey(filter);
    if (key == null) return null;
    return subjectColor(key);
  }

  static String? filterKey(String filter) {
    if (filter == 'All') return null;
    return switch (filter) {
      'Physics' => 'physics',
      'Chemistry' => 'chemistry',
      'Biology' => 'biology',
      'Science' => 'science',
      'Maths' => 'maths',
      _ => filter.toLowerCase(),
    };
  }

  static bool matchesFilter(Map<String, dynamic>? metadata, String filter) {
    final key = filterKey(filter);
    if (key == null) return true;
    final subject = (metadata?['subject'] as String?)?.toLowerCase();
    return subject == key;
  }
}

class SubjectIcon extends StatelessWidget {
  const SubjectIcon({
    super.key,
    required this.subjectKey,
    this.size = 48,
    this.iconSize = 24,
    this.radius = 14,
  });

  final String? subjectKey;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = QuizSubjects.subjectColor(subjectKey);
    final surface = QuizSubjects.subjectSurface(subjectKey);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: subjectKey != null ? surface : AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        QuizSubjects.subjectIcon(subjectKey),
        color: subjectKey != null ? color : AppColors.textPrimary,
        size: iconSize,
      ),
    );
  }
}

class SubjectChip extends StatelessWidget {
  const SubjectChip({
    super.key,
    required this.label,
    required this.subjectKey,
    this.selected = false,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final String? subjectKey;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = QuizSubjects.subjectColor(subjectKey);
    final bg = selected ? color : QuizSubjects.subjectSurface(subjectKey);
    final border = selected ? color : color.withValues(alpha: 0.35);
    final textColor = selected
        ? (subjectKey == 'chemistry' ? AppColors.textPrimary : AppColors.white)
        : color;

    final child = Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: compact ? 6 : 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: border, width: selected ? 2 : 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 12 : 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          color: textColor,
        ),
      ),
    );

    if (onTap == null) return child;
    return GestureDetector(onTap: onTap, child: child);
  }
}

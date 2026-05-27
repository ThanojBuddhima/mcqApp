import 'package:flutter/material.dart';

class GradeCategory {
  const GradeCategory(this.title, this.subtitle, this.icon);

  final String title;
  final String subtitle;
  final IconData icon;
}

class GradeCategories {
  static List<GradeCategory> forLevel(String level) {
    if (level == 'al') {
      return const [
        GradeCategory('Physics', 'A/L papers', Icons.science_outlined),
        GradeCategory('Chemistry', 'A/L papers', Icons.water_drop_outlined),
        GradeCategory('Biology', 'A/L papers', Icons.biotech_outlined),
      ];
    }
    return const [
      GradeCategory('Maths', 'Practice quizzes', Icons.calculate_outlined),
      GradeCategory('Science', 'Practice quizzes', Icons.science_outlined),
    ];
  }

  static List<GradeCategory> forLevels(Set<String> levels) {
    if (levels.contains('al') && levels.contains('ol')) {
      return [...forLevel('ol'), ...forLevel('al')];
    }
    if (levels.contains('al')) return forLevel('al');
    return forLevel('ol');
  }

  static List<GradeCategory> forGrade(String? grade) {
    return forLevel(grade == 'A/L' ? 'al' : 'ol');
  }
}

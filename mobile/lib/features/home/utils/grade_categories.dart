import 'package:flutter/material.dart';

class GradeCategory {
  const GradeCategory(this.title, this.subtitle, this.icon);

  final String title;
  final String subtitle;
  final IconData icon;
}

class GradeCategories {
  static const _juniorGrades = {'6', '7', '8', '9', 'O/L'};

  static List<GradeCategory> forGrade(String? grade) {
    if (grade == 'A/L') {
      return const [
        GradeCategory('Physics', 'A/L papers', Icons.science_outlined),
        GradeCategory('Chemistry', 'A/L papers', Icons.water_drop_outlined),
        GradeCategory('Biology', 'A/L papers', Icons.biotech_outlined),
      ];
    }
    if (grade != null && _juniorGrades.contains(grade)) {
      return const [
        GradeCategory('Maths', 'Practice quizzes', Icons.calculate_outlined),
        GradeCategory('Science', 'Practice quizzes', Icons.science_outlined),
      ];
    }
    return const [
      GradeCategory('Maths', 'Practice quizzes', Icons.calculate_outlined),
      GradeCategory('Science', 'Practice quizzes', Icons.science_outlined),
    ];
  }
}

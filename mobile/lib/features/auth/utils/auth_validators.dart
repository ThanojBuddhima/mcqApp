class AuthValidators {
  static const grades = ['6', '7', '8', '9', 'O/L', 'A/L'];

  static String? name(String? value) {
    if (value == null || value.trim().length < 2) {
      return 'Enter your full name';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your email';
    }
    final email = value.trim();
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter a password';
    }
    if (value.length < 8) {
      return 'At least 8 characters';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Include a lowercase letter';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Include an uppercase letter';
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Include a number';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/]').hasMatch(value)) {
      return 'Include a special character';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? grade(String? value) {
    if (value == null || !grades.contains(value)) {
      return 'Select your grade';
    }
    return null;
  }
}

abstract final class AuthInputValidator {
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp _letterPattern = RegExp('[A-Za-z]');
  static final RegExp _numberPattern = RegExp('[0-9]');

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Enter your email address.';
    }
    if (!_emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? signInPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter your password.';
    }
    return null;
  }

  static String? registrationPassword(String? value) {
    final password = value ?? '';
    if (password.length < 6 ||
        !_letterPattern.hasMatch(password) ||
        !_numberPattern.hasMatch(password)) {
      return 'Use at least 6 characters with a letter and a number.';
    }
    return null;
  }

  static String? confirmation(String? value, String password) {
    if (value != password) {
      return 'Passwords do not match.';
    }
    return null;
  }
}

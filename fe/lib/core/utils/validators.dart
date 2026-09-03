class Validators {
  Validators._();

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim()))
      return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!value.contains(RegExp(r'[0-9]')))
      return 'Password must contain at least 1 number';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != password) return 'Passwords do not match';
    return null;
  }

  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Full name is required';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  static String? yearOfBirth(String? value) {
    if (value == null || value.trim().isEmpty)
      return 'Year of birth is required';
    final year = int.tryParse(value.trim());
    if (year == null) return 'Enter a valid year';
    final currentYear = DateTime.now().year;
    if (year < 1900 || year > currentYear)
      return 'Enter a year between 1900 and $currentYear';
    if (currentYear - year < 13) return 'You must be at least 13 years old';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty)
      return 'Phone number is required';
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) return 'Enter a valid phone number';
    return null;
  }

  static String? height(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final h = double.tryParse(value.trim());
    if (h == null) return 'Enter a valid height';
    if (h < 50 || h > 300) return 'Height must be between 50 and 300 cm';
    return null;
  }

  static String? weight(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final w = double.tryParse(value.trim());
    if (w == null) return 'Enter a valid weight';
    if (w < 1 || w > 500) return 'Weight must be between 1 and 500 kg';
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter the OTP';
    if (value.trim().length < 6) return 'Enter the complete 6-digit code';
    return null;
  }
}

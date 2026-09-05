class UserModel {
  final String id;
  final String? email;
  final String? phoneNumber;
  final String? fullName;
  final bool? onboardingComplete;

  const UserModel({
    required this.id,
    this.email,
    this.phoneNumber,
    this.fullName,
    this.onboardingComplete,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String?,
      fullName: json['full_name'] as String?,
      onboardingComplete: json['onboarding_complete'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone_number': phoneNumber,
      'full_name': fullName,
      'onboarding_complete': onboardingComplete,
    };
  }
}

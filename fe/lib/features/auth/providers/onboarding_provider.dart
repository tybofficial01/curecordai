import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingData {
  OnboardingData({
    this.fullName,
    this.yearOfBirth,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.bloodGroup,
    this.allergies,
    this.existingConditions = const [],
  });

  final String? fullName;
  final int? yearOfBirth;
  final String? gender;
  final double? heightCm;
  final double? weightKg;
  final String? bloodGroup;
  final String? allergies;
  final List<String> existingConditions;

  OnboardingData copyWith({
    String? fullName,
    int? yearOfBirth,
    String? gender,
    double? heightCm,
    double? weightKg,
    String? bloodGroup,
    String? allergies,
    List<String>? existingConditions,
  }) =>
      OnboardingData(
        fullName: fullName ?? this.fullName,
        yearOfBirth: yearOfBirth ?? this.yearOfBirth,
        gender: gender ?? this.gender,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        bloodGroup: bloodGroup ?? this.bloodGroup,
        allergies: allergies ?? this.allergies,
        existingConditions: existingConditions ?? this.existingConditions,
      );
}

class OnboardingNotifier extends StateNotifier<OnboardingData> {
  OnboardingNotifier() : super(OnboardingData());

  void prefillName(String fullName) {
    state = state.copyWith(fullName: fullName);
  }

  void updateStep1({
    required String fullName,
    required int yearOfBirth,
    required String gender,
  }) {
    state = state.copyWith(
      fullName: fullName,
      yearOfBirth: yearOfBirth,
      gender: gender,
    );
  }

  void updateStep2({
    double? heightCm,
    double? weightKg,
    String? bloodGroup,
  }) {
    state = state.copyWith(
      heightCm: heightCm,
      weightKg: weightKg,
      bloodGroup: bloodGroup,
    );
  }

  void updateStep3({
    String? allergies,
    List<String>? existingConditions,
  }) {
    state = state.copyWith(
      allergies: allergies,
      existingConditions: existingConditions,
    );
  }
}

final onboardingDataProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingData>(
  (ref) => OnboardingNotifier(),
);

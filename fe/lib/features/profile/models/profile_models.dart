class FullProfileResponse {
  final String? id;
  final String? fullName;
  final String? dateOfBirth;
  final String? gender;
  final String? phoneNumber;
  final String? email;
  final String? patientId;
  final String? profilePhotoUrl;
  final double? heightCm;
  final double? weightKg;
  final String? bloodGroup;
  final String? allergies;
  final List<String> conditions;
  final int completionPct;

  const FullProfileResponse({
    this.id,
    this.fullName,
    this.dateOfBirth,
    this.gender,
    this.phoneNumber,
    this.email,
    this.patientId,
    this.profilePhotoUrl,
    this.heightCm,
    this.weightKg,
    this.bloodGroup,
    this.allergies,
    this.conditions = const [],
    this.completionPct = 0,
  });

  factory FullProfileResponse.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? json;
    return FullProfileResponse(
      id: json['id'] as String?,
      fullName: profile['full_name'] as String?,
      dateOfBirth: profile['date_of_birth'] as String?,
      gender: profile['gender'] as String?,
      phoneNumber: json['phone_number'] as String?,
      email: json['email'] as String?,
      patientId: profile['patient_id_display'] as String?,
      profilePhotoUrl: profile['profile_photo_url'] as String?,
      heightCm: (profile['height_cm'] as num?)?.toDouble(),
      weightKg: (profile['weight_kg'] as num?)?.toDouble(),
      bloodGroup: profile['blood_group'] as String?,
      allergies: profile['allergies'] as String?,
      conditions: (profile['conditions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      completionPct: (profile['profile_completion_pct'] as int?) ?? 0,
    );
  }

  FullProfileResponse copyWith({
    String? fullName,
    String? dateOfBirth,
    String? gender,
    String? phoneNumber,
    String? profilePhotoUrl,
    double? heightCm,
    double? weightKg,
    String? bloodGroup,
    String? allergies,
    List<String>? conditions,
    int? completionPct,
  }) {
    return FullProfileResponse(
      id: id,
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email,
      patientId: patientId,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      conditions: conditions ?? this.conditions,
      completionPct: completionPct ?? this.completionPct,
    );
  }
}

class PreferencesSchema {
  /// One of `'en'` | `'ur'` | `'roman_ur'` - kept as a raw string (rather
  /// than an enum) because it's synced verbatim to the backend's
  /// `AppSetting.language` column, which accepts exactly these 3 values.
  /// Roman Urdu has no matching `Locale`/ISO code, so UI string selection is
  /// driven off this value directly via `appLocalizationsProvider`
  /// (see core/l10n/app_localizations_provider.dart) rather than `Locale`.
  final String language;
  final bool isDarkTheme;
  const PreferencesSchema({this.language = 'en', this.isDarkTheme = false});
  factory PreferencesSchema.fromJson(Map<String, dynamic> json) =>
      PreferencesSchema(
        language: json['language'] as String? ?? 'en',
        isDarkTheme: json['is_dark_theme'] as bool? ?? false,
      );
  Map<String, dynamic> toJson() => {
        'language': language,
        'is_dark_theme': isDarkTheme,
      };
  PreferencesSchema copyWith({String? language, bool? isDarkTheme}) =>
      PreferencesSchema(
        language: language ?? this.language,
        isDarkTheme: isDarkTheme ?? this.isDarkTheme,
      );
}

class PrivacySchema {
  final bool biometricLock;
  final bool appLockOnBackground;
  final bool screenshotPrevention;
  const PrivacySchema({
    this.biometricLock = false,
    this.appLockOnBackground = false,
    this.screenshotPrevention = false,
  });
  factory PrivacySchema.fromJson(Map<String, dynamic> json) => PrivacySchema(
        biometricLock: json['biometric_lock'] as bool? ?? false,
        appLockOnBackground: json['app_lock_on_background'] as bool? ?? false,
        screenshotPrevention: json['screenshot_prevention'] as bool? ?? false,
      );
  Map<String, dynamic> toJson() => {
        'biometric_lock': biometricLock,
        'app_lock_on_background': appLockOnBackground,
        'screenshot_prevention': screenshotPrevention,
      };
  PrivacySchema copyWith({
    bool? biometricLock,
    bool? appLockOnBackground,
    bool? screenshotPrevention,
  }) =>
      PrivacySchema(
        biometricLock: biometricLock ?? this.biometricLock,
        appLockOnBackground: appLockOnBackground ?? this.appLockOnBackground,
        screenshotPrevention: screenshotPrevention ?? this.screenshotPrevention,
      );
}

class DataSharingSchema {
  final String id;
  final String name;
  final String accessType;
  final String? grantedUntil;
  const DataSharingSchema({
    required this.id,
    required this.name,
    required this.accessType,
    this.grantedUntil,
  });
  factory DataSharingSchema.fromJson(Map<String, dynamic> json) =>
      DataSharingSchema(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        accessType: json['access_type'] as String? ?? 'read',
        grantedUntil: json['granted_until'] as String?,
      );
  Map<String, dynamic> toJson() => {
        'name': name,
        'access_type': accessType,
        if (grantedUntil != null) 'granted_until': grantedUntil,
      };
}

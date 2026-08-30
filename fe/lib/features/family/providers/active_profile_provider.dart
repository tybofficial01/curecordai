import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActiveProfile {
  const ActiveProfile({
    this.isOwnerMode = true,
    this.memberId,
    this.memberName,
    this.memberRelationship,
    this.memberPhotoUrl,
  });

  final bool isOwnerMode;
  final String? memberId;
  final String? memberName;
  final String? memberRelationship;
  final String? memberPhotoUrl;

  String get displayName => memberName ?? 'Member';
  String get initial =>
      (memberName?.isNotEmpty == true) ? memberName![0].toUpperCase() : '?';

  ActiveProfile copyWith({
    bool? isOwnerMode,
    String? memberId,
    String? memberName,
    String? memberRelationship,
    String? memberPhotoUrl,
  }) =>
      ActiveProfile(
        isOwnerMode: isOwnerMode ?? this.isOwnerMode,
        memberId: memberId ?? this.memberId,
        memberName: memberName ?? this.memberName,
        memberRelationship: memberRelationship ?? this.memberRelationship,
        memberPhotoUrl: memberPhotoUrl ?? this.memberPhotoUrl,
      );
}

class ActiveProfileNotifier extends StateNotifier<ActiveProfile> {
  ActiveProfileNotifier() : super(const ActiveProfile());

  void switchToMember(Map<String, dynamic> member) {
    state = ActiveProfile(
      isOwnerMode: false,
      memberId: member['id']?.toString(),
      memberName: member['full_name'] as String?,
      memberRelationship: member['relationship'] as String?,
      memberPhotoUrl: member['photo_url'] as String?,
    );
  }

  void switchToOwner() {
    state = const ActiveProfile();
  }
}

final activeProfileProvider =
    StateNotifierProvider<ActiveProfileNotifier, ActiveProfile>(
  (ref) => ActiveProfileNotifier(),
);

/// Convenience provider - returns the active family_member_id, or null in owner mode.
final activeMemberIdProvider = Provider<String?>((ref) {
  final profile = ref.watch(activeProfileProvider);
  return profile.isOwnerMode ? null : profile.memberId;
});

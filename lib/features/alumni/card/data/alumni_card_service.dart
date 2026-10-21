import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/features/alumni/card/data/alumni_card_cache.dart';
import 'package:alumni_system/features/alumni/card/models/alumni_card_data.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';

/// Loads roster + profile photo for the signed-in alumnus's digital card.
class AlumniCardService {
  AlumniCardService({
    AlumniMemberService? members,
    UserProfileService? profiles,
    AlumniCardCache? cache,
  }) : _membersOrNull = members,
       _profilesOrNull = profiles,
       _cache = cache ?? AlumniCardCache();

  AlumniMemberService? _membersOrNull;
  UserProfileService? _profilesOrNull;
  final AlumniCardCache _cache;

  AlumniMemberService get _members => _membersOrNull ??= AlumniMemberService();
  UserProfileService get _profiles => _profilesOrNull ??= UserProfileService();

  Future<AlumniCardLoadResult> loadForCurrentUser() async {
    final uid = AppSession.userId?.trim() ?? '';
    if (uid.isEmpty) return const AlumniCardLoadResult.unmatched();

    try {
      final member = await _members.findByAuthUid(uid);
      if (member == null) {
        await _cache.clear(uid);
        return const AlumniCardLoadResult.unmatched();
      }
      if (member.isDeactivated) {
        await _cache.clear(uid);
        return const AlumniCardLoadResult.deactivated();
      }

      // Sex/gender is stored on users (tracer/profile); roster may lag.
      final bootstrap = await _profiles.getOnboardingBootstrap(uid: uid);
      final fromUser = bootstrap.imageUrl;
      final photo = (fromUser != null && fromUser.isNotEmpty)
          ? fromUser
          : member.profileImageUrl;
      final data = AlumniCardData.fromMember(
        member,
        profileImageUrl: photo,
        sex: bootstrap.profile?.gender,
      );
      await _cache.save(uid, data);
      return AlumniCardLoadResult.ready(data);
    } catch (_) {
      final cached = await _cache.load(uid);
      if (cached != null) {
        return AlumniCardLoadResult.ready(cached, offline: true);
      }
      return const AlumniCardLoadResult.unmatched();
    }
  }
}

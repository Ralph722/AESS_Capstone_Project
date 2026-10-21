import 'package:intl/intl.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';

/// Field keys used in `PROFILE_UPDATE` audit diffs (`changes.fields`).
/// The admin member-detail timeline and the demographics "changed" markers
/// key off these names, so keep them stable.
const profileFieldLabels = <String, String>{
  'displayName': 'Name',
  'address': 'Permanent address',
  'email': 'E-mail address',
  'telephoneNumber': 'Telephone number',
  'mobileNumber': 'Mobile number',
  'civilStatus': 'Civil status',
  'gender': 'Sex',
  'birthDate': 'Birthday',
  'regionOfOrigin': 'Region of origin',
  'province': 'Province',
  'locationOfResidence': 'Location of residence',
  'program': 'Degree & specialization',
  'collegeUniversity': 'College or university',
  'yearGraduated': 'Year graduated',
  'honorsAwards': 'Honors or awards',
  'employmentStatus': 'Employment status',
  'photo': 'Profile photo',
};

/// Where a profile change came from (`changes.source`).
const profileChangeSourceLabels = <String, String>{
  'profile': 'Profile',
  'tracer': 'Tracer',
  'survey': 'Survey',
  'onboarding': 'Onboarding',
  'admin': 'Admin',
};

String profileChangeSourceLabel(String? source) =>
    profileChangeSourceLabels[source] ?? 'Profile';

final _birthDateFormat = DateFormat.yMMMd();

String _text(String value) => value.trim();

String _date(DateTime? value) =>
    value == null ? '' : _birthDateFormat.format(value);

/// Labelled old → new values for every tracer-profile field that differs
/// between [before] and [after]. Empty when nothing changed, so callers can
/// skip writing an audit row. Values are display strings (never secrets);
/// the photo is tracked separately as a changed marker, not data.
Map<String, dynamic> tracerProfileFieldDiff(
  TracerProfile before,
  TracerProfile after,
) {
  final values = <String, (String, String)>{
    'displayName': (_text(before.displayName), _text(after.displayName)),
    'address': (_text(before.address), _text(after.address)),
    'email': (_text(before.email), _text(after.email)),
    'telephoneNumber': (
      _text(before.telephoneNumber),
      _text(after.telephoneNumber),
    ),
    'mobileNumber': (_text(before.mobileNumber), _text(after.mobileNumber)),
    'civilStatus': (_text(before.civilStatus), _text(after.civilStatus)),
    'gender': (_text(before.gender), _text(after.gender)),
    'birthDate': (_date(before.birthDate), _date(after.birthDate)),
    'regionOfOrigin': (
      _text(before.regionOfOrigin),
      _text(after.regionOfOrigin),
    ),
    'province': (_text(before.province), _text(after.province)),
    'locationOfResidence': (
      _text(before.locationOfResidence),
      _text(after.locationOfResidence),
    ),
    'program': (_text(before.program), _text(after.program)),
    'collegeUniversity': (
      _text(before.collegeUniversity),
      _text(after.collegeUniversity),
    ),
    'yearGraduated': (_text(before.yearGraduated), _text(after.yearGraduated)),
    'honorsAwards': (_text(before.honorsAwards), _text(after.honorsAwards)),
    'employmentStatus': (
      _text(before.employmentStatus),
      _text(after.employmentStatus),
    ),
  };

  return {
    for (final entry in values.entries)
      if (entry.value.$1 != entry.value.$2)
        entry.key: {'from': entry.value.$1, 'to': entry.value.$2},
  };
}

/// Audit `changes` payload for a profile-photo replacement. Carries no
/// image data — the timeline renders it as a simple "changed" marker.
Map<String, dynamic> profilePhotoChange(String source) => {
  'source': source,
  'fields': {
    'photo': {'from': '', 'to': ''},
  },
};

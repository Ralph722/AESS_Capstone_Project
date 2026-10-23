/// Official CHED Graduate Tracer Study (GTS) field labels and option values.
class GtsConstants {
  GtsConstants._();

  static const defaultCollegeUniversity =
      'University of Science and Technology of Southern Philippines — Oroquieta Campus';

  // —— Section A labels ——
  static const labelName = 'Name';
  static const labelPermanentAddress = 'Permanent Address';
  static const labelEmail = 'E-mail Address';
  static const labelTelephone = 'Telephone or Contact Number(s)';
  static const labelMobile = 'Mobile Number';
  static const labelCivilStatus = 'Civil Status';
  static const labelSex = 'Sex';
  static const labelBirthday = 'Birthday';
  static const labelRegionOfOrigin = 'Region of Origin';
  static const labelProvince = 'Province';
  static const labelLocationOfResidence = 'Location of Residence';

  // —— Section B item 12 labels ——
  static const labelDegreeSpecialization = 'Degree(s) & Specialization(s)';
  static const labelCollegeUniversity = 'College or University';
  static const labelYearGraduated = 'Year Graduated';
  static const labelHonorsAwards = 'Honor(s) or Award(s) Received';

  // —— Employment status (onboarding / profile) ——
  static const labelEmploymentStatus = 'Employment Status';
  static const labelEmploymentType = 'Type of Employment';
  static const labelOccupation = 'Present Occupation';
  static const labelNotEmployedReasons = 'Reason(s) Not Yet Employed';

  static const employed = 'Employed';
  static const unemployed = 'Unemployed';
  static const neverEmployed = 'Never employed';

  static const List<String> employmentStatuses = [
    employed,
    unemployed,
    neverEmployed,
  ];

  /// CHED GTS Q18 options
  static const List<String> employmentTypes = [
    'Regular or Permanent',
    'Temporary',
    'Casual',
    'Contractual',
    'Self-employed',
  ];

  static const String otherReasonSpecify = 'Other reason(s), please specify';

  /// CHED GTS Q17 options
  static const List<String> notEmployedReasonOptions = [
    'Advance or further study',
    'Family concern and decided not to find a job',
    'Health-related reason(s)',
    'Lack of work experience',
    'No job opportunity',
    'Did not look for a job',
    otherReasonSpecify,
  ];

  static const List<String> civilStatuses = [
    'Single',
    'Married',
    'Separated',
    'Single Parent',
    'Widow or Widower',
  ];

  static const List<String> sexOptions = [
    'Male',
    'Female',
  ];

  static const List<String> regionsOfOrigin = [
    'Region 1',
    'Region 2',
    'Region 3',
    'Region 4',
    'Region 5',
    'Region 6',
    'Region 7',
    'Region 8',
    'Region 9',
    'Region 10',
    'Region 11',
    'Region 12',
    'NCR',
    'CAR',
    'ARMM',
    'CARAGA',
  ];

  static const List<String> locationOfResidenceOptions = [
    'City',
    'Municipality',
  ];

  /// Maps profile employment status to CHED item 16 answer.
  static String? toChedPresentlyEmployed(String? status) {
    final s = status?.trim().toLowerCase() ?? '';
    if (s == employed.toLowerCase()) return 'Yes';
    if (s == unemployed.toLowerCase()) return 'No';
    if (s == neverEmployed.toLowerCase()) return 'Never Employed';
    return null;
  }

  /// Maps CHED item 16 answer back to profile employment status.
  static String? fromChedPresentlyEmployed(String? answer) {
    final a = answer?.trim().toLowerCase() ?? '';
    if (a == 'yes') return employed;
    if (a == 'no') return unemployed;
    if (a == 'never employed') return neverEmployed;
    return null;
  }
}

class JobPosting {
  final String id;
  final String companyName;
  final String companyLogo;
  final String jobTitle;
  final String jobType;
  final String location;
  final String salaryRange;
  final String description;
  final List<String> requirements;
  final List<String> benefits;
  final DateTime postedDate;
  final DateTime applicationDeadline;
  final String contactEmail;
  final String applicationMethod;
  final bool isActive;
  final int views;
  final int applications;
  final String adminId;
  final bool isRemote;
  final String experienceLevel;
  final String status;
  final String category;
  final List<String> targetPrograms;
  final String applicationUrl;
  /// Populated client-side after interest/favorite count fetches.
  final int interestedCount;
  final int favoriteCount;

  const JobPosting({
    required this.id,
    required this.companyName,
    required this.companyLogo,
    required this.jobTitle,
    required this.jobType,
    required this.location,
    required this.salaryRange,
    required this.description,
    required this.requirements,
    required this.benefits,
    required this.postedDate,
    required this.applicationDeadline,
    required this.contactEmail,
    required this.applicationMethod,
    required this.isActive,
    required this.views,
    required this.applications,
    required this.adminId,
    required this.isRemote,
    required this.experienceLevel,
    required this.status,
    this.category = 'Others',
    this.targetPrograms = const [],
    this.applicationUrl = '',
    this.interestedCount = 0,
    this.favoriteCount = 0,
  });

  bool get isExpiredByDeadline {
    final end = DateTime(
      applicationDeadline.year,
      applicationDeadline.month,
      applicationDeadline.day,
      23,
      59,
      59,
    );
    return DateTime.now().isAfter(end);
  }

  bool get isActiveForAlumni =>
      status.toLowerCase() == 'active' && !isExpiredByDeadline;

  JobPosting copyWith({
    String? companyName,
    String? companyLogo,
    String? jobTitle,
    String? jobType,
    String? location,
    String? salaryRange,
    String? description,
    List<String>? requirements,
    List<String>? benefits,
    DateTime? applicationDeadline,
    String? contactEmail,
    String? applicationMethod,
    bool? isActive,
    int? views,
    int? applications,
    bool? isRemote,
    String? experienceLevel,
    String? status,
    String? category,
    List<String>? targetPrograms,
    String? applicationUrl,
    int? interestedCount,
    int? favoriteCount,
  }) {
    return JobPosting(
      id: id,
      companyName: companyName ?? this.companyName,
      companyLogo: companyLogo ?? this.companyLogo,
      jobTitle: jobTitle ?? this.jobTitle,
      jobType: jobType ?? this.jobType,
      location: location ?? this.location,
      salaryRange: salaryRange ?? this.salaryRange,
      description: description ?? this.description,
      requirements: requirements ?? this.requirements,
      benefits: benefits ?? this.benefits,
      postedDate: postedDate,
      applicationDeadline: applicationDeadline ?? this.applicationDeadline,
      contactEmail: contactEmail ?? this.contactEmail,
      applicationMethod: applicationMethod ?? this.applicationMethod,
      isActive: isActive ?? this.isActive,
      views: views ?? this.views,
      applications: applications ?? this.applications,
      adminId: adminId,
      isRemote: isRemote ?? this.isRemote,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      status: status ?? this.status,
      category: category ?? this.category,
      targetPrograms: targetPrograms ?? this.targetPrograms,
      applicationUrl: applicationUrl ?? this.applicationUrl,
      interestedCount: interestedCount ?? this.interestedCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
    );
  }

  Map<String, dynamic> toSupabaseRow() {
    final normalizedStatus = status.toLowerCase();
    return {
      'id': id,
      'title': jobTitle,
      'company': companyName,
      'location': location,
      'description': description,
      'status': normalizedStatus,
      'data': {
        'id': id,
        'companyName': companyName,
        'companyLogo': companyLogo,
        'jobTitle': jobTitle,
        'jobType': jobType,
        'location': location,
        'salaryRange': salaryRange,
        'description': description,
        'requirements': requirements,
        'benefits': benefits,
        'postedDate': postedDate.toUtc().toIso8601String(),
        'applicationDeadline': applicationDeadline.toUtc().toIso8601String(),
        'contactEmail': contactEmail,
        'applicationMethod': applicationMethod,
        'isActive': normalizedStatus == 'active',
        'views': views,
        'applications': applications,
        'adminId': adminId,
        'isRemote': isRemote,
        'experienceLevel': experienceLevel,
        'status': normalizedStatus,
        'category': category,
        'targetPrograms': targetPrograms,
        'applicationUrl': applicationUrl,
      },
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  factory JobPosting.fromSupabaseRow(Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(
      (row['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    DateTime parseDate(dynamic value, DateTime fallback) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal() ?? fallback;
      }
      return fallback;
    }

    final now = DateTime.now();
    final status =
        ((data['status'] as String?) ?? (row['status'] as String? ?? 'active'))
            .toLowerCase();

    return JobPosting(
      id: row['id']?.toString() ?? '',
      companyName:
          (data['companyName'] as String?) ?? (row['company'] as String? ?? ''),
      companyLogo: data['companyLogo'] as String? ?? '',
      jobTitle:
          (data['jobTitle'] as String?) ?? (row['title'] as String? ?? ''),
      jobType: data['jobType'] as String? ?? '',
      location:
          (data['location'] as String?) ?? (row['location'] as String? ?? ''),
      salaryRange: data['salaryRange'] as String? ?? '',
      description: (data['description'] as String?) ??
          (row['description'] as String? ?? ''),
      requirements: List<String>.from(data['requirements'] ?? const []),
      benefits: List<String>.from(data['benefits'] ?? const []),
      postedDate: parseDate(data['postedDate'], now),
      applicationDeadline: parseDate(data['applicationDeadline'], now),
      contactEmail: data['contactEmail'] as String? ?? '',
      applicationMethod: data['applicationMethod'] as String? ?? 'email',
      isActive: data['isActive'] as bool? ?? (status == 'active'),
      views: (data['views'] as num?)?.toInt() ?? 0,
      applications: (data['applications'] as num?)?.toInt() ?? 0,
      adminId: data['adminId'] as String? ?? '',
      isRemote: data['isRemote'] as bool? ?? false,
      experienceLevel: data['experienceLevel'] as String? ?? '',
      status: status,
      category: (data['category'] as String?)?.trim().isNotEmpty == true
          ? data['category'] as String
          : 'Others',
      targetPrograms: List<String>.from(data['targetPrograms'] ?? const []),
      applicationUrl: data['applicationUrl'] as String? ?? '',
    );
  }
}

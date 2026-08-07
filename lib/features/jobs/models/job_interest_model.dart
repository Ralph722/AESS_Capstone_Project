class JobInterest {
  const JobInterest({
    required this.userId,
    required this.jobId,
    required this.createdAt,
  });

  final String userId;
  final String jobId;
  final DateTime createdAt;

  factory JobInterest.fromSupabaseRow(Map<String, dynamic> row) {
    return JobInterest(
      userId: row['user_id']?.toString() ?? '',
      jobId: row['job_id']?.toString() ?? '',
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'].toString())?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Alumni row for the admin interested drawer.
class JobInterestedAlumni {
  const JobInterestedAlumni({
    required this.userId,
    required this.name,
    required this.email,
    required this.interestedAt,
    this.course = '',
    this.batch = '',
    this.employmentStatus = '',
    this.avatarUrl,
  });

  final String userId;
  final String name;
  final String email;
  final DateTime interestedAt;
  final String course;
  final String batch;
  final String employmentStatus;
  final String? avatarUrl;
}

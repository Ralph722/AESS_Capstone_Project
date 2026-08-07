import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';

void main() {
  test('JobPosting copyWith preserves id and updates fields', () {
    final job = JobPosting(
      id: 'job-1',
      companyName: 'Acme',
      companyLogo: '',
      jobTitle: 'Engineer',
      jobType: 'Full-time',
      location: 'Manila',
      salaryRange: '50k',
      description: 'Desc',
      requirements: const ['Dart'],
      benefits: const ['HMO'],
      postedDate: DateTime(2025, 1, 1),
      applicationDeadline: DateTime(2025, 6, 1),
      contactEmail: 'hr@acme.com',
      applicationMethod: 'email',
      isActive: true,
      views: 0,
      applications: 0,
      adminId: 'admin-1',
      isRemote: false,
      experienceLevel: 'Mid',
      status: 'active',
    );

    final updated = job.copyWith(jobTitle: 'Senior Engineer', status: 'archived');

    expect(updated.id, 'job-1');
    expect(updated.jobTitle, 'Senior Engineer');
    expect(updated.status, 'archived');
    expect(updated.companyName, 'Acme');
  });
}

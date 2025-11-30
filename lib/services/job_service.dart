import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alumni_system/screens/job_posting_screen.dart';

class JobService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add a new job posting
  Future<void> addJobPosting(JobPosting job) async {
    try {
      await _firestore.collection('jobs').doc(job.id).set(
            _jobPostingToFirestore(job),
          );
    } catch (e) {
      throw Exception('Error adding job posting: $e');
    }
  }

  /// Get all active job postings
  Future<List<JobPosting>> getActiveJobs() async {
    try {
      final snapshot = await _firestore
          .collection('jobs')
          .where('status', isEqualTo: 'active')
          .get();

      final jobs = snapshot.docs.map((doc) => _jobPostingFromFirestore(doc)).toList();
      jobs.sort((a, b) => b.postedDate.compareTo(a.postedDate));
      return jobs;
    } catch (e) {
      throw Exception('Error fetching active jobs: $e');
    }
  }

  /// Get all job postings (including archived)
  Future<List<JobPosting>> getAllJobs() async {
    try {
      final snapshot = await _firestore.collection('jobs').get();
      final jobs = snapshot.docs.map((doc) => _jobPostingFromFirestore(doc)).toList();
      jobs.sort((a, b) => b.postedDate.compareTo(a.postedDate));
      return jobs;
    } catch (e) {
      throw Exception('Error fetching all jobs: $e');
    }
  }

  /// Get jobs by status
  Future<List<JobPosting>> getJobsByStatus(String status) async {
    try {
      final snapshot = await _firestore
          .collection('jobs')
          .where('status', isEqualTo: status)
          .get();

      final jobs = snapshot.docs.map((doc) => _jobPostingFromFirestore(doc)).toList();
      jobs.sort((a, b) => b.postedDate.compareTo(a.postedDate));
      return jobs;
    } catch (e) {
      throw Exception('Error fetching jobs by status: $e');
    }
  }

  /// Get a single job posting
  Future<JobPosting?> getJobPosting(String jobId) async {
    try {
      final doc = await _firestore.collection('jobs').doc(jobId).get();
      if (doc.exists) {
        return _jobPostingFromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching job posting: $e');
    }
  }

  /// Update a job posting
  Future<void> updateJobPosting(JobPosting job) async {
    try {
      await _firestore.collection('jobs').doc(job.id).update(
            _jobPostingToFirestore(job),
          );
    } catch (e) {
      throw Exception('Error updating job posting: $e');
    }
  }

  /// Delete a job posting
  Future<void> deleteJobPosting(String jobId) async {
    try {
      await _firestore.collection('jobs').doc(jobId).delete();
    } catch (e) {
      throw Exception('Error deleting job posting: $e');
    }
  }

  /// Get total count of jobs
  Future<int> getTotalJobsCount() async {
    try {
      final snapshot = await _firestore.collection('jobs').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Error fetching jobs count: $e');
    }
  }

  /// Get count of active jobs
  Future<int> getActiveJobsCount() async {
    try {
      final snapshot = await _firestore
          .collection('jobs')
          .where('status', isEqualTo: 'active')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Error fetching active jobs count: $e');
    }
  }

  /// Increment view count
  Future<void> incrementViewCount(String jobId) async {
    try {
      await _firestore.collection('jobs').doc(jobId).update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('Error incrementing view count: $e');
    }
  }

  /// Increment application count
  Future<void> incrementApplicationCount(String jobId) async {
    try {
      await _firestore.collection('jobs').doc(jobId).update({
        'applications': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('Error incrementing application count: $e');
    }
  }

  /// Convert JobPosting to Firestore format
  Map<String, dynamic> _jobPostingToFirestore(JobPosting job) {
    return {
      'id': job.id,
      'companyName': job.companyName,
      'companyLogo': job.companyLogo,
      'jobTitle': job.jobTitle,
      'jobType': job.jobType,
      'location': job.location,
      'salaryRange': job.salaryRange,
      'description': job.description,
      'requirements': job.requirements,
      'benefits': job.benefits,
      'postedDate': Timestamp.fromDate(job.postedDate),
      'applicationDeadline': Timestamp.fromDate(job.applicationDeadline),
      'contactEmail': job.contactEmail,
      'applicationMethod': job.applicationMethod,
      'isActive': job.isActive,
      'views': job.views,
      'applications': job.applications,
      'adminId': job.adminId,
      'isRemote': job.isRemote,
      'experienceLevel': job.experienceLevel,
      'status': job.status,
    };
  }

  /// Convert Firestore document to JobPosting
  JobPosting _jobPostingFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobPosting(
      id: data['id'] ?? '',
      companyName: data['companyName'] ?? '',
      companyLogo: data['companyLogo'] ?? '',
      jobTitle: data['jobTitle'] ?? '',
      jobType: data['jobType'] ?? '',
      location: data['location'] ?? '',
      salaryRange: data['salaryRange'] ?? '',
      description: data['description'] ?? '',
      requirements: List<String>.from(data['requirements'] ?? []),
      benefits: List<String>.from(data['benefits'] ?? []),
      postedDate: (data['postedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      applicationDeadline: (data['applicationDeadline'] as Timestamp?)?.toDate() ?? DateTime.now(),
      contactEmail: data['contactEmail'] ?? '',
      applicationMethod: data['applicationMethod'] ?? 'email',
      isActive: data['isActive'] ?? true,
      views: data['views'] ?? 0,
      applications: data['applications'] ?? 0,
      adminId: data['adminId'] ?? '',
      isRemote: data['isRemote'] ?? false,
      experienceLevel: data['experienceLevel'] ?? '',
      status: data['status'] ?? 'active',
    );
  }
}

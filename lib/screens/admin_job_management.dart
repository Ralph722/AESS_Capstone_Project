// admin_job_management.dart
import 'package:flutter/material.dart';
import 'package:alumni_system/services/job_service.dart';
import 'job_posting_screen.dart';
import 'add_job_dialog.dart';

class AdminJobManagement extends StatefulWidget {
  const AdminJobManagement({super.key});

  @override
  State<AdminJobManagement> createState() => _AdminJobManagementState();
}

class _AdminJobManagementState extends State<AdminJobManagement> {
  final TextEditingController _searchController = TextEditingController();
  final List<JobPosting> _jobPostings = [];
  final List<JobPosting> _filteredJobs = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0: Active, 1: Drafts, 2: Expired

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    final jobService = JobService();
    try {
      print('DEBUG: Starting to load jobs...');
      final jobs = await jobService.getAllJobs().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Loading jobs took too long');
        },
      );
      print('DEBUG: Loaded ${jobs.length} jobs');
      if (mounted) {
        setState(() {
          _jobPostings.clear();
          _jobPostings.addAll(jobs);
          _filteredJobs.clear();
          _filteredJobs.addAll(jobs.where(_filterByTab));
          _isLoading = false;
        });
      }
    } catch (e) {
      print('DEBUG: Error loading jobs: $e');
      // Load mock data for testing
      _loadMockJobs();
    }
  }

  void _loadMockJobs() {
    final mockJobs = [
      JobPosting(
        id: '1',
        companyName: 'Tech Corp',
        companyLogo: '',
        jobTitle: 'Senior Flutter Developer',
        jobType: 'Full-time',
        location: 'San Francisco, CA',
        salaryRange: '\$120k - \$160k',
        description: 'We are looking for an experienced Flutter developer.',
        requirements: ['5+ years experience', 'Flutter expertise', 'Mobile development'],
        benefits: ['Health insurance', 'Remote work', '401k'],
        postedDate: DateTime.now().subtract(const Duration(days: 2)),
        applicationDeadline: DateTime.now().add(const Duration(days: 30)),
        contactEmail: 'jobs@techcorp.com',
        applicationMethod: 'email',
        isActive: true,
        views: 150,
        applications: 12,
        adminId: 'admin1',
        isRemote: true,
        experienceLevel: 'Senior',
        status: 'active',
      ),
      JobPosting(
        id: '2',
        companyName: 'StartUp Inc',
        companyLogo: '',
        jobTitle: 'Junior Web Developer',
        jobType: 'Part-time',
        location: 'New York, NY',
        salaryRange: '\$50k - \$70k',
        description: 'Join our growing startup team.',
        requirements: ['2+ years experience', 'React knowledge', 'JavaScript'],
        benefits: ['Flexible hours', 'Learning budget'],
        postedDate: DateTime.now().subtract(const Duration(days: 5)),
        applicationDeadline: DateTime.now().add(const Duration(days: 20)),
        contactEmail: 'hr@startupinc.com',
        applicationMethod: 'email',
        isActive: true,
        views: 89,
        applications: 5,
        adminId: 'admin1',
        isRemote: false,
        experienceLevel: 'Junior',
        status: 'active',
      ),
    ];

    if (mounted) {
      setState(() {
        _jobPostings.clear();
        _jobPostings.addAll(mockJobs);
        _filteredJobs.clear();
        _filteredJobs.addAll(mockJobs.where(_filterByTab));
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loaded mock data. Check Firestore connection.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  void _searchJobs(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredJobs.clear();
        _filteredJobs.addAll(_jobPostings.where((job) => _filterByTab(job)));
      } else {
        _filteredJobs.clear();
        _filteredJobs.addAll(_jobPostings.where((job) =>
            _filterByTab(job) &&
            (job.jobTitle.toLowerCase().contains(query.toLowerCase()) ||
                job.companyName.toLowerCase().contains(query.toLowerCase()))));
      }
    });
  }

  bool _filterByTab(JobPosting job) {
    switch (_selectedTab) {
      case 0: // Active
        return job.status == 'active';
      case 1: // Drafts
        return job.status == 'draft';
      case 2: // Expired
        return job.status == 'expired';
      default:
        return true;
    }
  }

  void _showAddJobDialog() {
    showDialog(
      context: context,
      builder: (context) => AddJobDialog(
        onJobAdded: (newJob) {
          setState(() {
            _jobPostings.add(newJob);
            _filteredJobs.add(newJob);
          });
        },
      ),
    );
  }

  void _editJob(JobPosting job) {
    showDialog(
      context: context,
      builder: (context) => AddJobDialog(
        job: job,
        onJobUpdated: (updatedJob) {
          setState(() {
            final index = _jobPostings.indexWhere((j) => j.id == updatedJob.id);
            if (index != -1) {
              _jobPostings[index] = updatedJob;
              _filteredJobs[_filteredJobs.indexWhere((j) => j.id == updatedJob.id)] = updatedJob;
            }
          });
        },
      ),
    );
  }

  void _deleteJob(String jobId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job Posting'),
        content: const Text('Are you sure you want to delete this job posting? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final jobService = JobService();
              try {
                await jobService.deleteJobPosting(jobId);
                if (mounted) {
                  setState(() {
                    _jobPostings.removeWhere((job) => job.id == jobId);
                    _filteredJobs.removeWhere((job) => job.id == jobId);
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Job posting deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting job: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _toggleJobStatus(String jobId, String newStatus) async {
    final jobService = JobService();
    try {
      final job = _jobPostings.firstWhere((job) => job.id == jobId);
      final updatedJob = job.copyWith(status: newStatus);
      await jobService.updateJobPosting(updatedJob);
      
      if (mounted) {
        setState(() {
          final index = _jobPostings.indexWhere((j) => j.id == jobId);
          _jobPostings[index] = updatedJob;
          _filteredJobs[_filteredJobs.indexWhere((j) => j.id == jobId)] = updatedJob;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Job ${newStatus == 'active' ? 'activated' : 'archived'}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Title and Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Job Postings Management',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF090A4F),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _showAddJobDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Post New Job'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF090A4F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Stats Cards Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: 150,
                child: _buildStatCard('Total Jobs', _jobPostings.length.toString(), Icons.work),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 150,
                child: _buildStatCard('Active', _jobPostings.where((j) => j.status == 'active').length.toString(), Icons.check_circle),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 150,
                child: _buildStatCard('Applications', '20', Icons.people),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 150,
                child: _buildStatCard('Views', '456', Icons.visibility),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Search Bar
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(Icons.search, color: Colors.grey, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _searchJobs,
                  decoration: const InputDecoration(
                    hintText: 'Search jobs...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tabs
        Row(
          children: [
            _buildTab('Active', 0),
            const SizedBox(width: 16),
            _buildTab('Drafts', 1),
            const SizedBox(width: 16),
            _buildTab('Expired', 2),
          ],
        ),
        const SizedBox(height: 16),

        // Jobs List
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          )
        else if (_filteredJobs.isEmpty)
          _buildEmptyState()
        else
          ...List.generate(
            _filteredJobs.length,
            (index) => _buildJobCard(_filteredJobs[index]),
          ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF090A4F), size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF090A4F),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
          _filteredJobs.clear();
          _filteredJobs.addAll(_jobPostings.where(_filterByTab));
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF090A4F) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF090A4F) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildJobCard(JobPosting job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Company Logo
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF090A4F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.business, color: Color(0xFF090A4F)),
              ),
              const SizedBox(width: 12),
              // Job Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.companyName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF090A4F),
                      ),
                    ),
                    Text(
                      job.jobTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF090A4F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildStatusChip(job.status),
                        _buildDetailChip(job.jobType),
                        _buildDetailChip(job.location),
                        if (job.isRemote) _buildDetailChip('Remote'),
                      ],
                    ),
                  ],
                ),
              ),
              // Stats
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.visibility, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${job.views}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.people, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${job.applications}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editJob(job),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF090A4F),
                    side: const BorderSide(color: Color(0xFF090A4F)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _toggleJobStatus(
                      job.id,
                      job.status == 'active' ? 'archived' : 'active',
                    );
                  },
                  icon: Icon(
                    job.status == 'active' ? Icons.archive : Icons.unarchive,
                    size: 16,
                  ),
                  label: Text(job.status == 'active' ? 'Archive' : 'Activate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _deleteJob(job.id),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'active':
        color = Colors.green;
      case 'draft':
        color = Colors.orange;
      case 'expired':
        color = Colors.red;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDetailChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.work_outline,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedTab == 0
                ? 'No active job postings'
                : _selectedTab == 1
                    ? 'No draft job postings'
                    : 'No expired job postings',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedTab == 0
                ? 'Create your first job posting to get started'
                : 'All your ${_selectedTab == 1 ? 'drafts' : 'expired jobs'} will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
          ),
          if (_selectedTab == 0) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showAddJobDialog,
              child: const Text('Post New Job'),
            ),
          ],
        ],
      ),
    );
  }
}
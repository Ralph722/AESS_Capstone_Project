// admin_job_management.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
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
  int _selectedTab = 0; // 0: Active, 1: Expired

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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading jobs: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
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
      case 1: // Expired
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
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF090A4F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.work,
                  color: Color(0xFF090A4F),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Job Postings Management',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF090A4F),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddJobDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Post New Job',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF090A4F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Stats Cards - Evenly Spaced
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Jobs',
                _jobPostings.length.toString(),
                Icons.work,
                const Color(0xFF090A4F),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Active',
                _jobPostings.where((j) => j.status == 'active').length.toString(),
                Icons.check_circle,
                const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Expired',
                _jobPostings.where((j) => j.status == 'expired').length.toString(),
                Icons.schedule,
                const Color(0xFFF44336),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Applications',
                _jobPostings.fold<int>(0, (sum, job) => sum + job.applications).toString(),
                Icons.people,
                const Color(0xFF9C27B0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Main Content Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search and Tabs Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF090A4F),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  children: [
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _searchJobs,
                        decoration: InputDecoration(
                          hintText: 'Search jobs by title or company...',
                          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Tabs
                    Row(
                      children: [
                        _buildTab('Active', 0),
                        const SizedBox(width: 12),
                        _buildTab('Expired', 1),
                      ],
                    ),
                  ],
                ),
              ),
              // Jobs List
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_filteredJobs.isEmpty)
                _buildEmptyState()
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredJobs.length,
                  itemBuilder: (context, index) {
                    return _buildJobCard(_filteredJobs[index]);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isSelected = _selectedTab == index;
    final count = _jobPostings.where((job) {
      switch (index) {
        case 0:
          return job.status == 'active';
        case 1:
          return job.status == 'expired';
        default:
          return false;
      }
    }).length;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
            _filteredJobs.clear();
            _filteredJobs.addAll(_jobPostings.where(_filterByTab));
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF090A4F) : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF090A4F).withOpacity(0.1)
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF090A4F) : Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobCard(JobPosting job) {
    final statusColor = _getStatusColor(job.status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
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
              // Status Indicator
              Container(
                width: 4,
                height: 80,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              // Job Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                job.jobTitle,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF090A4F),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.business, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    job.companyName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _buildStatusChip(job.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildDetailChip(job.jobType),
                        _buildDetailChip(job.location),
                        if (job.isRemote)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.home, size: 12, color: Colors.blue.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'Remote',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (job.experienceLevel.isNotEmpty)
                          _buildDetailChip(job.experienceLevel),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'Posted: ${intl.DateFormat('MMM d, yyyy').format(job.postedDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${job.applications} applications',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
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
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'expired':
        return Colors.red;
      case 'archived':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
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
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _selectedTab == 0
                  ? Icons.work_outline
                  : Icons.schedule,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedTab == 0
                  ? 'No active job postings'
                  : 'No expired job postings',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedTab == 0
                  ? 'Create your first job posting to get started'
                  : 'All your expired jobs will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            if (_selectedTab == 0) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showAddJobDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Post New Job'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF090A4F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
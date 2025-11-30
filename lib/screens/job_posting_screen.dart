import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:alumni_system/services/job_service.dart';

class JobPostingScreen extends StatefulWidget {
  const JobPostingScreen({super.key});

  @override
  State<JobPostingScreen> createState() => _JobPostingScreenState();
}

class _JobPostingScreenState extends State<JobPostingScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedFilter = 0;
  final List<String> _filters = ['All', 'Full-time', 'Part-time', 'Remote', 'Internship'];
  final List<JobPosting> _jobPostings = [];
  final List<JobPosting> _filteredJobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    try {
      final jobService = JobService();
      final jobs = await jobService.getActiveJobs().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Loading jobs took too long');
        },
      );
      if (mounted) {
        setState(() {
          _jobPostings.clear();
          _jobPostings.addAll(jobs);
          _filteredJobs.clear();
          _filteredJobs.addAll(jobs);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading jobs: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterJobs(int filterIndex) {
    setState(() {
      _selectedFilter = filterIndex;
      if (filterIndex == 0) {
        _filteredJobs.clear();
        _filteredJobs.addAll(_jobPostings);
      } else {
        final filter = _filters[filterIndex];
        _filteredJobs.clear();
        _filteredJobs.addAll(_jobPostings.where((job) => job.jobType == filter));
      }
    });
  }

  void _searchJobs(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredJobs.clear();
        _filteredJobs.addAll(_jobPostings);
      } else {
        _filteredJobs.clear();
        _filteredJobs.addAll(_jobPostings.where((job) =>
            job.jobTitle.toLowerCase().contains(query.toLowerCase()) ||
            job.companyName.toLowerCase().contains(query.toLowerCase()) ||
            job.location.toLowerCase().contains(query.toLowerCase())));
      }
    });
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return intl.DateFormat('MMM d').format(dateTime);
    }
  }

  void _showJobDetails(JobPosting job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => JobDetailsModal(job: job),
    );
  }

  void _applyToJob(JobPosting job) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Application sent to ${job.companyName}'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF090A4F), Color(0xFF1A237E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.work_outline, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Job Postings',
              style: TextStyle(
                color: Color(0xFF090A4F),
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bookmark_border,
                color: Color(0xFF090A4F),
                size: 22,
              ),
            ),
            onPressed: () {
              // TODO: Navigate to saved jobs
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // IMPROVED Search Section
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar - IMPROVED
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
                      const Icon(
                        Icons.search,
                        color: Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _searchJobs,
                          decoration: const InputDecoration(
                            hintText: 'Search jobs, companies, or locations...',
                            hintStyle: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF090A4F),
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: Colors.grey,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _searchJobs('');
                          },
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // IMPROVED Filter Chips
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return FilterChip(
                        label: Text(
                          _filters[index],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _selectedFilter == index 
                                ? Colors.white 
                                : const Color(0xFF090A4F),
                          ),
                        ),
                        selected: _selectedFilter == index,
                        onSelected: (selected) => _filterJobs(index),
                        backgroundColor: Colors.white,
                        selectedColor: const Color(0xFF090A4F),
                        side: BorderSide(
                          color: _selectedFilter == index 
                              ? const Color(0xFF090A4F) 
                              : Colors.grey.shade300,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        checkmarkColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Job Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: Colors.white,
            child: Row(
              children: [
                Text(
                  '${_filteredJobs.length} jobs found',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // Sort dropdown would go here
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Newest',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey.shade600,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Job Listings (unchanged)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredJobs.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredJobs.length,
                        itemBuilder: (context, index) {
                          final job = _filteredJobs[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: JobPostingCard(
                              job: job,
                              onTap: () => _showJobDetails(job),
                              onApply: () => _applyToJob(job),
                              getTimeAgo: _getTimeAgo,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.work_outline,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No jobs found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

// Rest of the code remains the same (JobPostingCard, JobDetailsModal, JobPosting class)
class JobPostingCard extends StatelessWidget {
  final JobPosting job;
  final VoidCallback onTap;
  final VoidCallback onApply;
  final String Function(DateTime) getTimeAgo;
  final Function(JobPosting)? onEdit;
  final Function(String)? onDelete;

  const JobPostingCard({
    super.key,
    required this.job,
    required this.onTap,
    required this.onApply,
    required this.getTimeAgo,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
            // Header with Company and Time
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Company Logo
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF090A4F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.business,
                    color: const Color(0xFF090A4F),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Company and Job Info
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
                      const SizedBox(height: 4),
                      Text(
                        job.jobTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF090A4F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        getTimeAgo(job.postedDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Bookmark Button
                IconButton(
                  icon: const Icon(
                    Icons.bookmark_border,
                    color: Color(0xFF090A4F),
                    size: 20,
                  ),
                  onPressed: () {
                    // TODO: Save job functionality
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Job Details Row
            Row(
              children: [
                _buildJobDetailChip(job.jobType, Icons.work_outline),
                const SizedBox(width: 8),
                _buildJobDetailChip(job.location, Icons.location_on),
                if (job.isRemote) ...[
                  const SizedBox(width: 8),
                  _buildJobDetailChip('Remote', Icons.work_outline),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // Salary and Experience
            Row(
              children: [
                Icon(
                  Icons.attach_money,
                  size: 16,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  job.salaryRange,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.star,
                  size: 16,
                  color: Colors.orange.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  job.experienceLevel,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF090A4F),
                      side: const BorderSide(color: Color(0xFF090A4F)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 8),
                // Edit Button
                if (onEdit != null)
                  SizedBox(
                    width: 45,
                    child: OutlinedButton(
                      onPressed: () => onEdit!(job),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Icon(Icons.edit, size: 18),
                    ),
                  ),
                if (onEdit != null) const SizedBox(width: 8),
                // Delete Button
                if (onDelete != null)
                  SizedBox(
                    width: 45,
                    child: OutlinedButton(
                      onPressed: () => onDelete!(job.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Icon(Icons.delete, size: 18),
                    ),
                  ),
                if (onDelete != null) const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF090A4F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobDetailChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF090A4F).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: const Color(0xFF090A4F),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF090A4F),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// JobDetailsModal Widget
class JobDetailsModal extends StatelessWidget {
  final JobPosting job;

  const JobDetailsModal({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.jobTitle,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF090A4F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              job.companyName,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Job Details
                  _buildDetailSection('Job Type', job.jobType),
                  _buildDetailSection('Location', job.location),
                  _buildDetailSection('Salary', job.salaryRange),
                  _buildDetailSection('Experience Level', job.experienceLevel),
                  _buildDetailSection('Application Deadline', 
                      intl.DateFormat('MMM d, yyyy').format(job.applicationDeadline)),

                  const SizedBox(height: 24),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF090A4F),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    job.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Requirements
                  const Text(
                    'Requirements',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF090A4F),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...job.requirements.map((req) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 16)),
                        Expanded(
                          child: Text(
                            req,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),

                  const SizedBox(height: 24),

                  // Benefits
                  const Text(
                    'Benefits',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF090A4F),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...job.benefits.map((benefit) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✓ ', style: TextStyle(fontSize: 16, color: Color(0xFF4CAF50))),
                        Expanded(
                          child: Text(
                            benefit,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),

                  const SizedBox(height: 32),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Application sent to ${job.companyName}'),
                            backgroundColor: const Color(0xFF4CAF50),
                          ),
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF090A4F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF090A4F),
            ),
          ),
        ],
      ),
    );
  }
}

// JobPosting Model Class
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
  final String status; // NEW

  JobPosting({
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
    required this.status, //NEW
  });
}

// Add this extension for copyWith method (NEW)
extension JobPostingCopyWith on JobPosting {
  JobPosting copyWith({
    String? companyName,
    String? jobTitle,
    String? jobType,
    String? location,
    String? salaryRange,
    String? description,
    List<String>? requirements,
    List<String>? benefits,
    DateTime? applicationDeadline,
    String? contactEmail,
    bool? isRemote,
    String? experienceLevel,
    String? status,
  }) {
    return JobPosting(
      id: id,
      companyName: companyName ?? this.companyName,
      companyLogo: companyLogo,
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
      applicationMethod: applicationMethod,
      isActive: isActive,
      views: views,
      applications: applications,
      adminId: adminId,
      isRemote: isRemote ?? this.isRemote,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      status: status ?? this.status,
    );
  }
}
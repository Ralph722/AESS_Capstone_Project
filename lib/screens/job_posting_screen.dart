import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:alumni_system/services/job_service.dart';
import 'package:alumni_system/services/favorite_job_service.dart';
import 'dart:async';

class JobPostingScreen extends StatefulWidget {
  const JobPostingScreen({super.key});

  @override
  State<JobPostingScreen> createState() => _JobPostingScreenState();
}

class _JobPostingScreenState extends State<JobPostingScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FavoriteJobService _favoriteJobService = FavoriteJobService();
  int _selectedFilter = 0;
  final List<String> _filters = ['All', 'Full-time', 'Part-time', 'Remote', 'Internship'];
  final List<JobPosting> _jobPostings = [];
  final List<JobPosting> _filteredJobs = [];
  bool _isLoading = true;
  Set<String> _favoriteJobIds = {};
  StreamSubscription<List<String>>? _favoritesSubscription;
  String _selectedSort = 'Newest';
  final List<String> _sortOptions = ['Newest', 'Oldest', 'Salary: High to Low', 'Salary: Low to High'];

  @override
  void initState() {
    super.initState();
    _loadJobs();
    _startFavoritesListener();
  }


  void _startFavoritesListener() {
    _favoritesSubscription = _favoriteJobService.getFavoriteJobIdsStream().listen(
      (favoriteIds) {
        if (mounted) {
          setState(() {
            _favoriteJobIds = favoriteIds.toSet();
          });
        }
      },
      onError: (error) {
        print('Error listening to favorites: $error');
      },
    );
  }

  Future<void> _toggleFavorite(String jobId) async {
    try {
      final isFavorite = _favoriteJobIds.contains(jobId);
      if (isFavorite) {
        await _favoriteJobService.removeFromFavorites(jobId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job removed from favorites'),
              backgroundColor: Color(0xFF4CAF50),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        await _favoriteJobService.addToFavorites(jobId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job saved to favorites'),
              backgroundColor: Color(0xFF4CAF50),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
          // Apply current filter and sort
          _filterJobs(_selectedFilter);
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
      List<JobPosting> filtered = [];
      
      if (filterIndex == 0) {
        // All jobs
        filtered = List<JobPosting>.from(_jobPostings);
      } else {
        final filter = _filters[filterIndex];
        
        if (filter == 'Remote') {
          // Filter by isRemote boolean
          filtered = _jobPostings.where((job) => job.isRemote).toList();
        } else {
          // Filter by jobType (Full-time, Part-time, Internship)
          filtered = _jobPostings.where((job) => job.jobType == filter).toList();
        }
      }
      
      // Apply sorting
      _filteredJobs.clear();
      _filteredJobs.addAll(_applySort(filtered));
    });
  }

  List<JobPosting> _applySort(List<JobPosting> jobs) {
    final sorted = List<JobPosting>.from(jobs);
    
    switch (_selectedSort) {
      case 'Newest':
        sorted.sort((a, b) => b.postedDate.compareTo(a.postedDate));
        break;
      case 'Oldest':
        sorted.sort((a, b) => a.postedDate.compareTo(b.postedDate));
        break;
      case 'Salary: High to Low':
        sorted.sort((a, b) {
          final aSalary = _extractSalaryNumber(a.salaryRange);
          final bSalary = _extractSalaryNumber(b.salaryRange);
          return bSalary.compareTo(aSalary);
        });
        break;
      case 'Salary: Low to High':
        sorted.sort((a, b) {
          final aSalary = _extractSalaryNumber(a.salaryRange);
          final bSalary = _extractSalaryNumber(b.salaryRange);
          return aSalary.compareTo(bSalary);
        });
        break;
    }
    
    return sorted;
  }

  double _extractSalaryNumber(String salaryRange) {
    // Extract numeric value from salary range (e.g., "$50,000 - $70,000" -> 50000)
    // Or "$676767" -> 676767
    final regex = RegExp(r'[\d,]+');
    final matches = regex.allMatches(salaryRange);
    if (matches.isNotEmpty) {
      final firstMatch = matches.first.group(0)?.replaceAll(',', '') ?? '0';
      return double.tryParse(firstMatch) ?? 0.0;
    }
    return 0.0;
  }

  void _onSortChanged(String? newValue) {
    if (newValue != null && newValue != _selectedSort) {
      setState(() {
        _selectedSort = newValue;
        // Re-apply current filter with new sort
        _filterJobs(_selectedFilter);
      });
    }
  }

  void _searchJobs(String query) {
    setState(() {
      List<JobPosting> searchResults = [];
      
      if (query.isEmpty) {
        // Apply current filter
        if (_selectedFilter == 0) {
          searchResults = List<JobPosting>.from(_jobPostings);
        } else {
          final filter = _filters[_selectedFilter];
          if (filter == 'Remote') {
            searchResults = _jobPostings.where((job) => job.isRemote).toList();
          } else {
            searchResults = _jobPostings.where((job) => job.jobType == filter).toList();
          }
        }
      } else {
        // Apply search query
        final matchingJobs = _jobPostings.where((job) =>
            job.jobTitle.toLowerCase().contains(query.toLowerCase()) ||
            job.companyName.toLowerCase().contains(query.toLowerCase()) ||
            job.location.toLowerCase().contains(query.toLowerCase()));
        
        // Apply current filter if not "All"
        if (_selectedFilter == 0) {
          searchResults = matchingJobs.toList();
        } else {
          final filter = _filters[_selectedFilter];
          if (filter == 'Remote') {
            searchResults = matchingJobs.where((job) => job.isRemote).toList();
          } else {
            searchResults = matchingJobs.where((job) => job.jobType == filter).toList();
          }
        }
      }
      
      // Apply sorting
      _filteredJobs.clear();
      _filteredJobs.addAll(_applySort(searchResults));
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
      builder: (context) => JobDetailsModal(
        job: job,
        isFavorite: _favoriteJobIds.contains(job.id),
        onFavoriteToggle: () => _toggleFavorite(job.id),
      ),
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

  void _showFavoriteJobs() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FavoriteJobsDialog(
        favoriteJobIds: _favoriteJobIds.toList(),
        allJobs: _jobPostings,
        onJobTap: (job) {
          Navigator.pop(context);
          _showJobDetails(job);
        },
        onFavoriteToggle: (jobId) => _toggleFavorite(jobId),
        getTimeAgo: _getTimeAgo,
      ),
    );
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
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
          Stack(
            children: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _favoriteJobIds.isEmpty
                        ? Icons.bookmark_border
                        : Icons.bookmark,
                    color: _favoriteJobIds.isEmpty
                        ? const Color(0xFF090A4F)
                        : const Color(0xFFFFD700),
                    size: 22,
                  ),
                ),
                onPressed: () => _showFavoriteJobs(),
              ),
              if (_favoriteJobIds.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6B6B),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _favoriteJobIds.length > 99 ? '99+' : '${_favoriteJobIds.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
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
                // Sort dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedSort,
                    underline: const SizedBox(),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    items: _sortOptions.map((String option) {
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      );
                    }).toList(),
                    onChanged: _onSortChanged,
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
                              isFavorite: _favoriteJobIds.contains(job.id),
                              onFavoriteToggle: () => _toggleFavorite(job.id),
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
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const JobPostingCard({
    super.key,
    required this.job,
    required this.onTap,
    required this.onApply,
    required this.getTimeAgo,
    this.onEdit,
    this.onDelete,
    this.isFavorite = false,
    required this.onFavoriteToggle,
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
                GestureDetector(
                  onTap: () {
                    onFavoriteToggle();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isFavorite ? Icons.bookmark : Icons.bookmark_border,
                      color: isFavorite ? const Color(0xFFFFD700) : const Color(0xFF090A4F),
                      size: 20,
                    ),
                  ),
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
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const JobDetailsModal({
    super.key,
    required this.job,
    this.isFavorite = false,
    required this.onFavoriteToggle,
  });

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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isFavorite ? Icons.bookmark : Icons.bookmark_border,
                              color: isFavorite ? const Color(0xFFFFD700) : const Color(0xFF090A4F),
                            ),
                            onPressed: onFavoriteToggle,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
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

// Favorite Jobs Dialog
class _FavoriteJobsDialog extends StatelessWidget {
  final List<String> favoriteJobIds;
  final List<JobPosting> allJobs;
  final Function(JobPosting) onJobTap;
  final Function(String) onFavoriteToggle;
  final String Function(DateTime) getTimeAgo;

  const _FavoriteJobsDialog({
    required this.favoriteJobIds,
    required this.allJobs,
    required this.onJobTap,
    required this.onFavoriteToggle,
    required this.getTimeAgo,
  });

  List<JobPosting> get favoriteJobs {
    return allJobs.where((job) => favoriteJobIds.contains(job.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF090A4F),
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bookmark, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Saved Jobs',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${favoriteJobIds.length} ${favoriteJobIds.length == 1 ? 'job' : 'jobs'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Favorite Jobs List
            Expanded(
              child: favoriteJobs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bookmark_border,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No saved jobs yet',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the bookmark icon on any job to save it',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: favoriteJobs.length,
                      itemBuilder: (context, index) {
                        final job = favoriteJobs[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: JobPostingCard(
                            job: job,
                            onTap: () => onJobTap(job),
                            onApply: () {},
                            getTimeAgo: getTimeAgo,
                            isFavorite: true,
                            onFavoriteToggle: () => onFavoriteToggle(job.id),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
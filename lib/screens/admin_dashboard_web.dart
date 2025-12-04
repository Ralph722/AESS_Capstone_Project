import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/screens/login_screen.dart';
import 'package:alumni_system/screens/admin_messages_screen.dart';
import 'package:alumni_system/services/auth_service.dart';
import 'package:alumni_system/services/event_service.dart';
import 'package:alumni_system/services/audit_service.dart';
import 'package:alumni_system/services/job_service.dart';
import 'package:alumni_system/models/event_model.dart';
import 'package:alumni_system/models/audit_log_model.dart';
import 'package:alumni_system/screens/job_posting_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_job_management.dart'; // ADD THIS IMPORT (NEW)

class AdminDashboardWeb extends StatefulWidget {
  const AdminDashboardWeb({super.key});

  @override
  State<AdminDashboardWeb> createState() => _AdminDashboardWebState();
}

class _AdminDashboardWebState extends State<AdminDashboardWeb> {
  final TextEditingController _themeController = TextEditingController();
  final TextEditingController _batchYearController = TextEditingController();
  final TextEditingController _eventDateController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final AuthService _authService = AuthService();
  final EventService _eventService = EventService();
  final AuditService _auditService = AuditService();
  final JobService _jobService = JobService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _selectedMenuItem = 0;
  List<AlumniEvent> activeEvents = [];
  List<AlumniEvent> archivedEventsList = [];
  List<AlumniEvent> filteredEvents = [];
  List<AuditLog> auditLogs = [];
  List<AuditLog> filteredAuditLogs = [];
  bool isLoading = true;
  int totalEvents = 0;
  int expiringEvents = 0;
  int archivedEvents = 0;
  int totalUsers = 0;
  int totalJobs = 0;
  int unreadMessagesCount = 0;
  List<AuditLog> recentActivity = [];
  
  // Event filters
  String? _selectedBatchYear;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String? _selectedVenue;
  
  // Archives tab
  int _archivesTabIndex = 0;
  List<JobPosting> archivedJobs = [];

  // Activity log filters
  String _selectedActionFilter = 'All';
  String _selectedResourceFilter = 'All';
  String _selectedStatusFilter = 'All';
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _activitySearchController = TextEditingController();

  // Cached audit logs to prevent reloading
  List<AuditLog>? _cachedAuditLogs;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      setState(() => isLoading = true);
      final events = await _eventService.getActiveEvents();
      final total = await _eventService.getTotalEventsCount();
      final expiring = await _eventService.getExpiringEventsCount();
      final archived = await _eventService.getArchivedEventsCount();
      final archivedList = await _eventService.getArchivedEvents();
      
      // Load additional statistics
      final usersSnapshot = await _firestore.collection('users').count().get();
      final totalUsersCount = usersSnapshot.count ?? 0;
      
      final totalJobsCount = await _jobService.getTotalJobsCount();
      
      // Get unread messages count for admin (messages from users to admin)
      // We'll get all unread messages from users, then filter by admin recipient
      final unreadMessagesSnapshot = await _firestore
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderRole', isEqualTo: 'user')
          .get();
      // Count messages where recipient is admin (we'll check all and count those to admin)
      final unreadCount = unreadMessagesSnapshot.docs.length;
      
      // Load recent activity (last 5 logs)
      final recentLogs = await _auditService.getAllAuditLogs(limit: 5);
      
      // Preload activity logs in background for faster access when user navigates to that page
      _auditService.getAllAuditLogs(limit: 200).then((logs) {
        if (mounted) {
          setState(() {
            _cachedAuditLogs = logs;
          });
        }
      });
      
      // Load archived jobs
      List<JobPosting> archivedJobsList = [];
      try {
        archivedJobsList = await _jobService.getJobsByStatus('archived');
      } catch (e) {
        print('Error loading archived jobs: $e');
        archivedJobsList = [];
      }

      print(
        'DEBUG: Loaded ${events.length} active events, $total total, $expiring expiring, $archived archived',
      );
      setState(() {
        activeEvents = events;
        filteredEvents = events;
        totalEvents = total;
        expiringEvents = expiring;
        archivedEvents = archived;
        archivedEventsList = archivedList;
        totalUsers = totalUsersCount;
        totalJobs = totalJobsCount;
        unreadMessagesCount = unreadCount;
        recentActivity = recentLogs;
        archivedJobs = archivedJobsList;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print('DEBUG: Error loading data: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    }
  }

  Future<void> _loadEvents() async {
    await _loadAllData();
  }
  
  Future<void> _loadArchivedJobs() async {
    try {
      final archivedJobsList = await _jobService.getJobsByStatus('archived');
      if (mounted) {
        setState(() {
          archivedJobs = archivedJobsList;
        });
      }
    } catch (e) {
      print('Error loading archived jobs: $e');
      if (mounted) {
        setState(() {
          archivedJobs = [];
        });
      }
    }
  }

  DateTime _parseDate(String dateString) {
    try {
      // Handle MM/dd/yyyy format
      final parts = dateString.split('/');
      if (parts.length == 3) {
        final month = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
      // Fallback to default parsing
      return DateTime.parse(dateString);
    } catch (e) {
      throw Exception(
        'Invalid date format. Please use MM/dd/yyyy format (e.g., 12/20/2025)',
      );
    }
  }

  void _searchEvents(String query) {
    _applyFilters(searchQuery: query);
  }
  
  void _applyFilters({String? searchQuery}) {
    setState(() {
      var results = List<AlumniEvent>.from(activeEvents);
      
      // Search filter
      if (searchQuery != null && searchQuery.isNotEmpty) {
        results = results
            .where(
              (event) =>
                  event.theme.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  event.batchYear.contains(searchQuery) ||
                  event.venue.toLowerCase().contains(searchQuery.toLowerCase()),
            )
            .toList();
      }
      
      // Batch year filter
      if (_selectedBatchYear != null && _selectedBatchYear!.isNotEmpty) {
        results = results
            .where((event) => event.batchYear == _selectedBatchYear)
            .toList();
      }
      
      // Date range filter
      if (_filterStartDate != null) {
        final startDate = DateTime(_filterStartDate!.year, _filterStartDate!.month, _filterStartDate!.day);
        results = results
            .where((event) {
              final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
              return eventDate.isAfter(startDate.subtract(const Duration(days: 1))) || 
                     eventDate.isAtSameMomentAs(startDate);
            })
            .toList();
      }
      
      if (_filterEndDate != null) {
        final endDate = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day);
        results = results
            .where((event) {
              final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
              return eventDate.isBefore(endDate.add(const Duration(days: 1))) || 
                     eventDate.isAtSameMomentAs(endDate);
            })
            .toList();
      }
      
      // Venue filter
      if (_selectedVenue != null && _selectedVenue!.isNotEmpty) {
        results = results
            .where((event) => event.venue.toLowerCase().contains(_selectedVenue!.toLowerCase()))
            .toList();
      }
      
      filteredEvents = results;
    });
  }
  
  void _clearFilters() {
    setState(() {
      _selectedBatchYear = null;
      _filterStartDate = null;
      _filterEndDate = null;
      _selectedVenue = null;
      _searchController.clear();
      filteredEvents = activeEvents;
    });
  }
  
  List<String> _getUniqueBatchYears() {
    final years = activeEvents.map((e) => e.batchYear).toSet().toList();
    years.sort();
    return years;
  }
  
  List<String> _getUniqueVenues() {
    final venues = activeEvents.map((e) => e.venue).toSet().toList();
    venues.sort();
    return venues;
  }

  Future<void> _addEvent() async {
    if (_themeController.text.isEmpty ||
        _batchYearController.text.isEmpty ||
        _eventDateController.text.isEmpty ||
        _venueController.text.isEmpty ||
        _startTimeController.text.isEmpty ||
        _endTimeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    try {
      final newEvent = AlumniEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        theme: _themeController.text,
        batchYear: _batchYearController.text,
        date: _parseDate(_eventDateController.text),
        venue: _venueController.text,
        status: 'Active',
        comments: 0,
        startTime: _startTimeController.text,
        endTime: _endTimeController.text,
        description: _descriptionController.text,
      );

      print('DEBUG: Adding event with ID: ${newEvent.id}');
      await _eventService.addEvent(newEvent);
      print('DEBUG: Event added successfully');

      _themeController.clear();
      _batchYearController.clear();
      _eventDateController.clear();
      _venueController.clear();
      _startTimeController.clear();
      _endTimeController.clear();
      _descriptionController.clear();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event added successfully')));

      await _loadEvents();
    } catch (e) {
      print('DEBUG: Error adding event: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding event: $e')));
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    try {
      await _eventService.deleteEvent(eventId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event deleted')));
      await _loadEvents();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting event: $e')));
    }
  }

  Future<void> _archiveEvent(String eventId) async {
    try {
      await _eventService.archiveEvent(eventId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event archived')));
      await _loadEvents();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error archiving event: $e')));
    }
  }

  Future<void> _restoreEvent(String eventId) async {
    try {
      await _eventService.restoreEvent(eventId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event restored')));
      await _loadEvents();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error restoring event: $e')));
    }
  }

  Future<void> _editEvent(AlumniEvent event) async {
    _themeController.text = event.theme;
    _batchYearController.text = event.batchYear;
    _eventDateController.text = DateFormat('MM/dd/yyyy').format(event.date);
    _venueController.text = event.venue;
    _startTimeController.text = event.startTime;
    _endTimeController.text = event.endTime;
    _descriptionController.text = event.description;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Event'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFormField(
                'Event Theme',
                _themeController,
                'Enter event theme',
              ),
              const SizedBox(height: 16),
              _buildFormField(
                'Batch Year',
                _batchYearController,
                'Enter batch year',
              ),
              const SizedBox(height: 16),
              _buildFormField(
                'Event Date',
                _eventDateController,
                'MM/DD/YYYY',
                isDate: true,
              ),
              const SizedBox(height: 16),
              _buildFormField('Venue', _venueController, 'Enter venue'),
              const SizedBox(height: 16),
              _buildFormField(
                'Start Time',
                _startTimeController,
                'HH:mm',
                isTime: true,
              ),
              const SizedBox(height: 16),
              _buildFormField(
                'End Time',
                _endTimeController,
                'HH:mm',
                isTime: true,
              ),
              const SizedBox(height: 16),
              _buildFormField(
                'Description',
                _descriptionController,
                'Enter event description',
                isMultiline: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final updatedEvent = event.copyWith(
                  theme: _themeController.text,
                  batchYear: _batchYearController.text,
                  date: _parseDate(_eventDateController.text),
                  venue: _venueController.text,
                  startTime: _startTimeController.text,
                  endTime: _endTimeController.text,
                  description: _descriptionController.text,
                );
                await _eventService.updateEvent(updatedEvent);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Event updated successfully')),
                );
                await _loadEvents();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating event: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.getCurrentUser();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(currentUser),
          Expanded(
            child: Column(
              children: [
                _buildTopHeader(currentUser),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: _selectedMenuItem == 6
                        ? _buildMessagesContent() // Messages screen handles its own layout
                        : _buildContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(currentUser) {
    return Container(
      width: 280,
      color: const Color(0xFF090A4F),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: Color(0xFF090A4F),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Alumni Portal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildSidebarItem(0, Icons.dashboard, 'Dashboard'),
                _buildSidebarItem(1, Icons.event, 'Events'),
                _buildSidebarItem(2, Icons.people, 'Alumni Members'),
                _buildSidebarItem(3, Icons.comment, 'Comments'),
                _buildSidebarItem(4, Icons.archive, 'Archives'),
                _buildSidebarItem(5, Icons.work, 'Job Postings'),
                _buildSidebarItem(6, Icons.message, 'Messages'),
                _buildSidebarItem(7, Icons.history, 'Activity Logs'),
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Color(0xFF090A4F),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentUser?.displayName ?? 'Admin',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              currentUser?.email ?? 'admin@alumni.com',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(currentUser) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _getPageTitle(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF090A4F),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  color: Color(0xFF090A4F),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Admin - ${currentUser?.email?.split('@')[0] ?? 'User'}',
                  style: const TextStyle(
                    color: Color(0xFF090A4F),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    final isSelected = _selectedMenuItem == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedMenuItem = index;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? const Color(0xFF090A4F) : Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF090A4F) : Colors.white,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedMenuItem) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Events Management';
      case 2:
        return 'Alumni Members';
      case 3:
        return 'Comments';
      case 4:
        return 'Archives';
      case 5:
        return 'Job Postings';
      case 6:
        return 'Messages';
      case 7:
        return 'Activity Logs';
      default:
        return 'Dashboard';
    }
  }

  Widget _buildContent() {
    switch (_selectedMenuItem) {
      case 0:
        return SingleChildScrollView(child: _buildDashboardContent());
      case 1:
        return SingleChildScrollView(child: _buildEventsContent());
      case 2:
        return SingleChildScrollView(child: _buildMembersContent());
      case 3:
        return SingleChildScrollView(child: _buildCommentsContent());
      case 4:
        return SingleChildScrollView(child: _buildArchivedContent());
      case 5:
        return const SingleChildScrollView(child: AdminJobManagement());
      case 7:
        return SingleChildScrollView(child: _buildActivityLogsContent());
      default:
        return SingleChildScrollView(child: _buildDashboardContent());
    }
  }

  Widget _buildDashboardContent() {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Welcome Section - Compact
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF090A4F), Color(0xFF1A3A52)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome Back, Admin!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Here\'s what\'s happening with your alumni system today',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.dashboard,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // Statistics Cards - Horizontal Scrollable, Smaller
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatCard(
                'Total Events',
                totalEvents.toString(),
                Icons.event,
                const Color(0xFF1A3A52),
                Icons.trending_up,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Active Events',
                activeEvents.length.toString(),
                Icons.check_circle,
                const Color(0xFFFFD700),
                Icons.arrow_upward,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Total Users',
                totalUsers.toString(),
                Icons.people,
                const Color(0xFF2196F3),
                Icons.person_add,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Job Postings',
                totalJobs.toString(),
                Icons.work,
                const Color(0xFF4CAF50),
                Icons.business_center,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Expiring Soon',
                expiringEvents.toString(),
                Icons.warning,
                const Color(0xFFFF9800),
                Icons.schedule,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Unread Messages',
                unreadMessagesCount.toString(),
                Icons.mail,
                const Color(0xFF9C27B0),
                Icons.mark_email_unread,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Archived Events',
                archivedEvents.toString(),
                Icons.archive,
                const Color(0xFF607D8B),
                Icons.folder,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Main Content - Two Column Layout
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 1200;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _buildQuickActionsSection(),
                        const SizedBox(height: 20),
                        _buildUpcomingEventsSection(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: _buildRecentActivitySection(),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildQuickActionsSection(),
                  const SizedBox(height: 20),
                  _buildRecentActivitySection(),
                  const SizedBox(height: 20),
                  _buildUpcomingEventsSection(),
                ],
              );
            }
          },
        ),
      ],
    );
  }
  
  Widget _buildQuickActionsSection() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF090A4F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.flash_on,
                  color: Color(0xFF090A4F),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF090A4F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 400;
              final crossAxisCount = isWide ? 2 : 1;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.5,
                children: [
                  _buildQuickActionCard(
                    'Add New Event',
                    'Create event',
                    Icons.add_circle,
                    const Color(0xFF4CAF50),
                    () {
                      setState(() => _selectedMenuItem = 1);
                    },
                  ),
                  _buildQuickActionCard(
                    'View Members',
                    'Manage users',
                    Icons.people,
                    const Color(0xFF2196F3),
                    () {
                      setState(() => _selectedMenuItem = 2);
                    },
                  ),
                  _buildQuickActionCard(
                    'View Comments',
                    'Check comments',
                    Icons.comment,
                    const Color(0xFF9C27B0),
                    () {
                      setState(() => _selectedMenuItem = 3);
                    },
                  ),
                  _buildQuickActionCard(
                    'Manage Jobs',
                    'Job listings',
                    Icons.work,
                    const Color(0xFFFF9800),
                    () {
                      setState(() => _selectedMenuItem = 5);
                    },
                  ),
                  _buildQuickActionCard(
                    'Messages',
                    'View messages',
                    Icons.mail,
                    const Color(0xFFE91E63),
                    () {
                      setState(() => _selectedMenuItem = 6);
                    },
                  ),
                  _buildQuickActionCard(
                    'Activity Logs',
                    'Audit trail',
                    Icons.history,
                    const Color(0xFF795548),
                    () {
                      setState(() => _selectedMenuItem = 7);
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecentActivitySection() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF090A4F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.timeline,
                  color: Color(0xFF090A4F),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF090A4F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentActivity.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No recent activity',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ),
            )
          else
            ...recentActivity.take(5).map((log) => _buildActivityItem(log)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() => _selectedMenuItem = 7);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: const Text(
              'View All →',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActivityItem(AuditLog log) {
    IconData icon;
    Color iconColor;
    switch (log.action.toLowerCase()) {
      case 'create':
        icon = Icons.add_circle;
        iconColor = Colors.green;
        break;
      case 'update':
        icon = Icons.edit;
        iconColor = Colors.blue;
        break;
      case 'delete':
        icon = Icons.delete;
        iconColor = Colors.red;
        break;
      default:
        icon = Icons.info;
        iconColor = Colors.grey;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${log.action} ${log.resource}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d, HH:mm').format(log.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUpcomingEventsSection() {
    final upcomingEvents = activeEvents.where((event) {
      return event.date.isAfter(DateTime.now()) || 
             event.date.isAtSameMomentAs(DateTime.now().copyWith(hour: 0, minute: 0, second: 0));
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF090A4F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: Color(0xFF090A4F),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Upcoming Events',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF090A4F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (upcomingEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No upcoming events',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ),
            )
          else
            ...upcomingEvents.take(5).map((event) => _buildEventItem(event)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() => _selectedMenuItem = 1);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: const Text(
              'View All →',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEventItem(AlumniEvent event) {
    // Normalize dates to midnight for accurate day calculation
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
    final daysUntil = eventDate.difference(today).inDays;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 50,
            decoration: BoxDecoration(
              color: daysUntil <= 7 ? Colors.orange : const Color(0xFFFFD700),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.theme,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d').format(event.date),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.location_on, size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.venue,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (daysUntil >= 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      daysUntil == 0 
                          ? 'Today' 
                          : daysUntil == 1 
                              ? 'Tomorrow' 
                              : '$daysUntil days away',
                      style: TextStyle(
                        fontSize: 10,
                        color: daysUntil <= 7 ? Colors.orange : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1200;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildAddEventForm(),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 3,
                child: _buildEventsList(),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              _buildAddEventForm(),
              const SizedBox(height: 20),
              _buildEventsList(),
            ],
          );
        }
      },
    );
  }
  
  Widget _buildAddEventForm() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF090A4F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_circle,
                  color: Color(0xFF090A4F),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Create New Event',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF090A4F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildFormField(
            'Event Theme',
            _themeController,
            'Enter event theme',
            icon: Icons.event,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
                  Expanded(
                child: _buildFormField(
                  'Batch Year',
                  _batchYearController,
                  'e.g., 2024',
                  icon: Icons.calendar_month,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFormField(
                  'Event Date',
                  _eventDateController,
                  'MM/DD/YYYY',
                  isDate: true,
                  icon: Icons.calendar_today,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFormField(
            'Venue',
            _venueController,
            'Enter venue location',
            icon: Icons.location_on,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  'Start Time',
                  _startTimeController,
                  'HH:mm',
                  isTime: true,
                  icon: Icons.access_time,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFormField(
                  'End Time',
                  _endTimeController,
                  'HH:mm',
                  isTime: true,
                  icon: Icons.access_time,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFormField(
            'Description',
            _descriptionController,
            'Enter event description (optional)',
            isMultiline: true,
            icon: Icons.description,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addEvent,
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Create Event',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF090A4F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEventsList() {
    return Container(
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
        mainAxisSize: MainAxisSize.min,
        children: [
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.event,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Active Events',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      width: 280,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _searchEvents,
                        decoration: InputDecoration(
                          hintText: 'Search events...',
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
                  ],
                ),
                const SizedBox(height: 16),
                // Filters Row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 1000;
                      if (isWide) {
                        return Row(
                          children: [
                      // Batch Year Filter
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedBatchYear,
                            hint: Text(
                              'Batch Year',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            isExpanded: true,
                            underline: Container(),
                            icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600, size: 20),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('All Batch Years', style: TextStyle(fontSize: 12)),
                              ),
                              ..._getUniqueBatchYears().map((year) => DropdownMenuItem<String>(
                                value: year,
                                child: Text(year, style: const TextStyle(fontSize: 12)),
                              )),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedBatchYear = value;
                              });
                              _applyFilters();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Start Date Filter
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _filterStartDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() {
                                _filterStartDate = picked;
                              });
                              _applyFilters();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _filterStartDate != null
                                        ? DateFormat('MMM d, yyyy').format(_filterStartDate!)
                                        : 'From Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _filterStartDate != null
                                          ? Colors.black87
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // End Date Filter
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _filterEndDate ?? DateTime.now(),
                              firstDate: _filterStartDate ?? DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() {
                                _filterEndDate = picked;
                              });
                              _applyFilters();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _filterEndDate != null
                                        ? DateFormat('MMM d, yyyy').format(_filterEndDate!)
                                        : 'To Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _filterEndDate != null
                                          ? Colors.black87
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Venue Filter
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedVenue,
                            hint: Text(
                              'Venue',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            isExpanded: true,
                            underline: Container(),
                            icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600, size: 20),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('All Venues', style: TextStyle(fontSize: 12)),
                              ),
                              ..._getUniqueVenues().map((venue) => DropdownMenuItem<String>(
                                value: venue,
                                child: Text(
                                  venue.length > 20 ? '${venue.substring(0, 20)}...' : venue,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              )),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedVenue = value;
                              });
                              _applyFilters();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Clear Filters Button
                      if (_selectedBatchYear != null ||
                          _filterStartDate != null ||
                          _filterEndDate != null ||
                          _selectedVenue != null)
                        IconButton(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.clear, color: Colors.white, size: 20),
                          tooltip: 'Clear filters',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: DropdownButton<String>(
                                      value: _selectedBatchYear,
                                      hint: Text(
                                        'Batch Year',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                      isExpanded: true,
                                      underline: Container(),
                                      icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600, size: 20),
                                      items: [
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('All Batch Years', style: TextStyle(fontSize: 12)),
                                        ),
                                        ..._getUniqueBatchYears().map((year) => DropdownMenuItem<String>(
                                          value: year,
                                          child: Text(year, style: const TextStyle(fontSize: 12)),
                                        )),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedBatchYear = value;
                                        });
                                        _applyFilters();
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: DropdownButton<String>(
                                      value: _selectedVenue,
                                      hint: Text(
                                        'Venue',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                      isExpanded: true,
                                      underline: Container(),
                                      icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600, size: 20),
                                      items: [
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('All Venues', style: TextStyle(fontSize: 12)),
                                        ),
                                        ..._getUniqueVenues().map((venue) => DropdownMenuItem<String>(
                                          value: venue,
                                          child: Text(
                                            venue.length > 20 ? '${venue.substring(0, 20)}...' : venue,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        )),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedVenue = value;
                                        });
                                        _applyFilters();
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      final DateTime? picked = await showDatePicker(
                                        context: context,
                                        initialDate: _filterStartDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _filterStartDate = picked;
                                        });
                                        _applyFilters();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _filterStartDate != null
                                                  ? DateFormat('MMM d, yyyy').format(_filterStartDate!)
                                                  : 'From Date',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _filterStartDate != null
                                                    ? Colors.black87
                                                    : Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      final DateTime? picked = await showDatePicker(
                                        context: context,
                                        initialDate: _filterEndDate ?? DateTime.now(),
                                        firstDate: _filterStartDate ?? DateTime(2020),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _filterEndDate = picked;
                                        });
                                        _applyFilters();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _filterEndDate != null
                                                  ? DateFormat('MMM d, yyyy').format(_filterEndDate!)
                                                  : 'To Date',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _filterEndDate != null
                                                    ? Colors.black87
                                                    : Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (_selectedBatchYear != null ||
                                    _filterStartDate != null ||
                                    _filterEndDate != null ||
                                    _selectedVenue != null)
                                  IconButton(
                                    onPressed: _clearFilters,
                                    icon: const Icon(Icons.clear, color: Colors.white, size: 20),
                                    tooltip: 'Clear filters',
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          if (filteredEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No active events found',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first event to get started',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: filteredEvents.length,
              itemBuilder: (context, index) {
                final event = filteredEvents[index];
                return _buildEventCard(event);
              },
            ),
        ],
      ),
    );
  }
  
  Widget _buildEventCard(AlumniEvent event) {
    // Normalize dates to midnight for accurate day calculation
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
    final daysUntil = eventDate.difference(today).inDays;
    final isUpcoming = daysUntil >= 0;
    final isExpiringSoon = daysUntil >= 0 && daysUntil <= 7;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isExpiringSoon ? Colors.orange.withOpacity(0.3) : Colors.grey.shade200,
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
      child: Row(
        children: [
          Container(
            width: 4,
            height: 80,
            decoration: BoxDecoration(
              color: isExpiringSoon 
                  ? Colors.orange 
                  : isUpcoming 
                      ? const Color(0xFFFFD700) 
                      : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.theme,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF090A4F),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF090A4F),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MMM d, yyyy').format(event.date),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      '${event.startTime} - ${event.endTime}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        event.venue,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.comment, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${event.comments}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (isUpcoming && isExpiringSoon)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.warning, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          daysUntil == 0 
                              ? 'Event is today!' 
                              : daysUntil == 1 
                                  ? 'Event is tomorrow!' 
                                  : '$daysUntil days remaining',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton(
            icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.edit, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
                onTap: () => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => _editEvent(event),
                ),
              ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.archive, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Archive'),
                  ],
                ),
                onTap: () => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => _archiveEvent(event.id),
                ),
              ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
                onTap: () => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => _deleteEvent(event.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMembersContent() {
    return Container(
      padding: const EdgeInsets.all(24),
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
          const Text(
            'Alumni Members Management',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF090A4F),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Members management feature coming soon',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsContent() {
    return Container(
      padding: const EdgeInsets.all(24),
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
          const Text(
            'Comments Management',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF090A4F),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Comments management feature coming soon',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesContent() {
    // Use AdminMessagesScreen without AppBar since we're in the dashboard
    // The messages screen has its own Row layout, so it doesn't need SingleChildScrollView
    return const AdminMessagesScreen(hideAppBar: true);
  }

  Widget _buildArchivedContent() {
    // Ensure archivedJobs is initialized
    if (archivedJobs.isEmpty && !isLoading) {
      // Try to load archived jobs if not loaded yet
      _loadArchivedJobs();
    }
    
    return Container(
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
          // Header with Tabs
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF090A4F),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.archive,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Archives',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Tabs
                Row(
                  children: [
                    _buildArchiveTab(
                      0,
                      'Events',
                      archivedEventsList.length,
                      Icons.event,
                    ),
                    const SizedBox(width: 12),
                    _buildArchiveTab(
                      1,
                      'Job Postings',
                      (archivedJobs.isNotEmpty) ? archivedJobs.length : 0,
                      Icons.work,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tab Content
          _archivesTabIndex == 0
              ? _buildArchivedEventsTab()
              : _buildArchivedJobsTab(),
        ],
      ),
    );
  }
  
  Widget _buildArchiveTab(int index, String label, int count, IconData icon) {
    final isSelected = _archivesTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _archivesTabIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? const Color(0xFF090A4F) : Colors.white70,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF090A4F) : Colors.white70,
                ),
              ),
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
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF090A4F) : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildArchivedEventsTab() {
    if (archivedEventsList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.event_busy,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'No archived events',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: archivedEventsList.length,
      itemBuilder: (context, index) {
        final event = archivedEventsList[index];
        return _buildArchivedEventCard(event);
      },
    );
  }
  
  Widget _buildArchivedEventCard(AlumniEvent event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade300,
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
      child: Row(
        children: [
          Container(
            width: 4,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.theme,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF090A4F),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Archived',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MMM d, yyyy').format(event.date),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        event.venue,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.comment, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${event.comments}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton(
            icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.restore, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Restore'),
                  ],
                ),
                onTap: () => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => _restoreEvent(event.id),
                ),
              ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
                onTap: () => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => _deleteEvent(event.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildArchivedJobsTab() {
    if (archivedJobs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.work_off,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'No archived job postings',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: archivedJobs.length,
      itemBuilder: (context, index) {
        final job = archivedJobs[index];
        return _buildArchivedJobCard(job);
      },
    );
  }
  
  Widget _buildArchivedJobCard(JobPosting job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade300,
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
      child: Row(
        children: [
          Container(
            width: 4,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.jobTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF090A4F),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Archived',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.business, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      job.companyName,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      job.location,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (job.isRemote) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Remote',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(Icons.visibility, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${job.views}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${job.applications}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'Posted: ${DateFormat('MMM d, yyyy').format(job.postedDate)}',
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
          const SizedBox(width: 12),
          PopupMenuButton(
            icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.restore, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Restore'),
                  ],
                ),
                onTap: () => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => _restoreJob(job.id),
                ),
              ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
                onTap: () => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => _deleteJob(job.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Future<void> _restoreJob(String jobId) async {
    try {
      if (archivedJobs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job not found')),
        );
        return;
      }
      final job = archivedJobs.firstWhere((j) => j.id == jobId);
      await _jobService.updateJobPosting(
        job.copyWith(status: 'active'),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job posting restored')),
      );
      await _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error restoring job: $e')),
      );
    }
  }
  
  Future<void> _deleteJob(String jobId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job Posting'),
        content: const Text('Are you sure you want to permanently delete this job posting?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _jobService.deleteJobPosting(jobId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job posting deleted')),
        );
        await _loadAllData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting job: $e')),
        );
      }
    }
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color backgroundColor,
    IconData? trendIcon,
  ) {
    return Container(
      width: 140,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              if (trendIcon != null) ...[
                const SizedBox(width: 4),
                Icon(
                  trendIcon,
                  color: Colors.white.withOpacity(0.8),
                  size: 14,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2), width: 1.5),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF090A4F),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityLogsContent() {
    // Load logs only once, then cache them
    if (_cachedAuditLogs == null) {
      _auditService.getAllAuditLogs(limit: 200).then((logs) {
        if (mounted) {
          setState(() {
            _cachedAuditLogs = logs;
          });
        }
      });
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final logs = _cachedAuditLogs ?? [];
    
    // If no logs loaded yet, return loading
    if (logs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Get unique values for filters
    final actions = ['All', ...logs.map((l) => l.action).toSet().toList()];
    final resources = ['All', ...logs.map((l) => l.resource).toSet().toList()];
    final statuses = ['All', ...logs.map((l) => l.status).toSet().toList()];

    // Apply filters including date range and search
    String searchQuery = '';
    try {
      if (_activitySearchController.text.isNotEmpty) {
        searchQuery = _activitySearchController.text.toLowerCase();
      }
    } catch (e) {
      // Controller might not be ready yet
      searchQuery = '';
    }
    var filteredLogs = logs.where((log) {
      final actionMatch =
          _selectedActionFilter == 'All' || log.action == _selectedActionFilter;
      final resourceMatch =
          _selectedResourceFilter == 'All' ||
          log.resource == _selectedResourceFilter;
      final statusMatch =
          _selectedStatusFilter == 'All' || log.status == _selectedStatusFilter;

      // Search filter
      final searchMatch = searchQuery.isEmpty ||
          (log.userName.toLowerCase().contains(searchQuery)) ||
          (log.userEmail.toLowerCase().contains(searchQuery)) ||
          (log.action.toLowerCase().contains(searchQuery)) ||
          (log.resource.toLowerCase().contains(searchQuery)) ||
          (log.description.toLowerCase().contains(searchQuery));

      // Date range filter
      bool dateMatch = true;
      if (_startDate != null) {
        final logDate = DateTime(
          log.timestamp.year,
          log.timestamp.month,
          log.timestamp.day,
        );
        final startDate = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
        );
        dateMatch =
            logDate.isAfter(startDate) || logDate.isAtSameMomentAs(startDate);
      }
      if (_endDate != null && dateMatch) {
        final logDate = DateTime(
          log.timestamp.year,
          log.timestamp.month,
          log.timestamp.day,
        );
        final endDate = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
        );
        dateMatch =
            logDate.isBefore(endDate.add(const Duration(days: 1))) ||
            logDate.isAtSameMomentAs(endDate);
      }

      return actionMatch && resourceMatch && statusMatch && dateMatch && searchMatch;
    }).toList();

    // Calculate statistics
    final totalLogs = filteredLogs.length;
    final successLogs = filteredLogs.where((l) => l.status == 'SUCCESS').length;
    final failedLogs = filteredLogs.where((l) => l.status == 'FAILED').length;
    
    // Calculate today's logs - check all logs, not just filtered ones
    final now = DateTime.now();
    final todayYear = now.year;
    final todayMonth = now.month;
    final todayDay = now.day;
    
    // Count logs from today
    int todayLogs = 0;
    for (final log in logs) {
      try {
        // Get timestamp and ensure it's in local time
        DateTime logDate = log.timestamp;
        if (logDate.isUtc) {
          logDate = logDate.toLocal();
        }
        
        // Compare year, month, and day
        if (logDate.year == todayYear &&
            logDate.month == todayMonth &&
            logDate.day == todayDay) {
          todayLogs++;
        }
      } catch (e) {
        // Skip logs with invalid timestamps
        continue;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Statistics Cards
        Row(
          children: [
            Expanded(
              child: _buildActivityStatCard(
                'Total Logs',
                totalLogs.toString(),
                Icons.history,
                const Color(0xFF090A4F),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActivityStatCard(
                'Successful',
                successLogs.toString(),
                Icons.check_circle,
                const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActivityStatCard(
                'Failed',
                failedLogs.toString(),
                Icons.error,
                const Color(0xFFFF6B6B),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActivityStatCard(
                'Today',
                todayLogs.toString(),
                Icons.today,
                const Color(0xFFFFD700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Search and Filters Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.filter_list, color: Color(0xFF090A4F), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Search & Filters',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF090A4F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Search Bar
              TextField(
                controller: _activitySearchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by user, action, resource, or description...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF090A4F)),
                  suffixIcon: Builder(
                    builder: (context) {
                      try {
                        if (_activitySearchController.text.isNotEmpty) {
                          return IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _activitySearchController.clear();
                              setState(() {});
                            },
                          );
                        }
                      } catch (e) {
                        // Controller not ready
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              // Filter Dropdowns
              Row(
                children: [
                  Expanded(
                    child: _buildFilterDropdown(
                      'Action',
                      _selectedActionFilter,
                      actions,
                      (value) {
                        setState(() => _selectedActionFilter = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFilterDropdown(
                      'Resource',
                      _selectedResourceFilter,
                      resources,
                      (value) {
                        setState(() => _selectedResourceFilter = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFilterDropdown(
                      'Status',
                      _selectedStatusFilter,
                      statuses,
                      (value) {
                        setState(() => _selectedStatusFilter = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDatePicker('Start Date', _startDate, (date) {
                      setState(() => _startDate = date);
                    }),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDatePicker('End Date', _endDate, (date) {
                      setState(() => _endDate = date);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedActionFilter = 'All';
                        _selectedResourceFilter = 'All';
                        _selectedStatusFilter = 'All';
                        _startDate = null;
                        _endDate = null;
                        try {
                          if (_activitySearchController.text.isNotEmpty) {
                            _activitySearchController.clear();
                          }
                        } catch (e) {
                          // Controller might not be ready, ignore
                        }
                      });
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reset Filters'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF090A4F),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      _showDeleteLogsDialog(logs);
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete Logs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Activity Logs List
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF090A4F),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Activity Logs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${filteredLogs.length} ${filteredLogs.length == 1 ? 'record' : 'records'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (filteredLogs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(60),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.history_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No activity logs found',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters or search query',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredLogs.length > 100 ? 100 : filteredLogs.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final log = filteredLogs[index];
                    return _buildActivityLogCard(log, index);
                  },
                ),
              if (filteredLogs.length > 100)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Showing first 100 of ${filteredLogs.length} records',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLogCard(AuditLog log, int index) {
    final isSuccess = log.status == 'SUCCESS';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFFF6B6B),
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFFF6B6B))
                  .withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFFF6B6B),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.action,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF090A4F),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFFF6B6B))
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        log.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFFF6B6B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  log.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // User Info
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: log.userRole == 'admin'
                                ? const Color(0xFFFFD700).withOpacity(0.2)
                                : const Color(0xFF2196F3).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              log.userName.isNotEmpty ? log.userName[0].toUpperCase() : 'U',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: log.userRole == 'admin'
                                    ? const Color(0xFFFFD700)
                                    : const Color(0xFF2196F3),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.userName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF090A4F),
                              ),
                            ),
                            Text(
                              log.userEmail,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Resource and Time
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF090A4F).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            log.resource,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF090A4F),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM d, yyyy HH:mm').format(log.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF090A4F),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (newValue) => onChanged(newValue ?? 'All'),
          underline: Container(height: 1, color: Colors.grey.shade300),
        ),
      ],
    );
  }


  Widget _buildDatePicker(
    String label,
    DateTime? selectedDate,
    Function(DateTime) onDateSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF090A4F),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              onDateSelected(picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Color(0xFF090A4F),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedDate != null
                        ? DateFormat('MMM d, yyyy').format(selectedDate)
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 12,
                      color: selectedDate != null
                          ? const Color(0xFF090A4F)
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
                if (selectedDate != null)
                  GestureDetector(
                    onTap: () => onDateSelected(DateTime(1900)),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showDeleteLogsDialog(List<AuditLog> allLogs) {
    DateTime? deleteBeforeDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Delete Activity Logs'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Delete all logs created before this date:'),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setDialogState(() => deleteBeforeDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Color(0xFF090A4F),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          deleteBeforeDate != null
                              ? DateFormat(
                                  'MMM d, yyyy',
                                ).format(deleteBeforeDate!)
                              : 'Select date',
                          style: TextStyle(
                            fontSize: 12,
                            color: deleteBeforeDate != null
                                ? const Color(0xFF090A4F)
                                : Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (deleteBeforeDate != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'This will delete ${allLogs.where((log) => log.timestamp.isBefore(deleteBeforeDate!)).length} logs created before ${DateFormat('MMM d, yyyy').format(deleteBeforeDate!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFFF6B6B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: deleteBeforeDate == null
                  ? null
                  : () async {
                      try {
                        final logsToDelete = allLogs
                            .where(
                              (log) =>
                                  log.timestamp.isBefore(deleteBeforeDate!),
                            )
                            .toList();
                        for (final log in logsToDelete) {
                          await _auditService.deleteAuditLog(log.id);
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Deleted ${logsToDelete.length} logs',
                            ),
                            backgroundColor: const Color(0xFF4CAF50),
                          ),
                        );
                        // Clear cache and reload
                        _cachedAuditLogs = null;
                        if (mounted) setState(() {});
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField(
    String label,
    TextEditingController controller,
    String hint, {
    bool isDate = false,
    bool isTime = false,
    bool isMultiline = false,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF090A4F),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: isDate || isTime,
          maxLines: isMultiline ? 4 : 1,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null && !isDate && !isTime && !isMultiline
                ? Icon(icon, size: 20, color: Colors.grey.shade600)
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF090A4F), width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: isDate
                ? IconButton(
                    icon: const Icon(Icons.calendar_today, size: 20),
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        controller.text = DateFormat(
                          'MM/dd/yyyy',
                        ).format(picked);
                      }
                    },
                  )
                : isTime
                ? IconButton(
                    icon: const Icon(Icons.access_time, size: 20),
                    onPressed: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        controller.text = picked.format(context);
                      }
                    },
                  )
                : null,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _themeController.dispose();
    _batchYearController.dispose();
    _eventDateController.dispose();
    _venueController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    _activitySearchController.dispose();
    super.dispose();
  }
}

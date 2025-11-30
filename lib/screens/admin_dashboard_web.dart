import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/screens/login_screen.dart';
import 'package:alumni_system/services/auth_service.dart';
import 'package:alumni_system/services/event_service.dart';
import 'package:alumni_system/models/event_model.dart';
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

  int _selectedMenuItem = 0;
  List<AlumniEvent> activeEvents = [];
  List<AlumniEvent> archivedEventsList = [];
  List<AlumniEvent> filteredEvents = [];
  bool isLoading = true;
  int totalEvents = 0;
  int expiringEvents = 0;
  int archivedEvents = 0;

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
      
      print('DEBUG: Loaded ${events.length} active events, $total total, $expiring expiring, $archived archived');
      setState(() {
        activeEvents = events;
        filteredEvents = events;
        totalEvents = total;
        expiringEvents = expiring;
        archivedEvents = archived;
        archivedEventsList = archivedList;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print('DEBUG: Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  Future<void> _loadEvents() async {
    await _loadAllData();
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
      throw Exception('Invalid date format. Please use MM/dd/yyyy format (e.g., 12/20/2025)');
    }
  }

  void _searchEvents(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredEvents = activeEvents;
      } else {
        filteredEvents = activeEvents
            .where((event) =>
                event.theme.toLowerCase().contains(query.toLowerCase()) ||
                event.batchYear.contains(query) ||
                event.venue.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event added successfully')),
      );

      await _loadEvents();
    } catch (e) {
      print('DEBUG: Error adding event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding event: $e')),
      );
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    try {
      await _eventService.deleteEvent(eventId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event deleted')),
      );
      await _loadEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting event: $e')),
      );
    }
  }

  Future<void> _archiveEvent(String eventId) async {
    try {
      await _eventService.archiveEvent(eventId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event archived')),
      );
      await _loadEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error archiving event: $e')),
      );
    }
  }

  Future<void> _restoreEvent(String eventId) async {
    try {
      await _eventService.restoreEvent(eventId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event restored')),
      );
      await _loadEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error restoring event: $e')),
      );
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
              _buildFormField('Event Theme', _themeController, 'Enter event theme'),
              const SizedBox(height: 16),
              _buildFormField('Batch Year', _batchYearController, 'Enter batch year'),
              const SizedBox(height: 16),
              _buildFormField('Event Date', _eventDateController, 'MM/DD/YYYY', isDate: true),
              const SizedBox(height: 16),
              _buildFormField('Venue', _venueController, 'Enter venue'),
              const SizedBox(height: 16),
              _buildFormField('Start Time', _startTimeController, 'HH:mm', isTime: true),
              const SizedBox(height: 16),
              _buildFormField('End Time', _endTimeController, 'HH:mm', isTime: true),
              const SizedBox(height: 16),
              _buildFormField('Description', _descriptionController, 'Enter event description', isMultiline: true),
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _buildContent(),
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
                _buildSidebarItem(4, Icons.archive, 'Archived Events'),
                _buildSidebarItem(5, Icons.work, 'Job Postings'), //NEW
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
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
        return 'Archived Events';
      default:
        return 'Dashboard';
    }
  }

  Widget _buildContent() {
    switch (_selectedMenuItem) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return _buildEventsContent();
      case 2:
        return _buildMembersContent();
      case 3:
        return _buildCommentsContent();
      case 4:
        return _buildArchivedContent();
      case 5: // ADD THIS CASE (NEW)
        return const AdminJobManagement();
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildStatCard('Total Events', totalEvents.toString(), Icons.event, const Color(0xFF1A3A52)),
            _buildStatCard('Active Events', activeEvents.length.toString(), Icons.check_circle, const Color(0xFFFFD700)),
            _buildStatCard('Expiring Soon', expiringEvents.toString(), Icons.warning, const Color(0xFFFF9800)),
            _buildStatCard('Archived Events', archivedEvents.toString(), Icons.archive, const Color(0xFF1A3A52)),
          ],
        ),
        const SizedBox(height: 32),
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF090A4F)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard('Add New Event', 'Create a new alumni event', Icons.add_circle, const Color(0xFF4CAF50), () {
                setState(() => _selectedMenuItem = 1);
              }),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildQuickActionCard('View Members', 'Manage alumni members', Icons.people, const Color(0xFF2196F3), () {
                setState(() => _selectedMenuItem = 2);
              }),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildQuickActionCard('View Comments', 'Check event comments', Icons.comment, const Color(0xFF9C27B0), () {
                setState(() => _selectedMenuItem = 3);
              }),
            ),
            const SizedBox(width: 16), //NEW
            Expanded(
              child: _buildQuickActionCard('Manage Jobs', 'Post and manage job listings', Icons.work, const Color(0xFFFF9800), () {
                setState(() => _selectedMenuItem = 5); // UPDATED INDEX
              }),
            ), //NEW
          ],
        ),
      ],
    );
  }

  Widget _buildEventsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add New Alumni Event', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF090A4F))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildFormField('Event Theme', _themeController, 'Enter event theme')),
                  const SizedBox(width: 16),
                  Expanded(child: _buildFormField('Batch Year', _batchYearController, 'Enter batch year')),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildFormField('Event Date', _eventDateController, 'MM/DD/YYYY', isDate: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildFormField('Venue', _venueController, 'Enter venue')),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildFormField('Start Time', _startTimeController, 'HH:mm', isTime: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildFormField('End Time', _endTimeController, 'HH:mm', isTime: true)),
                ],
              ),
              const SizedBox(height: 16),
              _buildFormField('Description', _descriptionController, 'Enter event description', isMultiline: true),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addEvent,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Event'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF090A4F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD700),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Active Events', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF090A4F))),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: _searchController,
                        onChanged: _searchEvents,
                        decoration: InputDecoration(
                          hintText: 'Search events...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (filteredEvents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No active events found', style: TextStyle(color: Colors.grey.shade600, fontSize: 16))),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Theme')),
                      DataColumn(label: Text('Batch Year')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Venue')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Comments')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: filteredEvents.map((event) {
                      return DataRow(
                        cells: [
                          DataCell(Text(event.theme)),
                          DataCell(Text(event.batchYear)),
                          DataCell(Text(DateFormat('MM/dd/yyyy').format(event.date))),
                          DataCell(Text(event.venue)),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFFFD700), borderRadius: BorderRadius.circular(4)),
                            child: const Text('Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF090A4F))),
                          )),
                          DataCell(Text(event.comments.toString())),
                          DataCell(PopupMenuButton(
                            itemBuilder: (context) => [
                              PopupMenuItem(child: const Text('Edit'), onTap: () => _editEvent(event)),
                              PopupMenuItem(child: const Text('Archive'), onTap: () => _archiveEvent(event.id)),
                              PopupMenuItem(child: const Text('Delete'), onTap: () => _deleteEvent(event.id)),
                            ],
                            child: const Icon(Icons.more_vert),
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMembersContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Alumni Members Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF090A4F))),
          const SizedBox(height: 20),
          Center(child: Text('Members management feature coming soon', style: TextStyle(color: Colors.grey.shade600, fontSize: 16))),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Comments Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF090A4F))),
          const SizedBox(height: 20),
          Center(child: Text('Comments management feature coming soon', style: TextStyle(color: Colors.grey.shade600, fontSize: 16))),
        ],
      ),
    );
  }

  Widget _buildArchivedContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1A3A52),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Archived Events', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('${archivedEventsList.length} events', style: const TextStyle(fontSize: 14, color: Colors.white70)),
              ],
            ),
          ),
          if (archivedEventsList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('No archived events', style: TextStyle(color: Colors.grey.shade600, fontSize: 16))),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Theme')),
                  DataColumn(label: Text('Batch Year')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Venue')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Comments')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: archivedEventsList.map((event) {
                  return DataRow(
                    cells: [
                      DataCell(Text(event.theme)),
                      DataCell(Text(event.batchYear)),
                      DataCell(Text(DateFormat('MM/dd/yyyy').format(event.date))),
                      DataCell(Text(event.venue)),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(4)),
                        child: const Text('Archived', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      )),
                      DataCell(Text(event.comments.toString())),
                      DataCell(PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(child: const Text('Restore'), onTap: () => _restoreEvent(event.id)),
                          PopupMenuItem(child: const Text('Delete'), onTap: () => _deleteEvent(event.id)),
                        ],
                        child: const Icon(Icons.more_vert),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              Icon(icon, color: Colors.white, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF090A4F))),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField(String label, TextEditingController controller, String hint, {bool isDate = false, bool isTime = false, bool isMultiline = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF090A4F))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: isDate || isTime,
          maxLines: isMultiline ? 4 : 1,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            suffixIcon: isDate
                ? IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        controller.text = DateFormat('MM/dd/yyyy').format(picked);
                      }
                    },
                  )
                : isTime
                    ? IconButton(
                        icon: const Icon(Icons.access_time),
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
    super.dispose();
  }
}


import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/models/event_model.dart';
import 'package:alumni_system/services/event_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final TextEditingController _themeController = TextEditingController();
  final TextEditingController _batchYearController = TextEditingController();
  final TextEditingController _eventDateController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final EventService _eventService = EventService();
  List<AlumniEvent> activeEvents = [];
  List<AlumniEvent> filteredEvents = [];
  bool isLoading = true;
  int totalEvents = 0;
  int expiringEvents = 0;
  int archivedEvents = 0;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      setState(() => isLoading = true);
      final events = await _eventService.getActiveEvents();
      setState(() {
        activeEvents = events;
        filteredEvents = events;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading events: $e')),
      );
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
        _venueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
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
      );

      await _eventService.addEvent(newEvent);
      
      _themeController.clear();
      _batchYearController.clear();
      _eventDateController.clear();
      _venueController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event added successfully')),
      );

      // Reload events to get the updated list
      await _loadEvents();
      
      // Close the dialog if open
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A4F),
        elevation: 0,
        title: Row(
          children: [
            const Icon(
              Icons.school,
              color: Color(0xFFFFD700),
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text(
              'Alumni Portal',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.people,
                  color: Color(0xFF090A4F),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Users',
                  style: TextStyle(
                    color: Color(0xFF090A4F),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.person,
                  color: Color(0xFFFFD700),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Welcome, admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // Sidebar and Main Content
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sidebar
                Container(
                  width: 200,
                  color: const Color(0xFF090A4F),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSidebarItem(
                              Icons.dashboard,
                              'Dashboard',
                              true,
                            ),
                            const SizedBox(height: 16),
                            _buildSidebarItem(
                              Icons.archive,
                              'Archived Events',
                              false,
                              badge: '1',
                            ),
                            const SizedBox(height: 16),
                            _buildSidebarItem(
                              Icons.comment,
                              'Comments',
                              false,
                            ),
                            const SizedBox(height: 16),
                            _buildSidebarItem(
                              Icons.people,
                              'Alumni Members',
                              false,
                            ),
                            const SizedBox(height: 16),
                            _buildSidebarItem(
                              Icons.logout,
                              'Logout',
                              false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Main Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Alumni Events Dashboard',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF090A4F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 4,
                              width: 270,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Content Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Add New Event Form
                            Expanded(
                              flex: 1,
                              child: _buildAddEventForm(),
                            ),
                            const SizedBox(width: 24),
                            // Active Events Table
                            Expanded(
                              flex: 2,
                              child: _buildActiveEventsTable(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Stats Cards
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            _buildStatCard(
                              'Total Events',
                              totalEvents.toString(),
                              Icons.event,
                              const Color(0xFF1A3A52),
                            ),
                            const SizedBox(width: 16),
                            _buildStatCard(
                              'Active Events',
                              activeEvents.length.toString(),
                              Icons.check_circle,
                              const Color(0xFFFFD700),
                            ),
                            const SizedBox(width: 16),
                            _buildStatCard(
                              'Expiring Soon',
                              expiringEvents.toString(),
                              Icons.warning,
                              const Color(0xFFFFD700),
                            ),
                            const SizedBox(width: 16),
                            _buildStatCard(
                              'Archived Events',
                              archivedEvents.toString(),
                              Icons.archive,
                              const Color(0xFF1A3A52),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String label,
    bool isActive, {
    String? badge,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFFD700) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF090A4F) : Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF090A4F) : Colors.white,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddEventForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add New Alumni Event',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF090A4F),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Event Theme',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF090A4F),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _themeController,
            decoration: InputDecoration(
              hintText: 'Enter event theme',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Batch Year',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF090A4F),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _batchYearController,
            decoration: InputDecoration(
              hintText: 'Enter batch year',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Event Date',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF090A4F),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _eventDateController,
                  decoration: InputDecoration(
                    hintText: 'mm/dd/yyyy',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    _eventDateController.text =
                        DateFormat('MM/dd/yyyy').format(picked);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Venue',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF090A4F),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _venueController,
            decoration: InputDecoration(
              hintText: 'Enter venue',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addEvent,
              icon: const Icon(Icons.add),
              label: const Text('Add Event'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3A52),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveEventsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFFD700),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Text(
              'Active Events',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF090A4F),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _searchEvents,
                        decoration: InputDecoration(
                          hintText: 'Search events by theme, batch, venue...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        _searchController.clear();
                        _searchEvents('');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A3A52),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Table Header
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildTableHeader('Theme'),
                      ),
                      Expanded(
                        flex: 1,
                        child: _buildTableHeader('Batch Year'),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildTableHeader('Date'),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildTableHeader('Venue'),
                      ),
                      Expanded(
                        flex: 1,
                        child: _buildTableHeader('Status'),
                      ),
                      Expanded(
                        flex: 1,
                        child: _buildTableHeader('Comments'),
                      ),
                      Expanded(
                        flex: 1,
                        child: _buildTableHeader('Actions'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Table Body
                if (filteredEvents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No active events found',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else
                  Column(
                    children: filteredEvents.map((event) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  event.theme,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  event.batchYear,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  DateFormat('MM/dd/yyyy').format(event.date),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  event.venue,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD700),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    event.status,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF090A4F),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  event.comments.toString(),
                                  style: const TextStyle(fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: PopupMenuButton(
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      child: const Text('Edit'),
                                      onTap: () {
                                        // Edit functionality
                                      },
                                    ),
                                    PopupMenuItem(
                                      child: const Text('Archive'),
                                      onTap: () {
                                        _archiveEvent(event.id);
                                      },
                                    ),
                                    PopupMenuItem(
                                      child: const Text('Delete'),
                                      onTap: () {
                                        _deleteEvent(event.id);
                                      },
                                    ),
                                  ],
                                  child: const Icon(Icons.more_vert),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Color(0xFF090A4F),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color backgroundColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _themeController.dispose();
    _batchYearController.dispose();
    _eventDateController.dispose();
    _venueController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}


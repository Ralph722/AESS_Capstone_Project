import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/models/alumni_member_model.dart';
import 'package:alumni_system/services/alumni_member_service.dart';
import 'package:alumni_system/services/audit_service.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:html' as html;

class AdminAlumniMembersScreen extends StatefulWidget {
  const AdminAlumniMembersScreen({super.key});

  @override
  State<AdminAlumniMembersScreen> createState() => _AdminAlumniMembersScreenState();
}

class _AdminAlumniMembersScreenState extends State<AdminAlumniMembersScreen> {
  final AlumniMemberService _memberService = AlumniMemberService();
  final AuditService _auditService = AuditService();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _batchYearController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _linkedInController = TextEditingController();
  final TextEditingController _currentPositionController = TextEditingController();
  final TextEditingController _currentCompanyController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  List<AlumniMember> _allMembers = [];
  List<AlumniMember> _filteredMembers = [];
  List<AlumniMember> _displayedMembers = [];
  String? _selectedBatchFilter;
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isSubmitting = false;
  
  // Statistics
  int _totalMembers = 0;
  Map<String, int> _batchCounts = {};

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      setState(() => _isLoading = true);
      final members = await _memberService.getAllMembers();
      final batchYears = await _memberService.getBatchYears();
      
      // Calculate batch counts
      final batchCounts = <String, int>{};
      for (final batch in batchYears) {
        batchCounts[batch] = await _memberService.getMemberCountByBatch(batch);
      }

      setState(() {
        _allMembers = members;
        _filteredMembers = members;
        _displayedMembers = members;
        _totalMembers = members.length;
        _batchCounts = batchCounts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading members: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  void _filterMembers() {
    setState(() {
      _filteredMembers = _allMembers.where((member) {
        // Search filter
        final matchesSearch = _searchQuery.isEmpty ||
            member.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            member.emailAddress.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            member.course.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            member.batchYear.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            member.contactNumber.contains(_searchQuery);

        // Batch filter
        final matchesBatch = _selectedBatchFilter == null ||
            member.batchYear == _selectedBatchFilter;

        return matchesSearch && matchesBatch;
      }).toList();

      // Group by batch for display
      if (_selectedBatchFilter == null) {
        _displayedMembers = _filteredMembers;
      } else {
        _displayedMembers = _filteredMembers;
      }

    });
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _filterMembers();
  }

  void _onBatchFilterChanged(String? batch) {
    setState(() => _selectedBatchFilter = batch);
    _filterMembers();
  }

  Future<void> _submitForm() async {
    if (_fullNameController.text.trim().isEmpty ||
        _batchYearController.text.trim().isEmpty ||
        _courseController.text.trim().isEmpty ||
        _contactNumberController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Color(0xFFFF6B6B),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
        final member = AlumniMember(
        id: '',
        fullName: _fullNameController.text.trim(),
        batchYear: _batchYearController.text.trim(),
        course: _courseController.text.trim(),
        contactNumber: _contactNumberController.text.trim(),
        emailAddress: _emailController.text.trim(),
        linkedInUrl: _linkedInController.text.trim().isEmpty
            ? null
            : _linkedInController.text.trim(),
        currentPosition: _currentPositionController.text.trim().isEmpty
            ? null
            : _currentPositionController.text.trim(),
        currentCompany: _currentCompanyController.text.trim().isEmpty
            ? null
            : _currentCompanyController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        createdAt: DateTime.now(),
      );

      await _memberService.createMember(member);
      await _auditService.logAction(
        action: 'CREATE_MEMBER',
        resource: 'AlumniMember',
        resourceId: member.id,
        description: 'Created new alumni member: ${member.fullName}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Member added successfully'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );

      _clearForm();
      await _loadMembers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFFF6B6B),
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _clearForm() {
    _fullNameController.clear();
    _batchYearController.clear();
    _courseController.clear();
    _contactNumberController.clear();
    _emailController.clear();
    _linkedInController.clear();
    _currentPositionController.clear();
    _currentCompanyController.clear();
    _addressController.clear();
  }

  void _editMember(AlumniMember member) {
    // Create separate controllers for edit dialog
    final fullNameController = TextEditingController(text: member.fullName);
    final batchYearController = TextEditingController(text: member.batchYear);
    final courseController = TextEditingController(text: member.course);
    final contactNumberController = TextEditingController(text: member.contactNumber);
    final emailController = TextEditingController(text: member.emailAddress);
    final linkedInController = TextEditingController(text: member.linkedInUrl ?? '');
    final currentPositionController = TextEditingController(text: member.currentPosition ?? '');
    final currentCompanyController = TextEditingController(text: member.currentCompany ?? '');
    final addressController = TextEditingController(text: member.address ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit, color: Color(0xFF090A4F)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Edit Alumni Member',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF090A4F),
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormField(
                    controller: fullNameController,
                    label: 'Full Name',
                    icon: Icons.person,
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    controller: batchYearController,
                    label: 'Batch Year',
                    icon: Icons.calendar_today,
                    hint: 'e.g. 2022-2023',
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    controller: courseController,
                    label: 'Course',
                    icon: Icons.school,
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    controller: contactNumberController,
                    label: 'Contact Number',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    controller: emailController,
                    label: 'Email Address',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    required: true,
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Additional Information (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF090A4F),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    controller: currentPositionController,
                    label: 'Current Position',
                    icon: Icons.work_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    controller: currentCompanyController,
                    label: 'Current Company',
                    icon: Icons.business,
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    controller: addressController,
                    label: 'Address',
                    icon: Icons.location_on,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    controller: linkedInController,
                    label: 'LinkedIn URL',
                    icon: Icons.link,
                    keyboardType: TextInputType.url,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () {
                      fullNameController.dispose();
                      batchYearController.dispose();
                      courseController.dispose();
                      contactNumberController.dispose();
                      emailController.dispose();
                      linkedInController.dispose();
                      currentPositionController.dispose();
                      currentCompanyController.dispose();
                      addressController.dispose();
                      Navigator.pop(context);
                    },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF090A4F)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (fullNameController.text.trim().isEmpty ||
                          batchYearController.text.trim().isEmpty ||
                          courseController.text.trim().isEmpty ||
                          contactNumberController.text.trim().isEmpty ||
                          emailController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill in all required fields'),
                            backgroundColor: Color(0xFFFF6B6B),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      try {
                        final updatedMember = AlumniMember(
                          id: member.id,
                          fullName: fullNameController.text.trim(),
                          batchYear: batchYearController.text.trim(),
                          course: courseController.text.trim(),
                          contactNumber: contactNumberController.text.trim(),
                          emailAddress: emailController.text.trim(),
                          linkedInUrl: linkedInController.text.trim().isEmpty
                              ? null
                              : linkedInController.text.trim(),
                          currentPosition: currentPositionController.text.trim().isEmpty
                              ? null
                              : currentPositionController.text.trim(),
                          currentCompany: currentCompanyController.text.trim().isEmpty
                              ? null
                              : currentCompanyController.text.trim(),
                          address: addressController.text.trim().isEmpty
                              ? null
                              : addressController.text.trim(),
                          createdAt: member.createdAt,
                        );

                        await _memberService.updateMember(updatedMember);
                        await _auditService.logAction(
                          action: 'UPDATE_MEMBER',
                          resource: 'AlumniMember',
                          resourceId: updatedMember.id,
                          description: 'Updated alumni member: ${updatedMember.fullName}',
                        );

                        fullNameController.dispose();
                        batchYearController.dispose();
                        courseController.dispose();
                        contactNumberController.dispose();
                        emailController.dispose();
                        linkedInController.dispose();
                        currentPositionController.dispose();
                        currentCompanyController.dispose();
                        addressController.dispose();

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Member updated successfully'),
                              backgroundColor: Color(0xFF4CAF50),
                            ),
                          );
                        }
                        await _loadMembers();
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: const Color(0xFFFF6B6B),
                            ),
                          );
                        }
                      }
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.update, size: 18),
              label: Text(isSubmitting ? 'Updating...' : 'Update Member'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF090A4F),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMember(AlumniMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Member'),
        content: Text('Are you sure you want to delete ${member.fullName}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _memberService.deleteMember(member.id);
        await _auditService.logAction(
          action: 'DELETE_MEMBER',
          resource: 'AlumniMember',
          resourceId: member.id,
          description: 'Deleted alumni member: ${member.fullName}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Member deleted successfully'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
        await _loadMembers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting member: $e'),
              backgroundColor: const Color(0xFFFF6B6B),
            ),
          );
        }
      }
    }
  }

  void _viewMemberDetails(AlumniMember member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF090A4F), Color(0xFF1A237E)],
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: Text(
                  member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                member.fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF090A4F),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Batch Year', member.batchYear),
              _buildDetailRow('Course', member.course),
              _buildDetailRow('Email', member.emailAddress),
              _buildDetailRow('Contact', member.contactNumber),
              if (member.currentPosition != null)
                _buildDetailRow('Position', member.currentPosition!),
              if (member.currentCompany != null)
                _buildDetailRow('Company', member.currentCompany!),
              if (member.address != null)
                _buildDetailRow('Address', member.address!),
              if (member.linkedInUrl != null)
                _buildDetailRow('LinkedIn', member.linkedInUrl!),
              const SizedBox(height: 8),
              Text(
                'Joined: ${DateFormat('MMM d, yyyy').format(member.createdAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _editMember(member);
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF090A4F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF090A4F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel() async {
    try {
      final excel = Excel.createExcel();
      excel.delete('Sheet1');
      final sheet = excel['Alumni Members'];

      // Headers
      sheet.appendRow([
        'Full Name',
        'Batch Year',
        'Course',
        'Email',
        'Contact Number',
        'Current Position',
        'Current Company',
        'Address',
        'LinkedIn',
        'Date Joined',
      ]);

      // Data rows
      for (final member in _filteredMembers) {
        sheet.appendRow([
          member.fullName,
          member.batchYear,
          member.course,
          member.emailAddress,
          member.contactNumber,
          member.currentPosition ?? '',
          member.currentCompany ?? '',
          member.address ?? '',
          member.linkedInUrl ?? '',
          DateFormat('yyyy-MM-dd').format(member.createdAt),
        ]);
      }

      // Save file
      final bytes = excel.save();
      if (bytes != null) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', 'alumni_members_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx')
          ..click();
        html.Url.revokeObjectUrl(url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Members exported successfully'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _batchYearController.dispose();
    _courseController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _searchController.dispose();
    _linkedInController.dispose();
    _currentPositionController.dispose();
    _currentCompanyController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Group members by batch
    final Map<String, List<AlumniMember>> membersByBatch = {};
    for (final member in _displayedMembers) {
      if (!membersByBatch.containsKey(member.batchYear)) {
        membersByBatch[member.batchYear] = [];
      }
      membersByBatch[member.batchYear]!.add(member);
    }

    // Sort batches
    final sortedBatches = membersByBatch.keys.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Cards
          Container(
            width: 400,
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Members',
                    _totalMembers.toString(),
                    Icons.people,
                    const Color(0xFF090A4F),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'All Batches',
                    _batchCounts.length.toString(),
                    Icons.school,
                    const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Main Content - Two Column Layout
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Panel - Add/Edit Form
                Container(
                  width: 400,
                  margin: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFFD700),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Form Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFD700),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(14),
                            topRight: Radius.circular(14),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_add,
                              color: Color(0xFF090A4F),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Add Alumni Member',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF090A4F),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Form Content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFormField(
                                controller: _fullNameController,
                                label: 'Full Name',
                                icon: Icons.person,
                                required: true,
                              ),
                              const SizedBox(height: 16),
                              _buildFormField(
                                controller: _batchYearController,
                                label: 'Batch Year',
                                icon: Icons.calendar_today,
                                hint: 'e.g. 2022-2023',
                                required: true,
                              ),
                              const SizedBox(height: 16),
                              _buildFormField(
                                controller: _courseController,
                                label: 'Course',
                                icon: Icons.school,
                                required: true,
                              ),
                              const SizedBox(height: 16),
                              _buildFormField(
                                controller: _contactNumberController,
                                label: 'Contact Number',
                                icon: Icons.phone,
                                keyboardType: TextInputType.phone,
                                required: true,
                              ),
                              const SizedBox(height: 16),
                              _buildFormField(
                                controller: _emailController,
                                label: 'Email Address',
                                icon: Icons.email,
                                keyboardType: TextInputType.emailAddress,
                                required: true,
                              ),
                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 16),
                              const Text(
                                'Additional Information (Optional)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF090A4F),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildFormField(
                                controller: _currentPositionController,
                                label: 'Current Position',
                                icon: Icons.work_outline,
                              ),
                              const SizedBox(height: 16),
                              _buildFormField(
                                controller: _currentCompanyController,
                                label: 'Current Company',
                                icon: Icons.business,
                              ),
                              const SizedBox(height: 16),
                              _buildFormField(
                                controller: _addressController,
                                label: 'Address',
                                icon: Icons.location_on,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 16),
                              _buildFormField(
                                controller: _linkedInController,
                                label: 'LinkedIn URL',
                                icon: Icons.link,
                                keyboardType: TextInputType.url,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isSubmitting ? null : _submitForm,
                                  icon: _isSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Icon(Icons.add),
                                  label: Text(
                                    _isSubmitting ? 'Processing...' : 'Add Member',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF090A4F),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Right Panel - Members List
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF090A4F),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFF090A4F),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.people,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Alumni Members per Batch',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.file_download, color: Colors.white),
                                    onPressed: _exportToExcel,
                                    tooltip: 'Export to Excel',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Search and Filter
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: TextField(
                                        controller: _searchController,
                                        onChanged: _onSearchChanged,
                                        decoration: InputDecoration(
                                          hintText: 'Search by name, email, course, or batch...',
                                          prefixIcon: const Icon(Icons.search, color: Color(0xFF090A4F)),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: DropdownButton<String>(
                                      value: _selectedBatchFilter,
                                      hint: const Text('All Batches'),
                                      underline: const SizedBox(),
                                      items: [
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('All Batches'),
                                        ),
                                        ..._batchCounts.keys.map((batch) {
                                          return DropdownMenuItem<String>(
                                            value: batch,
                                            child: Text('$batch (${_batchCounts[batch]})'),
                                          );
                                        }),
                                      ],
                                      onChanged: _onBatchFilterChanged,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Members List
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _displayedMembers.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.people_outline,
                                            size: 64,
                                            color: Colors.grey.shade300,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            _searchQuery.isNotEmpty || _selectedBatchFilter != null
                                                ? 'No members found'
                                                : 'No alumni members added yet',
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _searchQuery.isNotEmpty || _selectedBatchFilter != null
                                                ? 'Try adjusting your search or filters'
                                                : 'Add your first member using the form on the left',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(20),
                                      itemCount: sortedBatches.length,
                                      itemBuilder: (context, batchIndex) {
                                        final batch = sortedBatches[batchIndex];
                                        final members = membersByBatch[batch]!;
                                        return _buildBatchSection(batch, members);
                                      },
                                    ),
                        ),
                      ],
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF090A4F)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF090A4F),
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
      ],
    );
  }

  Widget _buildBatchSection(String batchYear, List<AlumniMember> members) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF090A4F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.school,
                  color: Color(0xFF090A4F),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Batch $batchYear',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF090A4F),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090A4F),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${members.length} ${members.length == 1 ? 'member' : 'members'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...members.map((member) => _buildMemberCard(member)),
        ],
      ),
    );
  }

  Widget _buildMemberCard(AlumniMember member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF090A4F), Color(0xFF1A237E)],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(
              child: Text(
                member.fullName.isNotEmpty
                    ? member.fullName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Member Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF090A4F),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.school, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      member.course,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.email, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        member.emailAddress,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (member.currentPosition != null || member.currentCompany != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.work, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${member.currentPosition ?? ''}${member.currentPosition != null && member.currentCompany != null ? ' at ' : ''}${member.currentCompany ?? ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, color: Color(0xFF090A4F)),
                onPressed: () => _viewMemberDetails(member),
                tooltip: 'View Details',
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFF2196F3)),
                onPressed: () => _editMember(member),
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Color(0xFFFF6B6B)),
                onPressed: () => _deleteMember(member),
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }
}


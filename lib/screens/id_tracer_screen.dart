import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alumni_system/services/id_tracer_service.dart';
import 'package:alumni_system/models/id_tracer_model.dart';
import 'package:alumni_system/services/audit_service.dart';
import 'package:intl/intl.dart';

class IdTracerScreen extends StatefulWidget {
  const IdTracerScreen({super.key});

  @override
  State<IdTracerScreen> createState() => _IdTracerScreenState();
}

class _IdTracerScreenState extends State<IdTracerScreen> {
  final _formKey = GlobalKey<FormState>();
  final IdTracerService _idTracerService = IdTracerService();
  final AuditService _auditService = AuditService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isLoadingData = true;
  EmploymentRecord? _existingRecord;

  String _employmentStatus = 'Employed';
  final _monthsUnemployedController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _schoolIdController = TextEditingController();

  // Enhanced fields
  final _companyNameController = TextEditingController();
  final _positionController = TextEditingController();
  final _industryController = TextEditingController();
  final _salaryRangeController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _countryController = TextEditingController();

  String? _employmentType;
  DateTime? _startDate;

  final List<String> _employmentTypes = [
    'Full-time',
    'Part-time',
    'Contract',
    'Freelance',
    'Self-employed',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadExistingRecord();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _emailController.text = user.email ?? '';
      });

      // Try to get user data from Firestore
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          setState(() {
            if (data['contactNumber'] != null) {
              _contactNumberController.text = data['contactNumber'];
            }
            if (data['schoolId'] != null) {
              _schoolIdController.text = data['schoolId'];
            }
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
      }
    }
  }

  Future<void> _loadExistingRecord() async {
    try {
      setState(() => _isLoadingData = true);
      final record = await _idTracerService.getCurrentUserRecord();

      if (record != null && mounted) {
        setState(() {
          _existingRecord = record;
          _employmentStatus = record.employmentStatus;
          _monthsUnemployedController.text =
              record.monthsUnemployed?.toString() ?? '';
          _emailController.text = record.userEmail;
          _contactNumberController.text = record.contactNumber;
          _schoolIdController.text = record.schoolId;
          _companyNameController.text = record.companyName ?? '';
          _positionController.text = record.position ?? '';
          _industryController.text = record.industry ?? '';
          _employmentType = record.employmentType;
          _startDate = record.startDate;
          _salaryRangeController.text = record.salaryRange ?? '';
          _cityController.text = record.city ?? '';
          _provinceController.text = record.province ?? '';
          _countryController.text = record.country ?? '';
        });
      }
    } catch (e) {
      print('Error loading existing record: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  @override
  void dispose() {
    _monthsUnemployedController.dispose();
    _emailController.dispose();
    _contactNumberController.dispose();
    _schoolIdController.dispose();
    _companyNameController.dispose();
    _positionController.dispose();
    _industryController.dispose();
    _salaryRangeController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFFFFD700), size: 28),
              const SizedBox(width: 8),
              const Text(
                'ID Tracer',
                style: TextStyle(
                  color: Color(0xFF090A4F),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.search, color: Color(0xFFFFD700), size: 28),
            const SizedBox(width: 8),
            const Text(
              'ID Tracer',
              style: TextStyle(
                color: Color(0xFF090A4F),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          if (_existingRecord != null)
            IconButton(
              icon: const Icon(Icons.visibility, color: Color(0xFF090A4F)),
              onPressed: _showMySubmission,
              tooltip: 'View My Submission',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF090A4F), width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner if existing record
                  if (_existingRecord != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You have a previous submission. Updating will replace your existing record.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Employment Status
                  const Text(
                    'Employment Status *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF090A4F),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildRadioOption('Employed', 'Employed'),
                      const SizedBox(width: 24),
                      _buildRadioOption('Unemployed', 'Unemployed'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Months Unemployed (only show if Unemployed)
                  if (_employmentStatus == 'Unemployed') ...[
                    _buildTextField(
                      controller: _monthsUnemployedController,
                      label: 'Months unemployed',
                      icon: Icons.calendar_today,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter months unemployed';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Employment Details (only show if Employed)
                  if (_employmentStatus == 'Employed') ...[
                    const Text(
                      'Employment Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF090A4F),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _companyNameController,
                      label: 'Company Name',
                      icon: Icons.business,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _positionController,
                      label: 'Position/Job Title',
                      icon: Icons.work,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _industryController,
                      label: 'Industry',
                      icon: Icons.domain,
                    ),
                    const SizedBox(height: 16),
                    _buildDropdownField(
                      label: 'Employment Type',
                      icon: Icons.access_time,
                      value: _employmentType,
                      items: _employmentTypes,
                      onChanged: (value) {
                        setState(() {
                          _employmentType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDateField(
                      label: 'Start Date',
                      icon: Icons.calendar_today,
                      value: _startDate,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() {
                            _startDate = date;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _salaryRangeController,
                      label: 'Salary Range (Optional)',
                      icon: Icons.attach_money,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF090A4F),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _cityController,
                      label: 'City',
                      icon: Icons.location_city,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _provinceController,
                      label: 'Province',
                      icon: Icons.map,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _countryController,
                      label: 'Country',
                      icon: Icons.public,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Contact Information
                  const Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF090A4F),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email *',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _contactNumberController,
                    label: 'Contact Number *',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your contact number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _schoolIdController,
                    label: 'School ID Number *',
                    icon: Icons.badge,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your school ID';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF090A4F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            disabledBackgroundColor: Colors.grey.shade300,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Submit',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleClear,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: const Color(0xFF090A4F),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            disabledBackgroundColor: Colors.grey.shade300,
                          ),
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Please log in to submit your employment record.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final record = EmploymentRecord(
        id:
            _existingRecord?.id ??
            _firestore.collection('employment_records').doc().id,
        userId: user.uid,
        userName: user.displayName ?? 'Unknown',
        userEmail: _emailController.text.trim(),
        schoolId: _schoolIdController.text.trim(),
        employmentStatus: _employmentStatus,
        monthsUnemployed:
            _employmentStatus == 'Unemployed' &&
                _monthsUnemployedController.text.isNotEmpty
            ? int.tryParse(_monthsUnemployedController.text)
            : null,
        companyName:
            _employmentStatus == 'Employed' &&
                _companyNameController.text.isNotEmpty
            ? _companyNameController.text.trim()
            : null,
        position:
            _employmentStatus == 'Employed' &&
                _positionController.text.isNotEmpty
            ? _positionController.text.trim()
            : null,
        industry:
            _employmentStatus == 'Employed' &&
                _industryController.text.isNotEmpty
            ? _industryController.text.trim()
            : null,
        employmentType: _employmentStatus == 'Employed'
            ? _employmentType
            : null,
        startDate: _employmentStatus == 'Employed' ? _startDate : null,
        salaryRange:
            _employmentStatus == 'Employed' &&
                _salaryRangeController.text.isNotEmpty
            ? _salaryRangeController.text.trim()
            : null,
        city: _cityController.text.isNotEmpty
            ? _cityController.text.trim()
            : null,
        province: _provinceController.text.isNotEmpty
            ? _provinceController.text.trim()
            : null,
        country: _countryController.text.isNotEmpty
            ? _countryController.text.trim()
            : null,
        contactNumber: _contactNumberController.text.trim(),
        submittedAt: _existingRecord?.submittedAt ?? DateTime.now(),
        verificationStatus: 'Pending',
      );

      await _idTracerService.submitEmploymentRecord(record);

      // Log the action
      await _auditService.logAction(
        action: _existingRecord != null
            ? 'UPDATE_EMPLOYMENT_RECORD'
            : 'SUBMIT_EMPLOYMENT_RECORD',
        resource: 'EmploymentRecord',
        resourceId: record.id,
        description:
            '${_existingRecord != null ? 'Updated' : 'Submitted'} employment record: ${record.employmentStatus}',
        status: 'SUCCESS',
      );

      if (mounted) {
        _showSuccess(
          'Employment record ${_existingRecord != null ? 'updated' : 'submitted'} successfully!',
        );
        await _loadExistingRecord();
      }
    } catch (e) {
      if (mounted) {
        _showError('Error submitting record: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleClear() {
    setState(() {
      _monthsUnemployedController.clear();
      _companyNameController.clear();
      _positionController.clear();
      _industryController.clear();
      _employmentType = null;
      _startDate = null;
      _salaryRangeController.clear();
      _cityController.clear();
      _provinceController.clear();
      _countryController.clear();
      _employmentStatus = 'Employed';
    });
    _formKey.currentState?.reset();
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildRadioOption(String value, String label) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _employmentStatus = value;
          // Clear employment-specific fields when switching to Unemployed
          if (value == 'Unemployed') {
            _companyNameController.clear();
            _positionController.clear();
            _industryController.clear();
            _employmentType = null;
            _startDate = null;
            _salaryRangeController.clear();
          }
        });
      },
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              border: Border.all(
                color: _employmentStatus == value
                    ? const Color(0xFF090A4F)
                    : Colors.grey,
                width: 2,
              ),
              color: _employmentStatus == value
                  ? const Color(0xFF090A4F)
                  : Colors.transparent,
            ),
            child: _employmentStatus == value
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: _employmentStatus == value
                  ? const Color(0xFF090A4F)
                  : Colors.grey,
              fontWeight: _employmentStatus == value
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey),
          border: InputBorder.none,
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required IconData icon,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value != null
                    ? DateFormat('MMM d, yyyy').format(value)
                    : 'Select date',
                style: TextStyle(
                  fontSize: 16,
                  color: value != null ? Colors.black87 : Colors.grey,
                ),
              ),
            ),
            Icon(Icons.calendar_today, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  void _showMySubmission() {
    if (_existingRecord == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.assignment, color: Color(0xFF090A4F)),
            const SizedBox(width: 8),
            const Text('My Employment Record'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Verification Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _existingRecord!.verificationStatus == 'Verified'
                      ? Colors.green.shade100
                      : _existingRecord!.verificationStatus == 'Rejected'
                      ? Colors.red.shade100
                      : Colors.yellow.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _existingRecord!.verificationStatus == 'Verified'
                          ? Icons.check_circle
                          : _existingRecord!.verificationStatus == 'Rejected'
                          ? Icons.cancel
                          : Icons.pending,
                      color: _existingRecord!.verificationStatus == 'Verified'
                          ? Colors.green.shade700
                          : _existingRecord!.verificationStatus == 'Rejected'
                          ? Colors.red.shade700
                          : Colors.yellow.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Status: ${_existingRecord!.verificationStatus}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _existingRecord!.verificationStatus == 'Verified'
                            ? Colors.green.shade700
                            : _existingRecord!.verificationStatus == 'Rejected'
                            ? Colors.red.shade700
                            : Colors.yellow.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildDetailRow(
                'Employment Status',
                _existingRecord!.employmentStatus,
              ),
              if (_existingRecord!.employmentStatus == 'Unemployed' &&
                  _existingRecord!.monthsUnemployed != null)
                _buildDetailRow(
                  'Months Unemployed',
                  _existingRecord!.monthsUnemployed.toString(),
                ),
              if (_existingRecord!.employmentStatus == 'Employed') ...[
                if (_existingRecord!.companyName != null)
                  _buildDetailRow('Company', _existingRecord!.companyName!),
                if (_existingRecord!.position != null)
                  _buildDetailRow('Position', _existingRecord!.position!),
                if (_existingRecord!.industry != null)
                  _buildDetailRow('Industry', _existingRecord!.industry!),
                if (_existingRecord!.employmentType != null)
                  _buildDetailRow(
                    'Employment Type',
                    _existingRecord!.employmentType!,
                  ),
                if (_existingRecord!.startDate != null)
                  _buildDetailRow(
                    'Start Date',
                    DateFormat(
                      'MMM d, yyyy',
                    ).format(_existingRecord!.startDate!),
                  ),
                if (_existingRecord!.salaryRange != null)
                  _buildDetailRow(
                    'Salary Range',
                    _existingRecord!.salaryRange!,
                  ),
              ],
              if (_existingRecord!.city != null ||
                  _existingRecord!.province != null ||
                  _existingRecord!.country != null)
                _buildDetailRow(
                  'Location',
                  [
                    _existingRecord!.city,
                    _existingRecord!.province,
                    _existingRecord!.country,
                  ].where((e) => e != null && e.isNotEmpty).join(', '),
                ),
              _buildDetailRow('Email', _existingRecord!.userEmail),
              _buildDetailRow('Contact Number', _existingRecord!.contactNumber),
              _buildDetailRow('School ID', _existingRecord!.schoolId),
              const Divider(height: 24),
              _buildDetailRow(
                'Submitted',
                DateFormat(
                  'MMM d, yyyy HH:mm',
                ).format(_existingRecord!.submittedAt),
              ),
              _buildDetailRow(
                'Last Updated',
                DateFormat(
                  'MMM d, yyyy HH:mm',
                ).format(_existingRecord!.lastUpdated),
              ),
              if (_existingRecord!.verifiedAt != null)
                _buildDetailRow(
                  'Verified At',
                  DateFormat(
                    'MMM d, yyyy HH:mm',
                  ).format(_existingRecord!.verifiedAt!),
                ),
              if (_existingRecord!.notes != null &&
                  _existingRecord!.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin Notes:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF090A4F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(_existingRecord!.notes!),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Scroll to top of form
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF090A4F),
            ),
            child: const Text('Edit Record'),
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
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF090A4F),
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

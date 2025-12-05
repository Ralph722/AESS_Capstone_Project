// add_job_dialog.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:alumni_system/services/job_service.dart';
import 'package:alumni_system/services/notification_service.dart';
import 'job_posting_screen.dart';

class AddJobDialog extends StatefulWidget {
  final JobPosting? job;
  final Function(JobPosting)? onJobAdded;
  final Function(JobPosting)? onJobUpdated;

  const AddJobDialog({super.key, this.job, this.onJobAdded, this.onJobUpdated});

  @override
  State<AddJobDialog> createState() => _AddJobDialogState();
}

class _AddJobDialogState extends State<AddJobDialog> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _locationController = TextEditingController();
  final _salaryRangeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _benefitsController = TextEditingController();
  final _contactEmailController = TextEditingController();

  String _selectedJobType = 'Full-time';
  String _selectedExperienceLevel = 'Mid-level';
  bool _isRemote = false;
  DateTime _applicationDeadline = DateTime.now().add(const Duration(days: 30));

  final List<String> _jobTypes = [
    'Full-time',
    'Part-time',
    'Contract',
    'Internship',
    'Temporary',
  ];

  final List<String> _experienceLevels = [
    'Entry-level',
    'Mid-level',
    'Senior',
    'Executive',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.job != null) {
      _populateForm(widget.job!);
    }
  }

  void _populateForm(JobPosting job) {
    _companyNameController.text = job.companyName;
    _jobTitleController.text = job.jobTitle;
    _locationController.text = job.location;
    _salaryRangeController.text = job.salaryRange;
    _descriptionController.text = job.description;
    _requirementsController.text = job.requirements.join('\n');
    _benefitsController.text = job.benefits.join('\n');
    _contactEmailController.text = job.contactEmail;
    _selectedJobType = job.jobType;
    _selectedExperienceLevel = job.experienceLevel;
    _isRemote = job.isRemote;
    _applicationDeadline = job.applicationDeadline;
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final currentUser = FirebaseAuth.instance.currentUser;
      final jobService = JobService();

      final job = JobPosting(
        id: widget.job?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        companyName: _companyNameController.text,
        companyLogo: '',
        jobTitle: _jobTitleController.text,
        jobType: _selectedJobType,
        location: _locationController.text,
        salaryRange: _salaryRangeController.text,
        description: _descriptionController.text,
        requirements: _requirementsController.text
            .split('\n')
            .where((req) => req.isNotEmpty)
            .toList(),
        benefits: _benefitsController.text
            .split('\n')
            .where((benefit) => benefit.isNotEmpty)
            .toList(),
        postedDate: widget.job?.postedDate ?? DateTime.now(),
        applicationDeadline: _applicationDeadline,
        contactEmail: _contactEmailController.text,
        applicationMethod: 'email',
        isActive: true,
        views: widget.job?.views ?? 0,
        applications: widget.job?.applications ?? 0,
        adminId: currentUser?.uid ?? 'admin1',
        isRemote: _isRemote,
        experienceLevel: _selectedExperienceLevel,
        status: widget.job?.status ?? 'active',
      );

      try {
        if (widget.job == null) {
          await jobService.addJobPosting(job);

          // Send notification to all users about new job
          try {
            final notificationService = NotificationService();
            await notificationService.notifyNewJob(
              jobId: job.id,
              jobTitle: job.jobTitle,
              companyName: job.companyName,
            );
          } catch (e) {
            print('Error sending job notification: $e');
            // Don't fail the job creation if notification fails
          }

          widget.onJobAdded?.call(job);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Job posting created successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          await jobService.updateJobPosting(job);
          widget.onJobUpdated?.call(job);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Job posting updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _selectDeadline() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _applicationDeadline,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _applicationDeadline) {
      setState(() {
        _applicationDeadline = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.job == null ? 'Post New Job' : 'Edit Job',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF090A4F),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Information
                        const Text(
                          'Basic Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF090A4F),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          'Company Name',
                          _companyNameController,
                          'Enter company name',
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          'Job Title',
                          _jobTitleController,
                          'Enter job title',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdown(
                                'Job Type',
                                _selectedJobType,
                                _jobTypes,
                                (value) =>
                                    setState(() => _selectedJobType = value!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDropdown(
                                'Experience Level',
                                _selectedExperienceLevel,
                                _experienceLevels,
                                (value) => setState(
                                  () => _selectedExperienceLevel = value!,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                'Location',
                                _locationController,
                                'Enter location',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                'Salary Range',
                                _salaryRangeController,
                                'e.g., ₱50,000 - ₱80,000',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _selectDeadline,
                                child: AbsorbPointer(
                                  child: _buildTextField(
                                    'Application Deadline',
                                    TextEditingController(
                                      text:
                                          '${_applicationDeadline.day}/${_applicationDeadline.month}/${_applicationDeadline.year}',
                                    ),
                                    'Select deadline',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('Remote Work'),
                                value: _isRemote,
                                onChanged: (value) =>
                                    setState(() => _isRemote = value ?? false),
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Job Description
                        const Text(
                          'Job Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF090A4F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText:
                                'Describe the job responsibilities, role, and expectations...',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter job description';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        // Requirements
                        const Text(
                          'Requirements',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF090A4F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _requirementsController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Enter each requirement on a new line...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Benefits
                        const Text(
                          'Benefits',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF090A4F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _benefitsController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Enter each benefit on a new line...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Contact Information
                        const Text(
                          'Contact Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF090A4F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildTextField(
                          'Contact Email',
                          _contactEmailController,
                          'Enter contact email',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF090A4F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          widget.job == null ? 'Post Job' : 'Update Job',
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
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF090A4F),
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter $label';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF090A4F),
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          items: items.map((String item) {
            return DropdownMenuItem<String>(value: item, child: Text(item));
          }).toList(),
          onChanged: onChanged,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}

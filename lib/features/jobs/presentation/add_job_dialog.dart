import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/core/utils/local_id.dart';
import 'package:alumni_system/features/jobs/data/job_service.dart';
import 'package:alumni_system/features/jobs/models/job_category_constants.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_form_layout.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';

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
  final _applicationUrlController = TextEditingController();
  late final TextEditingController _deadlineController;

  final _picker = ImagePicker();
  final _imageStorage = ImageStorageService();

  String _selectedJobType = 'Full-time';
  String _selectedExperienceLevel = 'Mid-level';
  String _selectedCategory = JobCategoryConstants.others;
  bool _isRemote = false;
  DateTime _applicationDeadline = DateTime.now().add(const Duration(days: 30));
  String _companyLogoUrl = '';
  Uint8List? _pendingLogoBytes;
  String _coverUrl = '';
  Uint8List? _pendingCoverBytes;
  bool _coverRemoved = false;
  final Set<String> _targetPrograms = {};
  bool _saving = false;

  bool get _isEditing => widget.job != null;

  @override
  void initState() {
    super.initState();
    _deadlineController = TextEditingController(text: _formatDeadline());
    if (widget.job != null) _populateForm(widget.job!);
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _jobTitleController.dispose();
    _locationController.dispose();
    _salaryRangeController.dispose();
    _descriptionController.dispose();
    _requirementsController.dispose();
    _benefitsController.dispose();
    _contactEmailController.dispose();
    _applicationUrlController.dispose();
    _deadlineController.dispose();
    super.dispose();
  }

  String _formatDeadline() =>
      '${_applicationDeadline.day}/${_applicationDeadline.month}/${_applicationDeadline.year}';

  void _populateForm(JobPosting job) {
    _companyNameController.text = job.companyName;
    _jobTitleController.text = job.jobTitle;
    _locationController.text = job.location;
    _salaryRangeController.text = job.salaryRange;
    _descriptionController.text = job.description;
    _requirementsController.text = job.requirements.join('\n');
    _benefitsController.text = job.benefits.join('\n');
    _contactEmailController.text = job.contactEmail;
    _applicationUrlController.text = job.applicationUrl;
    _selectedJobType = job.jobType.isNotEmpty ? job.jobType : 'Full-time';
    _selectedExperienceLevel = job.experienceLevel.isNotEmpty
        ? job.experienceLevel
        : 'Mid-level';
    _selectedCategory = JobCategoryConstants.normalize(job.category);
    _isRemote = job.isRemote;
    _applicationDeadline = job.applicationDeadline;
    _deadlineController.text = _formatDeadline();
    _companyLogoUrl = job.companyLogo;
    _coverUrl = job.coverImage;
    _targetPrograms
      ..clear()
      ..addAll(job.targetPrograms);
  }

  Future<void> _pickLogo() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 88,
      );
      if (file == null) return;
      var bytes = await file.readAsBytes();
      var compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 512,
        minHeight: 512,
        quality: 82,
        format: CompressFormat.jpeg,
      );
      if (compressed.length > 700 * 1024) {
        compressed = await FlutterImageCompress.compressWithList(
          compressed,
          minWidth: 400,
          minHeight: 400,
          quality: 70,
          format: CompressFormat.jpeg,
        );
      }
      if (!mounted) return;
      setState(() {
        _pendingLogoBytes = compressed;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not pick logo: $e')));
    }
  }

  Future<void> _pickCover() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 90,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      var compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1280,
        minHeight: 720,
        quality: 75,
        format: CompressFormat.jpeg,
      );
      if (compressed.length > ImageStorageService.maxUploadBytes) {
        compressed = await FlutterImageCompress.compressWithList(
          compressed,
          quality: 55,
          format: CompressFormat.jpeg,
        );
      }
      if (!mounted) return;
      setState(() {
        _pendingCoverBytes = compressed;
        _coverRemoved = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not pick cover photo: $e')));
    }
  }

  bool get _hasCover => _pendingCoverBytes != null || _coverUrl.isNotEmpty;

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _applicationDeadline.isBefore(DateTime.now())
          ? DateTime.now()
          : _applicationDeadline,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _applicationDeadline = picked;
      _deadlineController.text = _formatDeadline();
    });
  }

  String? _validateEmail(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
    if (!ok) return 'Enter a valid email';
    return null;
  }

  String? _validateUrl(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final uri = Uri.tryParse(t);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return 'Use http:// or https:// URL';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);

    final jobId = widget.job?.id ?? LocalId.generate();
    var logoUrl = _companyLogoUrl;

    try {
      if (_pendingLogoBytes != null) {
        logoUrl = await _imageStorage.uploadJobCompanyLogo(
          jobId: jobId,
          bytes: _pendingLogoBytes!,
        );
      }
      var coverUrl = _coverUrl;
      if (_pendingCoverBytes != null) {
        coverUrl = await _imageStorage.uploadJobCoverImage(
          jobId: jobId,
          bytes: _pendingCoverBytes!,
        );
      } else if (_coverRemoved) {
        coverUrl = '';
        await _imageStorage.deleteJobCoverImage(jobId);
      }

      final posting = JobPosting(
        id: jobId,
        companyName: _companyNameController.text.trim(),
        companyLogo: logoUrl,
        coverImage: coverUrl,
        jobTitle: _jobTitleController.text.trim(),
        jobType: _selectedJobType,
        location: _locationController.text.trim(),
        salaryRange: _salaryRangeController.text.trim(),
        description: _descriptionController.text.trim(),
        requirements: _requirementsController.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        benefits: _benefitsController.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        postedDate: widget.job?.postedDate ?? DateTime.now(),
        applicationDeadline: _applicationDeadline,
        contactEmail: _contactEmailController.text.trim(),
        applicationMethod: 'email',
        isActive: true,
        views: widget.job?.views ?? 0,
        applications: widget.job?.applications ?? 0,
        adminId: AppSession.userId ?? 'admin',
        isRemote: _isRemote,
        experienceLevel: _selectedExperienceLevel,
        status: widget.job?.status ?? 'active',
        category: _selectedCategory,
        targetPrograms: _targetPrograms.toList()..sort(),
        applicationUrl: _applicationUrlController.text.trim(),
      );

      // Alumni notices come from the jobs table trigger (notify_job_changes).
      final service = JobService();
      if (_isEditing) {
        await service.updateJobPosting(posting);
        widget.onJobUpdated?.call(posting);
      } else {
        await service.addJobPosting(posting);
        widget.onJobAdded?.call(posting);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Job updated' : 'Job posted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving job: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminFormSection(
                    title: 'General',
                    subtitle: 'Role basics alumni will scan first',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _jobTitleController,
                          decoration: const InputDecoration(
                            labelText: 'Job title *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: AdminDensity.space2),
                        AdminFormRow(
                          children: [
                            DropdownButtonFormField<String>(
                              // ignore: deprecated_member_use
                              value: _selectedCategory,
                              borderRadius: PortalMenu.dropdownRadius,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: JobCategoryConstants.all
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(
                                () => _selectedCategory =
                                    v ?? JobCategoryConstants.others,
                              ),
                            ),
                            DropdownButtonFormField<String>(
                              // ignore: deprecated_member_use
                              value: _selectedJobType,
                              borderRadius: PortalMenu.dropdownRadius,
                              decoration: const InputDecoration(
                                labelText: 'Job type',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: JobCategoryConstants.jobTypes
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(
                                () => _selectedJobType = v ?? 'Full-time',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AdminDensity.space2),
                        AdminFormRow(
                          children: [
                            DropdownButtonFormField<String>(
                              // ignore: deprecated_member_use
                              value: _selectedExperienceLevel,
                              borderRadius: PortalMenu.dropdownRadius,
                              decoration: const InputDecoration(
                                labelText: 'Experience',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: JobCategoryConstants.experienceLevels
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(
                                () =>
                                    _selectedExperienceLevel = v ?? 'Mid-level',
                              ),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Remote work'),
                              value: _isRemote,
                              onChanged: (v) =>
                                  setState(() => _isRemote = v ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AdminFormSection(
                    title: 'Company',
                    subtitle: 'Employer identity, logo and cover photo',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _companyNameController,
                          decoration: const InputDecoration(
                            labelText: 'Company name *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: AdminDensity.space2),
                        Row(
                          children: [
                            _logoPreview(),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _saving ? null : _pickLogo,
                                    icon: const Icon(
                                      Icons.upload_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      _pendingLogoBytes != null ||
                                              _companyLogoUrl.isNotEmpty
                                          ? 'Replace logo'
                                          : 'Upload logo',
                                    ),
                                  ),
                                  if (_pendingLogoBytes != null ||
                                      _companyLogoUrl.isNotEmpty)
                                    TextButton(
                                      onPressed: _saving
                                          ? null
                                          : () => setState(() {
                                              _pendingLogoBytes = null;
                                              _companyLogoUrl = '';
                                            }),
                                      child: const Text('Remove'),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AdminDensity.space3),
                        Text(
                          'Cover photo (optional)',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'A wide photo shown at the top of the job details. '
                          'Alumni can view and download it.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: AdminDensity.space2),
                        _coverPreview(),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _saving ? null : _pickCover,
                              icon: const Icon(Icons.image_outlined, size: 18),
                              label: Text(
                                _hasCover
                                    ? 'Replace cover photo'
                                    : 'Upload cover photo',
                              ),
                            ),
                            if (_hasCover)
                              TextButton(
                                onPressed: _saving
                                    ? null
                                    : () => setState(() {
                                        _pendingCoverBytes = null;
                                        _coverUrl = '';
                                        _coverRemoved = true;
                                      }),
                                child: const Text('Remove'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AdminFormSection(
                    title: 'Job details',
                    subtitle: 'Location, pay, deadline, and role summary',
                    child: Column(
                      children: [
                        AdminFormRow(
                          children: [
                            TextFormField(
                              controller: _locationController,
                              decoration: const InputDecoration(
                                labelText: 'Location *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                            TextFormField(
                              controller: _salaryRangeController,
                              decoration: const InputDecoration(
                                labelText: 'Salary range *',
                                hintText: 'e.g., ₱50,000 - ₱80,000',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: AdminDensity.space2),
                        TextFormField(
                          controller: _deadlineController,
                          readOnly: true,
                          onTap: _pickDeadline,
                          decoration: const InputDecoration(
                            labelText: 'Application deadline *',
                            border: OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          validator: (_) => null,
                        ),
                        const SizedBox(height: AdminDensity.space2),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Description *',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  AdminFormSection(
                    title: 'Requirements',
                    subtitle: 'One requirement per line',
                    child: TextFormField(
                      controller: _requirementsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'One requirement per line',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                  AdminFormSection(
                    title: 'Benefits',
                    subtitle: 'One benefit per line',
                    child: TextFormField(
                      controller: _benefitsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'One benefit per line',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                  AdminFormSection(
                    title: 'Application',
                    subtitle: 'How alumni reach the employer',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _contactEmailController,
                          decoration: const InputDecoration(
                            labelText: 'Contact email *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: AdminDensity.space2),
                        TextFormField(
                          controller: _applicationUrlController,
                          decoration: const InputDecoration(
                            labelText: 'External apply URL (optional)',
                            hintText: 'https://…',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: _validateUrl,
                        ),
                      ],
                    ),
                  ),
                  AdminFormSection(
                    title: 'Recommended for (programs)',
                    subtitle: 'Optional targeting for career recommendations',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: CourseConstants.courses.map((c) {
                        final selected = _targetPrograms.contains(c);
                        return FilterChip(
                          label: Text(c),
                          selected: selected,
                          onSelected: (v) => setState(() {
                            if (v) {
                              _targetPrograms.add(c);
                            } else {
                              _targetPrograms.remove(c);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AdminFormActionsBar(
            actions: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Update job' : 'Post job'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coverPreview() {
    Widget child;
    if (_pendingCoverBytes != null) {
      child = Image.memory(_pendingCoverBytes!, fit: BoxFit.cover);
    } else if (_coverUrl.isNotEmpty) {
      child = AppImage.widget(_coverUrl, fit: BoxFit.cover);
    } else {
      child = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.panorama_outlined, color: Color(0xFF64748B), size: 28),
            SizedBox(height: 6),
            Text(
              'No cover photo',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }

  Widget _logoPreview() {
    Widget child;
    if (_pendingLogoBytes != null) {
      child = Image.memory(_pendingLogoBytes!, fit: BoxFit.cover);
    } else if (_companyLogoUrl.isNotEmpty) {
      child = AppImage.widget(_companyLogoUrl, fit: BoxFit.cover);
    } else {
      child = const Icon(Icons.business_rounded, color: Color(0xFF090A4F));
    }
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

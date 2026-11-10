import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/constants/event_category_constants.dart';
import 'package:alumni_system/core/utils/local_id.dart';
import 'package:alumni_system/core/utils/web_file_upload.dart';
import 'package:alumni_system/features/events/data/event_service.dart';
import 'package:alumni_system/features/events/models/event_agenda_item.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/events/widgets/venue_pin_picker_dialog.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';
import 'package:alumni_system/features/admin/events/widgets/admin_event_ui.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_form_fields.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_form_layout.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

Future<bool?> showAdminEventEditorDialog({
  required BuildContext context,
  AlumniEvent? event,
  DateTime? initialDate,
}) {
  return showAdminDialogSurface<bool>(
    context: context,
    maxWidth: kAdminDialogXl,
    barrierDismissible: false,
    child: AdminEventEditorDialog(event: event, initialDate: initialDate),
  );
}

class AdminEventEditorDialog extends StatefulWidget {
  const AdminEventEditorDialog({
    super.key,
    this.event,
    this.initialDate,
  });

  final AlumniEvent? event;
  final DateTime? initialDate;

  @override
  State<AdminEventEditorDialog> createState() => _AdminEventEditorDialogState();
}

class _AdminEventEditorDialogState extends State<AdminEventEditorDialog> {
  final _eventService = EventService();
  final _imageStorage = ImageStorageService();
  final _picker = ImagePicker();

  late final TextEditingController _theme;
  late final TextEditingController _batchYear;
  late final TextEditingController _date;
  late final TextEditingController _venue;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late final TextEditingController _description;
  late final TextEditingController _capacity;
  late final TextEditingController _deadline;

  String _category = EventCategoryConstants.other;
  String _coverUrl = '';
  Uint8List? _pendingCoverBytes;
  final List<_AgendaDraft> _agenda = [];
  bool _saving = false;
  bool _uploadingCover = false;
  bool _submitted = false;
  double? _venueLatitude;
  double? _venueLongitude;

  bool get _isEdit => widget.event != null;
  bool get _hasVenuePin =>
      _venueLatitude != null &&
      _venueLongitude != null &&
      _venueLatitude!.isFinite &&
      _venueLongitude!.isFinite;

  List<String> get _missingRequiredFields => [
    if (_theme.text.trim().isEmpty) 'Theme',
    if (_batchYear.text.trim().isEmpty) 'Batch year',
    if (_date.text.trim().isEmpty) 'Event date',
    if (_start.text.trim().isEmpty) 'Start time',
    if (_end.text.trim().isEmpty) 'End time',
    if (_venue.text.trim().isEmpty) 'Venue',
  ];

  InputDecoration _compactInputDecoration(
    String label, {
    IconData? icon,
    String? hintText,
  }) {
    const borderSide = BorderSide(color: AdminColors.border);
    final shape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: borderSide,
    );
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 18, color: AdminColors.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: shape,
      enabledBorder: shape,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminColors.primary, width: 1.4),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _theme = TextEditingController(text: e?.theme ?? '');
    _batchYear = TextEditingController(text: e?.batchYear ?? '');
    final initialDate = e?.date ?? widget.initialDate;
    _date = TextEditingController(
      text: initialDate == null
          ? ''
          : DateFormat('MM/dd/yyyy').format(initialDate),
    );
    _venue = TextEditingController(text: e?.venue ?? '');
    _start = TextEditingController(text: e?.startTime ?? '09:00');
    _end = TextEditingController(text: e?.endTime ?? '17:00');
    _description = TextEditingController(text: e?.description ?? '');
    _capacity = TextEditingController(
      text: e?.capacity == null ? '' : '${e!.capacity}',
    );
    _deadline = TextEditingController(
      text: e?.registrationDeadline == null
          ? ''
          : DateFormat('MM/dd/yyyy').format(e!.registrationDeadline!),
    );
    _category = e?.category ?? EventCategoryConstants.other;
    _coverUrl = e?.coverImageUrl ?? '';
    _venueLatitude = e?.venueLatitude;
    _venueLongitude = e?.venueLongitude;
    for (final item in e?.agenda ?? const <EventAgendaItem>[]) {
      _agenda.add(
        _AgendaDraft(
          time: TextEditingController(text: item.time),
          title: TextEditingController(text: item.title),
        ),
      );
    }
  }

  @override
  void dispose() {
    _theme.dispose();
    _batchYear.dispose();
    _date.dispose();
    _venue.dispose();
    _start.dispose();
    _end.dispose();
    _description.dispose();
    _capacity.dispose();
    _deadline.dispose();
    for (final a in _agenda) {
      a.dispose();
    }
    super.dispose();
  }

  DateTime _parseDate(String raw) {
    final parts = raw.split('/');
    if (parts.length == 3) {
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }
    return DateTime.parse(raw);
  }

  Future<void> _pickCover() async {
    try {
      setState(() => _uploadingCover = true);
      Uint8List? bytes;
      try {
        bytes = await pickFileBytesOnWeb(accept: 'image/*');
      } catch (_) {}
      if (bytes == null) {
        final file = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          imageQuality: 85,
        );
        if (file != null) bytes = await file.readAsBytes();
      }
      if (bytes == null) return;

      var compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1280,
        minHeight: 720,
        quality: 75,
        format: CompressFormat.jpeg,
      );
      if (compressed.length > 700 * 1024) {
        compressed = await FlutterImageCompress.compressWithList(
          compressed,
          quality: 55,
          format: CompressFormat.jpeg,
        );
      }
      setState(() {
        _pendingCoverBytes = compressed;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(eventFriendlyError(e, 'Could not pick cover image.')),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  void _removeCover() {
    setState(() {
      _pendingCoverBytes = null;
      _coverUrl = '';
    });
  }

  Future<void> _pickVenuePin() async {
    final result = await showVenuePinPickerDialog(
      context: context,
      venueLabel: _venue.text.trim(),
      initialLatitude: _venueLatitude,
      initialLongitude: _venueLongitude,
    );
    if (result == null || !mounted) return;
    setState(() {
      _venueLatitude = result.latitude;
      _venueLongitude = result.longitude;
    });
  }

  Future<void> _save() async {
    if (_missingRequiredFields.isNotEmpty) {
      setState(() => _submitted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final id = widget.event?.id ?? LocalId.generate();
      var cover = _coverUrl;
      if (_pendingCoverBytes != null) {
        cover = await _imageStorage.uploadEventCoverImage(
          eventId: id,
          bytes: _pendingCoverBytes!,
        );
      } else if (_coverUrl.isEmpty && widget.event?.hasCoverImage == true) {
        await _imageStorage.deleteEventCoverImage(id);
      }

      final capacityText = _capacity.text.trim();
      final capacity = capacityText.isEmpty ? null : int.tryParse(capacityText);
      final deadlineText = _deadline.text.trim();
      final deadline =
          deadlineText.isEmpty ? null : _parseDate(deadlineText);

      final agenda = _agenda
          .map(
            (a) => EventAgendaItem(
              time: a.time.text.trim(),
              title: a.title.text.trim(),
            ),
          )
          .where((a) => a.title.isNotEmpty)
          .toList();

      final event = AlumniEvent(
        id: id,
        theme: _theme.text.trim(),
        batchYear: _batchYear.text.trim(),
        date: _parseDate(_date.text.trim()),
        venue: _venue.text.trim(),
        status: widget.event?.status ?? 'Active',
        comments: widget.event?.comments ?? 0,
        startTime: _start.text.trim(),
        endTime: _end.text.trim(),
        description: _description.text.trim(),
        createdAt: widget.event?.createdAt,
        coverImageUrl: cover,
        category: _category,
        capacity: capacity,
        registrationDeadline: deadline,
        agenda: agenda,
        viewsCount: widget.event?.viewsCount ?? 0,
        cancelled: widget.event?.cancelled ?? false,
        venueLatitude: _venueLatitude,
        venueLongitude: _venueLongitude,
      );

      // Alumni notices (new event / venue / schedule) come from the
      // events table trigger (notify_event_changes).
      if (_isEdit) {
        await _eventService.updateEvent(event);
      } else {
        await _eventService.addEvent(event);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            eventFriendlyError(e, 'Could not save event. Please try again.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminModalHeader(
          title: _isEdit ? 'Edit event' : 'New event',
          subtitle: _isEdit
              ? 'Update schedule, venue, and details'
              : 'Create an alumni event for the portal',
          icon: _isEdit ? Icons.edit_calendar_outlined : Icons.event_outlined,
          onClose: _saving ? null : () => Navigator.pop(context, false),
        ),
        AnimatedBuilder(
          animation: Listenable.merge([
            _theme,
            _batchYear,
            _date,
            _start,
            _end,
            _venue,
          ]),
          builder: (context, _) {
            final missing = _submitted ? _missingRequiredFields : const <String>[];
            if (missing.isEmpty) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                border: Border(
                  top: BorderSide(color: Color(0xFFFECACA)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: Color(0xFFB91C1C),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Required before saving: ${missing.join(', ')}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AdminDensity.formSectionPadding),
            child: Column(
              children: [
                AdminFormSection(
                  title: 'Basic information',
                  subtitle: 'Title, audience batch, and category',
                  child: Column(
                    children: [
                      adminFormField(
                        context,
                        'Event theme *',
                        _theme,
                        'Enter event title',
                        icon: Icons.event,
                      ),
                      const SizedBox(height: 12),
                      AdminFormRow(
                        breakpoint: 520,
                        children: [
                          adminFormField(
                            context,
                            'Batch year *',
                            _batchYear,
                            'e.g. 2024',
                            icon: Icons.calendar_month,
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            isExpanded: true,
                            decoration: _compactInputDecoration(
                              'Category',
                              icon: Icons.category_outlined,
                            ),
                            items: EventCategoryConstants.all
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _category = v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      adminFormField(
                        context,
                        'Description',
                        _description,
                        'Optional overview. Links (https://… or www.…) '
                            'become clickable.',
                        isMultiline: true,
                        icon: Icons.description,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AdminFormSection(
                  title: 'Schedule',
                  child: AdminFormRow(
                    breakpoint: 520,
                    children: [
                      adminFormField(
                        context,
                        'Event date *',
                        _date,
                        'MM/DD/YYYY',
                        isDate: true,
                        icon: Icons.calendar_today,
                      ),
                      adminFormField(
                        context,
                        'Start *',
                        _start,
                        'HH:mm',
                        isTime: true,
                        icon: Icons.access_time,
                      ),
                      adminFormField(
                        context,
                        'End *',
                        _end,
                        'HH:mm',
                        isTime: true,
                        icon: Icons.access_time,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AdminFormSection(
                  title: 'Venue',
                  subtitle:
                      'Type a readable place name, then optionally pin the exact spot on the map.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      adminFormField(
                        context,
                        'Venue *',
                        _venue,
                        'Location or address',
                        icon: Icons.location_on,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickVenuePin,
                              style: AdminButtonStyles.outlined(),
                              icon: Icon(
                                _hasVenuePin
                                    ? Icons.edit_location_alt_outlined
                                    : Icons.add_location_alt_outlined,
                                size: 18,
                              ),
                              label: Text(
                                _hasVenuePin
                                    ? 'Edit map pin'
                                    : 'Pin on map',
                              ),
                            ),
                          ),
                          if (_hasVenuePin) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Clear map pin',
                              style: AdminDensity.iconButtonStyle(
                                foregroundColor: AdminColors.textSecondary,
                              ),
                              onPressed: () => setState(() {
                                _venueLatitude = null;
                                _venueLongitude = null;
                              }),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ],
                      ),
                      if (_hasVenuePin)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(
                                AdminSurfaces.radiusSm,
                              ),
                              border: Border.all(
                                color: const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                  color: Color(0xFF047857),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Venue pin saved: ${_venueLatitude!.toStringAsFixed(5)}, '
                                    '${_venueLongitude!.toStringAsFixed(5)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF047857),
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
                const SizedBox(height: 12),
                AdminFormSection(
                  title: 'Cover image',
                  subtitle: 'One image. Compressed automatically on save.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 7,
                        child: Material(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(
                            AdminSurfaces.radiusMd,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              AdminSurfaces.radiusMd,
                            ),
                            onTap: _uploadingCover ? null : _pickCover,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AdminSurfaces.radiusMd,
                                ),
                                border: Border.all(color: AdminColors.border),
                                image: _pendingCoverBytes != null
                                    ? DecorationImage(
                                        image: MemoryImage(_pendingCoverBytes!),
                                        fit: BoxFit.cover,
                                      )
                                    : (_coverUrl.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(_coverUrl),
                                            fit: BoxFit.cover,
                                          )
                                        : null),
                              ),
                              child:
                                  _pendingCoverBytes == null && _coverUrl.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.add_photo_alternate_outlined,
                                              size: 28,
                                              color: AdminColors.primary
                                                  .withValues(alpha: 0.72),
                                            ),
                                            const SizedBox(height: 6),
                                            const Text(
                                              'Add event cover image',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AdminColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            const Text(
                                              'Click to browse · recommended 16:9 landscape',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color:
                                                    AdminColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _uploadingCover ? null : _pickCover,
                            style: AdminButtonStyles.outlined(),
                            icon: _uploadingCover
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.upload, size: 18),
                            label: Text(
                              _coverUrl.isEmpty && _pendingCoverBytes == null
                                  ? 'Upload cover'
                                  : 'Replace',
                            ),
                          ),
                          if (_coverUrl.isNotEmpty || _pendingCoverBytes != null)
                            TextButton.icon(
                              onPressed: _removeCover,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFB91C1C),
                                minimumSize: const Size(
                                  0,
                                  AdminDensity.buttonHeight,
                                ),
                              ),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Remove'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AdminFormSection(
                  title: 'Capacity & registration',
                  child: AdminFormRow(
                    breakpoint: 520,
                    children: [
                      adminFormField(
                        context,
                        'Capacity',
                        _capacity,
                        'Optional seat limit',
                        icon: Icons.event_seat,
                      ),
                      adminFormField(
                        context,
                        'Registration deadline',
                        _deadline,
                        'MM/DD/YYYY',
                        isDate: true,
                        icon: Icons.timer_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AdminFormSection(
                  title: 'Agenda',
                  subtitle: 'Optional timed program items.',
                  child: Column(
                    children: [
                      for (var i = 0; i < _agenda.length; i++) ...[
                        Row(
                          children: [
                            SizedBox(
                              width: 104,
                              child: TextField(
                                controller: _agenda[i].time,
                                decoration: _compactInputDecoration(
                                  'Time',
                                  hintText: '09:00 AM',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _agenda[i].title,
                                decoration: _compactInputDecoration(
                                  'Item',
                                  hintText: 'Session title',
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Remove',
                              style: AdminDensity.iconButtonStyle(
                                foregroundColor: AdminColors.textSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _agenda[i].dispose();
                                  _agenda.removeAt(i);
                                });
                              },
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: AdminButtonStyles.ghost(),
                          onPressed: () {
                            setState(() {
                              _agenda.add(
                                _AgendaDraft(
                                  time: TextEditingController(),
                                  title: TextEditingController(),
                                ),
                              );
                            });
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add agenda item'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AdminFormSection(
                  title: 'Preview',
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _theme,
                      _batchYear,
                      _date,
                      _start,
                      _end,
                      _venue,
                    ]),
                    builder: (context, _) {
                      final meta = [
                        if (_date.text.trim().isNotEmpty) _date.text.trim(),
                        if (_start.text.trim().isNotEmpty &&
                            _end.text.trim().isNotEmpty)
                          '${_start.text.trim()} – ${_end.text.trim()}',
                        if (_venue.text.trim().isNotEmpty) _venue.text.trim(),
                      ];
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(
                            AdminSurfaces.radiusMd,
                          ),
                          border: Border.all(color: AdminColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                AdminEventCategoryBadge(category: _category),
                                if (_batchYear.text.trim().isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AdminColors.border,
                                      ),
                                    ),
                                    child: Text(
                                      'Batch ${_batchYear.text.trim()}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AdminColors.textSecondary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _theme.text.trim().isEmpty
                                  ? 'Untitled event'
                                  : _theme.text.trim(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AdminColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              meta.isEmpty
                                  ? 'Date, schedule, and venue will appear here'
                                  : meta.join(' · '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AdminColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        AdminFormActionsBar(
          leading: [
            OutlinedButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              style: AdminButtonStyles.outlined(),
              child: const Text('Cancel'),
            ),
          ],
          actions: [
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(_isEdit ? Icons.save_outlined : Icons.publish, size: 18),
              label: Text(_isEdit ? 'Save' : 'Publish'),
              style: AdminButtonStyles.filled(),
            ),
          ],
        ),
      ],
    );
  }
}

class _AgendaDraft {
  _AgendaDraft({required this.time, required this.title});
  final TextEditingController time;
  final TextEditingController title;
  void dispose() {
    time.dispose();
    title.dispose();
  }
}

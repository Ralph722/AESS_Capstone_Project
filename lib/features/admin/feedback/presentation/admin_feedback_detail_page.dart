import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alumni_system/features/feedback/models/feedback_model.dart';
import 'package:alumni_system/features/feedback/data/feedback_service.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';

class AdminFeedbackDetailScreen extends StatefulWidget {
  const AdminFeedbackDetailScreen({super.key, required this.feedbackId});

  final String feedbackId;

  @override
  State<AdminFeedbackDetailScreen> createState() =>
      _AdminFeedbackDetailScreenState();
}

class _AdminFeedbackDetailScreenState extends State<AdminFeedbackDetailScreen> {
  static const Color _navy = Color(0xFF090A4F);

  final _service = FeedbackService();
  final _responseController = TextEditingController();

  FeedbackSubmission? _item;
  FeedbackStatus _status = FeedbackStatus.submitted;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final item = await _service.getFeedbackByIdForAdmin(widget.feedbackId);
      if (!mounted) return;
      setState(() {
        _item = item;
        _status = _defaultStatusForAdmin(item);
        _responseController.text = item?.adminResponse ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  FeedbackStatus _defaultStatusForAdmin(FeedbackSubmission? item) {
    if (item == null) return FeedbackStatus.submitted;
    if (item.hasAdminResponse &&
        (item.status == FeedbackStatus.submitted ||
            item.status == FeedbackStatus.inReview)) {
      return FeedbackStatus.resolved;
    }
    return item.status;
  }

  Future<void> _saveResponse() async {
    setState(() => _saving = true);
    try {
      final statusForSave = _status == FeedbackStatus.closed
          ? FeedbackStatus.closed
          : FeedbackStatus.resolved;
      await _service.respondToFeedback(
        feedbackId: widget.feedbackId,
        adminResponse: _responseController.text,
        status: statusForSave,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Response saved and alumni notified.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateStatusOnly() async {
    setState(() => _saving = true);
    try {
      await _service.updateStatus(
        feedbackId: widget.feedbackId,
        status: _status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status updated.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Feedback detail'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _loading && _item == null
                ? const AdminMemberDetailSkeleton()
                : _item == null
              ? const Center(child: Text('Not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _item!.userName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _navy,
                                ),
                              ),
                              Text(_item!.userEmail),
                              if (_item!.program != null)
                                Text(
                                  '${_item!.program}${_item!.batchYear != null ? ' • Batch ${_item!.batchYear}' : ''}',
                                ),
                              const SizedBox(height: 8),
                              Text(
                                '${_item!.category.label} • ${DateFormat('MMM d, yyyy h:mm a').format(_item!.createdAt)}',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              if (_item!.rating != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      i < _item!.rating! ? Icons.star : Icons.star_border,
                                      color: Colors.amber,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_item!.subject?.isNotEmpty == true)
                                Text(
                                  _item!.subject!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              if (_item!.subject?.isNotEmpty == true) const SizedBox(height: 8),
                              Text(_item!.message),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<FeedbackStatus>(
                        value: _status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: FeedbackStatus.values
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.label),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (v) {
                                if (v != null) setState(() => _status = v);
                              },
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _saving ? null : _updateStatusOnly,
                        child: const Text('Update status only'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _responseController,
                        enabled: !_saving,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Admin response',
                          hintText: 'Reply visible to the alumni who submitted…',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _saving ? null : _saveResponse,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save response & notify alumni'),
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }
}


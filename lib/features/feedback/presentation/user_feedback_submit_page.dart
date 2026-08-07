import 'package:flutter/material.dart';

import 'package:alumni_system/features/feedback/models/feedback_model.dart';
import 'package:alumni_system/features/feedback/data/feedback_service.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';

class UserFeedbackSubmitScreen extends StatefulWidget {
  const UserFeedbackSubmitScreen({super.key});

  @override
  State<UserFeedbackSubmitScreen> createState() =>
      _UserFeedbackSubmitScreenState();
}

class _UserFeedbackSubmitScreenState extends State<UserFeedbackSubmitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _service = FeedbackService();

  FeedbackCategory _category = FeedbackCategory.general;
  int? _rating;
  bool _isSubmitting = false;

  bool get _dirty =>
      _subjectController.text.trim().isNotEmpty ||
      _messageController.text.trim().isNotEmpty ||
      _rating != null ||
      _category != FeedbackCategory.general;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await _service.submitFeedback(
        category: _category,
        subject: _subjectController.text,
        message: _messageController.text,
        rating: _rating,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(portalFriendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_dirty) return;
        final discard = await confirmDiscardChanges(context);
        if (!discard || !mounted) return;
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: PortalTheme.pageBg,
        appBar: const PortalAppBar(title: 'Send feedback'),
        body: PortalContentFrame(
          maxWidth: PortalBreakpoints.chatMax,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                const PortalPageIntro(
                  headline: 'We\'d love to hear from you',
                  body:
                      'We read every submission. You cannot edit after sending — take a moment to review before you submit.',
                  padding: EdgeInsets.fromLTRB(4, 4, 4, 16),
                ),
                Container(
                  padding: const EdgeInsets.all(PortalTheme.space4),
                  decoration: BoxDecoration(
                    color: PortalTheme.card,
                    borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
                    border: Border.all(color: PortalTheme.border),
                    boxShadow: PortalTheme.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<FeedbackCategory>(
                        key: ValueKey(_category),
                        initialValue: _category,
                        decoration: _inputDecoration('Category'),
                        items: FeedbackCategory.values
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.label),
                              ),
                            )
                            .toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (v) {
                                if (v != null) setState(() => _category = v);
                              },
                      ),
                      const SizedBox(height: PortalTheme.space3),
                      TextFormField(
                        controller: _subjectController,
                        enabled: !_isSubmitting,
                        decoration: _inputDecoration('Subject (optional)'),
                        maxLength: 120,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: PortalTheme.space2),
                      TextFormField(
                        controller: _messageController,
                        enabled: !_isSubmitting,
                        decoration: _inputDecoration('Message'),
                        maxLines: 6,
                        maxLength: 2000,
                        textInputAction: TextInputAction.newline,
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final text = v?.trim() ?? '';
                          if (text.length < 10) {
                            return 'Please enter at least 10 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: PortalTheme.space2),
                      Text(
                        'Overall experience (optional)',
                        style: PortalTheme.cardTitle.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          final star = i + 1;
                          final selected =
                              _rating != null && star <= _rating!;
                          return IconButton(
                            onPressed: _isSubmitting
                                ? null
                                : () {
                                    setState(() {
                                      _rating = selected && _rating == star
                                          ? null
                                          : star;
                                    });
                                  },
                            icon: Icon(
                              selected ? Icons.star : Icons.star_border,
                              color: selected
                                  ? PortalTheme.gold
                                  : PortalTheme.textMuted,
                              size: 36,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: PortalTheme.space4),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: PortalTheme.primaryButton(),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit feedback'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: PortalTheme.bodySecondary,
      filled: true,
      fillColor: PortalTheme.surfaceMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
        borderSide: const BorderSide(color: PortalTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
        borderSide: const BorderSide(color: PortalTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
        borderSide: const BorderSide(color: PortalTheme.navy, width: 2),
      ),
    );
  }
}

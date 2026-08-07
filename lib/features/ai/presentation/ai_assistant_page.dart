import 'package:flutter/material.dart';
import 'package:alumni_system/core/config/ai_config.dart';
import 'package:alumni_system/features/ai/models/ai_chat_message.dart';
import 'package:alumni_system/features/ai/data/ai_assistant_service.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';

/// In-app AI chat (Google Gemini) for alumni and admins.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({
    super.key,
    required this.isAdmin,
    this.userDisplayName,
  });

  final bool isAdmin;
  final String? userDisplayName;

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _service = AiAssistantService();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <AiChatMessage>[];
  bool _isLoading = false;

  static const _alumniSuggestions = [
    'How do I update my tracer profile?',
    'Where can I find job postings?',
    'How do I complete a survey?',
    'How do I contact support?',
  ];

  static const _adminSuggestions = [
    'How do I manage the alumni roster?',
    'How do I create a survey?',
    'How do I post an announcement?',
    'How do I view reports?',
  ];

  List<String> get _suggestions =>
      widget.isAdmin ? _adminSuggestions : _alumniSuggestions;

  bool get _showWelcome => _messages.length <= 1 && !_isLoading;

  @override
  void initState() {
    super.initState();
    _messages.add(
      AiChatMessage(
        role: AiMessageRole.assistant,
        text: widget.isAdmin
            ? 'Hello! I\'m your Alumni Portal admin assistant. Ask me about the roster, surveys, reports, announcements, or any admin feature.'
            : 'Hello! I\'m your Alumni Portal assistant. Ask me how to update your tracer, complete surveys, find jobs, or use any part of the app.',
      ),
    );
    if (!AiConfig.isConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSetupDialog());
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showSetupDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set up AI'),
        content: const SelectableText(
          'To enable the assistant:\n\n'
          '1. Open https://aistudio.google.com/apikey\n'
          '2. Create a free API key\n'
          '3. Paste it in lib/config/ai_defaults.dart (apiKey field)\n'
          '4. Hot restart the app\n\n'
          'Or build with:\n'
          '--dart-define=GEMINI_API_KEY=your_key',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _send([String? overrideText]) async {
    final text = (overrideText ?? _inputController.text).trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(AiChatMessage(role: AiMessageRole.user, text: text));
      _isLoading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final history = _messages
          .sublist(0, _messages.length - 1)
          .where((m) => !m.isError)
          .toList();
      final reply = await _service.sendMessage(
        isAdmin: widget.isAdmin,
        history: history,
        userMessage: text,
        userDisplayName: widget.userDisplayName,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(AiChatMessage(role: AiMessageRole.assistant, text: reply));
        _isLoading = false;
      });
    } on AiNotConfiguredException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          AiChatMessage(
            role: AiMessageRole.assistant,
            text: e.message,
            isError: true,
          ),
        );
        _isLoading = false;
      });
      _showSetupDialog();
    } on AiQuotaException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          AiChatMessage(
            role: AiMessageRole.assistant,
            text: e.message,
            isError: true,
          ),
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          AiChatMessage(
            role: AiMessageRole.assistant,
            text: 'Sorry, something went wrong. Please try again in a moment.',
            isError: true,
          ),
        );
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: PortalTheme.normal,
        curve: PortalTheme.ease,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortalTheme.pageBg,
      appBar: PortalAppBar(
        foreground: PortalAppBarTone.dark,
        title: widget.isAdmin ? 'Admin AI Assistant' : 'AI Help',
        automaticallyImplyLeading: true,
        actions: [
          if (!AiConfig.isConfigured)
            PortalHeaderAction(
              icon: Icons.settings_outlined,
              tooltip: 'Setup required',
              onPressed: _showSetupDialog,
            ),
        ],
      ),
      body: PortalContentFrame(
        maxWidth: PortalBreakpoints.chatMax,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: _messages.length +
                    (_showWelcome ? 1 : 0) +
                    (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_showWelcome && index == 1) {
                    return _buildSuggestedQuestions();
                  }
                  final msgIndex = _showWelcome && index > 0 ? index - 1 : index;
                  if (msgIndex == _messages.length && _isLoading) {
                    return _buildTypingIndicator();
                  }
                  if (msgIndex >= _messages.length) {
                    return const SizedBox.shrink();
                  }
                  return _buildBubble(_messages[msgIndex]);
                },
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedQuestions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: PortalTheme.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Try asking',
            style: PortalTheme.meta.copyWith(
              fontWeight: FontWeight.w700,
              color: PortalTheme.navy,
            ),
          ),
          const SizedBox(height: PortalTheme.space2),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((q) {
              return ActionChip(
                label: Text(
                  q,
                  style: PortalTheme.caption.copyWith(
                    color: PortalTheme.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: PortalTheme.navy.withValues(alpha: 0.06),
                side: BorderSide(
                  color: PortalTheme.navy.withValues(alpha: 0.15),
                ),
                onPressed: _isLoading ? null : () => _send(q),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(AiChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? PortalTheme.navy
              : message.isError
                  ? PortalTheme.danger.withValues(alpha: 0.08)
                  : PortalTheme.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(PortalTheme.radiusLg),
            topRight: const Radius.circular(PortalTheme.radiusLg),
            bottomLeft: Radius.circular(isUser ? PortalTheme.radiusLg : 4),
            bottomRight: Radius.circular(isUser ? 4 : PortalTheme.radiusLg),
          ),
          border: message.isError
              ? Border.all(color: PortalTheme.danger.withValues(alpha: 0.3))
              : isUser
                  ? null
                  : Border.all(color: PortalTheme.border),
          boxShadow: isUser ? null : PortalTheme.softShadow,
        ),
        child: SelectableText(
          message.text,
          style: PortalTheme.body.copyWith(
            color: isUser
                ? PortalTheme.textOnNavy
                : message.isError
                    ? PortalTheme.danger
                    : PortalTheme.textPrimary,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: PortalTheme.card,
          borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
          border: Border.all(color: PortalTheme.border),
        ),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: PortalTheme.navy,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Material(
      color: PortalTheme.card,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PortalTheme.card,
          border: Border(
            top: BorderSide(color: PortalTheme.border.withValues(alpha: 0.9)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: PortalTheme.body,
                    decoration: InputDecoration(
                      hintText: 'Ask anything about the portal…',
                      hintStyle: PortalTheme.bodySecondary,
                      filled: true,
                      fillColor: PortalTheme.surfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(PortalTheme.radiusXl),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: PortalTheme.navy,
                  borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
                  child: InkWell(
                    onTap: _isLoading ? null : () => _send(),
                    borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.send_rounded,
                        color: PortalTheme.gold,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

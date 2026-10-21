import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// A button shown by [AdminStateView.empty] / [AdminStateView.error].
class AdminStateAction {
  const AdminStateAction({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
}

enum _AdminStateKind { loading, empty, error }

/// Loading, empty and error states for admin pages, cards and charts.
///
/// [AdminStateView.error] shows friendly text; the technical [details] string
/// stays hidden until the user expands "Show details". A retry button is only
/// rendered when [onRetry] is provided.
class AdminStateView extends StatefulWidget {
  const AdminStateView.loading({super.key, this.label, this.compact = false})
    : _kind = _AdminStateKind.loading,
      icon = null,
      title = null,
      message = null,
      primaryAction = null,
      secondaryAction = null,
      details = null,
      onRetry = null,
      retryLabel = null;

  const AdminStateView.empty({
    super.key,
    required String this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.primaryAction,
    this.secondaryAction,
    this.compact = false,
  }) : _kind = _AdminStateKind.empty,
       label = null,
       details = null,
       onRetry = null,
       retryLabel = null;

  const AdminStateView.error({
    super.key,
    String this.title = 'Something went wrong',
    this.message,
    this.details,
    this.onRetry,
    String this.retryLabel = 'Try again',
    this.compact = false,
  }) : _kind = _AdminStateKind.error,
       icon = Icons.error_outline_rounded,
       label = null,
       primaryAction = null,
       secondaryAction = null;

  final _AdminStateKind _kind;

  /// Loading label (loading only).
  final String? label;
  final IconData? icon;
  final String? title;
  final String? message;
  final AdminStateAction? primaryAction;
  final AdminStateAction? secondaryAction;

  /// Technical error text; hidden behind "Show details".
  final String? details;
  final VoidCallback? onRetry;
  final String? retryLabel;

  /// Smaller layout for use inside cards and charts.
  final bool compact;

  @override
  State<AdminStateView> createState() => _AdminStateViewState();
}

class _AdminStateViewState extends State<AdminStateView> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final content = switch (widget._kind) {
      _AdminStateKind.loading => _buildLoading(),
      _AdminStateKind.empty => _buildMessage(isError: false),
      _AdminStateKind.error => _buildMessage(isError: true),
    };
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(widget.compact ? 12 : 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: content,
        ),
      ),
    );
  }

  Widget _buildLoading() {
    final size = widget.compact ? 20.0 : 28.0;
    return Semantics(
      liveRegion: true,
      label: widget.label ?? 'Loading',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AdminColors.primary,
            ),
          ),
          if (widget.label != null) ...[
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: Text(
                widget.label!,
                textAlign: TextAlign.center,
                style: AdminText.caption,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessage({required bool isError}) {
    final compact = widget.compact;
    final iconColor = isError ? AdminColors.danger : AdminColors.textMuted;
    final iconBg = isError ? AdminColors.dangerBg : AdminColors.surface;

    final iconBox = compact
        ? Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminColors.border),
            ),
            child: Icon(widget.icon, size: 22, color: iconColor),
          )
        : Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(widget.icon, size: 40, color: iconColor),
          );

    final actions = <Widget>[
      if (isError && widget.onRetry != null)
        FilledButton.icon(
          onPressed: widget.onRetry,
          style: AdminButtonStyles.filled(),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(widget.retryLabel!),
        ),
      if (widget.primaryAction case final a?)
        a.icon == null
            ? FilledButton(
                onPressed: a.onPressed,
                style: AdminButtonStyles.filled(),
                child: Text(a.label),
              )
            : FilledButton.icon(
                onPressed: a.onPressed,
                style: AdminButtonStyles.filled(),
                icon: Icon(a.icon, size: 18),
                label: Text(a.label),
              ),
      if (widget.secondaryAction case final a?)
        a.icon == null
            ? OutlinedButton(
                onPressed: a.onPressed,
                style: AdminButtonStyles.outlined(),
                child: Text(a.label),
              )
            : OutlinedButton.icon(
                onPressed: a.onPressed,
                style: AdminButtonStyles.outlined(),
                icon: Icon(a.icon, size: 18),
                label: Text(a.label),
              ),
    ];

    final hasDetails =
        isError && widget.details != null && widget.details!.trim().isNotEmpty;

    return Semantics(
      liveRegion: isError,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: iconBox),
          SizedBox(height: compact ? 12 : 16),
          Semantics(
            header: !compact,
            child: Text(
              widget.title!,
              textAlign: TextAlign.center,
              style: compact
                  ? const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.textPrimary,
                    )
                  : const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textPrimary,
                    ),
            ),
          ),
          if (widget.message != null) ...[
            SizedBox(height: compact ? 4 : 8),
            Text(
              widget.message!,
              textAlign: TextAlign.center,
              style: compact
                  ? AdminText.caption
                  : const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AdminColors.textSecondary,
                    ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            SizedBox(height: compact ? 12 : 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
          if (hasDetails) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() => _showDetails = !_showDetails),
              style: TextButton.styleFrom(
                foregroundColor: AdminColors.textSecondary,
                textStyle: const TextStyle(fontSize: 12),
              ),
              icon: Icon(
                _showDetails
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
              ),
              label: Text(_showDetails ? 'Hide details' : 'Show details'),
            ),
            if (_showDetails)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AdminColors.surface,
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                  border: Border.all(color: AdminColors.border),
                ),
                child: SelectableText(
                  widget.details!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: AdminColors.textSecondary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

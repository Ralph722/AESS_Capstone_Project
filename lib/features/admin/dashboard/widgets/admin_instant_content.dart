import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';

/// Shows page chrome immediately; uses skeleton placeholders while loading.
class AdminInstantContent extends StatelessWidget {
  const AdminInstantContent({
    super.key,
    required this.loading,
    required this.isEmpty,
    required this.child,
    this.empty,
    this.minHeight = 200,
    this.loadingSkeleton,
  });

  final bool loading;
  final bool isEmpty;
  final Widget child;
  final Widget? empty;
  final double minHeight;
  final Widget? loadingSkeleton;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final body = _buildBody();
        if (constraints.maxHeight.isFinite) {
          return SizedBox(
            height: constraints.maxHeight,
            width: constraints.maxWidth,
            child: body,
          );
        }
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: body,
        );
      },
    );
  }

  Widget _buildBody() {
    if (loading && isEmpty) {
      return loadingSkeleton ?? const AdminDirectoryListSkeleton();
    }
    if (!loading && isEmpty) {
      return empty ??
          Center(
            child: Text(
              'No data yet.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
    }
    return child;
  }
}

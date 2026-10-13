import 'package:flutter/material.dart';

/// Asks the admin to confirm before downloading a file that lists
/// graduates by name or contact details. [what] names the file, e.g.
/// "The roster extract".
Future<bool> confirmPersonalDataExport(
  BuildContext context, {
  required String what,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.privacy_tip_outlined),
      title: const Text('This file contains personal data'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Text(
          '$what lists graduates by name and contact details. Download it '
          'only for official alumni office work, keep it in a secure place, '
          'and do not share it outside authorized staff. Personal data is '
          'protected by the Data Privacy Act of 2012 (RA 10173).',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Download'),
        ),
      ],
    ),
  );
  return ok == true;
}

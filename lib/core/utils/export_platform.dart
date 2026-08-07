import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:alumni_system/core/utils/web_file_download.dart';

/// Shown when export/download is attempted off Flutter web (e.g. mobile admin).
const String exportWebOnlyMessage =
    'Export and download are only available in the web admin portal. '
    'Open the admin dashboard in a desktop browser to export files.';

bool get canExportFiles => kIsWeb;

void showExportUnavailableSnackBar(BuildContext context) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(exportWebOnlyMessage),
      duration: Duration(seconds: 4),
    ),
  );
}

/// Returns false on non-web platforms after showing [exportWebOnlyMessage].
bool requireWebExport(BuildContext context) {
  if (kIsWeb) return true;
  showExportUnavailableSnackBar(context);
  return false;
}

bool tryDownloadBytesOnWeb(
  BuildContext context, {
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
}) {
  if (!requireWebExport(context)) return false;
  downloadBytesOnWeb(bytes: bytes, fileName: fileName, mimeType: mimeType);
  return true;
}

bool tryDownloadTextOnWeb(
  BuildContext context, {
  required String content,
  required String fileName,
  String mimeType = 'text/plain',
}) {
  if (!requireWebExport(context)) return false;
  downloadTextOnWeb(
    content: content,
    fileName: fileName,
    mimeType: mimeType,
  );
  return true;
}

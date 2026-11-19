import 'dart:typed_data';

import 'package:alumni_system/core/utils/export_platform.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// Preview a PDF via the system print / layout dialog (web + mobile).
Future<void> previewAlumniPdf({
  required Uint8List bytes,
  required String fileName,
}) {
  return Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: fileName,
  );
}

/// Save or share a PDF for alumni clients.
///
/// - Web: browser download via [tryDownloadBytesOnWeb]
/// - iOS / Android: system share sheet via [Printing.sharePdf]
Future<void> shareOrDownloadAlumniPdf({
  required BuildContext context,
  required Uint8List bytes,
  required String fileName,
}) async {
  if (kIsWeb) {
    final ok = tryDownloadBytesOnWeb(
      context,
      bytes: bytes,
      fileName: fileName,
      mimeType: 'application/pdf',
    );
    if (!ok) {
      throw StateError('Browser download is not available in this environment.');
    }
    return;
  }
  await Printing.sharePdf(bytes: bytes, filename: fileName);
}

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

/// Whether browser download APIs are available on this platform.
bool get isWebFileDownloadSupported => kIsWeb;

/// Triggers a file download in the browser (Flutter web only).
void downloadBytesOnWeb({
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
}) {
  if (!kIsWeb) return;
  final blob = mimeType != null
      ? html.Blob([bytes], mimeType)
      : html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// Triggers a text/CSV download in the browser.
void downloadTextOnWeb({
  required String content,
  required String fileName,
  String mimeType = 'text/plain',
}) {
  if (!kIsWeb) return;
  final blob = html.Blob([content], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

/// Picks a file in the browser and returns its bytes (web only).
Future<Uint8List?> pickFileBytesOnWeb({
  String accept = '.xlsx,.xls,.csv',
}) async {
  if (!kIsWeb) return null;

  final input = html.FileUploadInputElement()..accept = accept;
  input.click();

  await input.onChange.first;
  final file = input.files?.first;
  if (file == null) return null;

  final reader = html.FileReader();
  final completer = Completer<Uint8List?>();
  reader.onLoadEnd.listen((_) {
    final result = reader.result;
    if (result is ByteBuffer) {
      completer.complete(result.asUint8List());
    } else if (result is List<int>) {
      completer.complete(Uint8List.fromList(result));
    } else {
      completer.complete(null);
    }
  });
  reader.onError.listen((_) => completer.complete(null));
  reader.readAsArrayBuffer(file);
  return completer.future;
}

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> downloadBytes(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

Future<bool> copyImageBytes(Uint8List bytes, String mimeType) async {
  final types = {
    if (mimeType.isNotEmpty) mimeType,
    'image/png',
  };
  for (final type in types) {
    try {
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: type),
      );
      final item = web.ClipboardItem({type: blob}.jsify()! as JSObject);
      await web.window.navigator.clipboard.write([item].toJS).toDart;
      return true;
    } catch (_) {
      // Try next MIME type; many browsers only accept image/png.
    }
  }
  return false;
}

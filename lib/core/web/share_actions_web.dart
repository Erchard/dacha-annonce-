import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<bool> shareEventPayload({
  required String title,
  required String text,
  required String url,
  Uint8List? imageBytes,
  String imageName = 'photo.jpg',
  String imageType = 'image/jpeg',
}) async {
  try {
    if (imageBytes != null) {
      final file = web.File(
        [imageBytes.toJS].toJS,
        imageName,
        web.FilePropertyBag(type: imageType),
      );
      final withFile = web.ShareData(
        title: title,
        text: text,
        url: url,
        files: [file].toJS,
      );
      if (web.window.navigator.canShare(withFile)) {
        await web.window.navigator.share(withFile).toDart;
        return true;
      }
    }
    final data = web.ShareData(title: title, text: text, url: url);
    if (web.window.navigator.canShare(data)) {
      await web.window.navigator.share(data).toDart;
      return true;
    }
  } catch (_) {
    // User cancel or unsupported — fall back to Facebook URL.
  }
  return false;
}

void openExternalUrl(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
}

Future<bool> copyTextToClipboard(String text) async {
  try {
    await web.window.navigator.clipboard.writeText(text).toDart;
    return true;
  } catch (_) {
    try {
      final area = web.HTMLTextAreaElement()
        ..value = text
        ..style.position = 'fixed'
        ..style.left = '-9999px';
      web.document.body?.append(area);
      area.select();
      final ok = web.document.execCommand('copy');
      area.remove();
      return ok;
    } catch (_) {
      return false;
    }
  }
}

void downloadTextFile({
  required String fileName,
  required String content,
  String mimeType = 'text/plain;charset=utf-8',
}) {
  final parts = [content.toJS].toJS;
  final blob = web.Blob(parts, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

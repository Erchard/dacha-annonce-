import 'dart:typed_data';

Future<bool> shareEventPayload({
  required String title,
  required String text,
  required String url,
  Uint8List? imageBytes,
  String imageName = 'photo.jpg',
  String imageType = 'image/jpeg',
}) async => false;

void openExternalUrl(String url) {}

Future<bool> copyTextToClipboard(String text) async => false;

void downloadTextFile({
  required String fileName,
  required String content,
  String mimeType = 'text/plain;charset=utf-8',
}) {}

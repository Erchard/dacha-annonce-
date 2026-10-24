import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../web/bytes_actions.dart';

/// Memory image with save/copy actions (Flutter canvas has no native browser
/// right-click “Save image”).
class CopyFriendlyImage extends StatelessWidget {
  const CopyFriendlyImage({
    super.key,
    required this.bytes,
    required this.fileName,
    this.contentType = 'image/jpeg',
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
  final double? width;
  final double? height;
  final BoxFit fit;

  String get _safeName {
    final raw = fileName.trim().isEmpty ? 'photo' : fileName.trim();
    return raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  Future<void> _download(BuildContext context) async {
    await downloadBytes(bytes, _safeName, contentType);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Фото збережено')),
      );
    }
  }

  Future<void> _copy(BuildContext context) async {
    if (kIsWeb) {
      final ok = await copyImageBytes(bytes, contentType);
      if (!context.mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фото скопійовано')),
        );
        return;
      }
      await _download(context);
      return;
    }
    await Clipboard.setData(ClipboardData(text: _safeName));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('На цій платформі збережіть фото через меню'),
        ),
      );
    }
  }

  Future<void> _showActions(BuildContext context, Offset globalPosition) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(value: 'copy', child: Text('Копіювати фото')),
        PopupMenuItem(value: 'save', child: Text('Зберегти фото')),
        PopupMenuItem(value: 'open', child: Text('Відкрити')),
      ],
    );
    if (!context.mounted || selected == null) return;
    switch (selected) {
      case 'copy':
        await _copy(context);
      case 'save':
        await _download(context);
      case 'open':
        await _openPreview(context);
    }
  }

  Future<void> _openPreview(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: InteractiveViewer(
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Закрити'),
                    ),
                    OutlinedButton(
                      onPressed: () => _copy(context),
                      child: const Text('Копіювати'),
                    ),
                    FilledButton(
                      onPressed: () => _download(context),
                      child: const Text('Зберегти'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.memory(
      bytes,
      width: width,
      height: height,
      fit: fit,
    );
    final child = width == null && height == null
        ? SizedBox.expand(child: image)
        : image;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openPreview(context),
        onLongPressStart: (d) => _showActions(context, d.globalPosition),
        onSecondaryTapDown: (d) => _showActions(context, d.globalPosition),
        child: child,
      ),
    );
  }
}

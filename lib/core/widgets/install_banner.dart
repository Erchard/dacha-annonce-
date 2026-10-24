import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../web/pwa_install.dart';

/// Soft prompt to install the web app on the home screen (web only).
class InstallBanner extends StatefulWidget {
  const InstallBanner({super.key});

  @override
  State<InstallBanner> createState() => _InstallBannerState();
}

class _InstallBannerState extends State<InstallBanner> {
  bool _visible = false;
  bool _iosHint = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    onPwaInstallAvailable(() {
      if (mounted) _refresh();
    });
  }

  void _refresh() {
    final dismissed = isPwaInstallDismissed();
    final standalone = isPwaStandalone();
    final canPrompt = canPromptPwaInstall();
    final ios = isIosSafariNotStandalone();
    setState(() {
      _iosHint = ios && !dismissed && !standalone;
      _visible = !dismissed && !standalone && (canPrompt || ios);
    });
  }

  Future<void> _install() async {
    if (_iosHint) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Встановити «Дача»'),
          content: const Text(
            'На iPhone/iPad: Поділитися → На початковий екран.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Зрозуміло'),
            ),
          ],
        ),
      );
      return;
    }
    await promptPwaInstall();
    if (mounted) _refresh();
  }

  void _dismiss() {
    dismissPwaInstall();
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Icon(Icons.install_mobile, color: scheme.primary),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Встановіть «Дача» на головний екран для швидкого доступу.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            TextButton(onPressed: _install, child: const Text('Встановити')),
            IconButton(
              tooltip: 'Закрити',
              onPressed: _dismiss,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

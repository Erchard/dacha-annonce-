import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS()
extension type _BeforeInstallPromptEvent._(JSObject _) implements web.Event {
  external JSPromise<JSAny?> prompt();
}

_BeforeInstallPromptEvent? _deferredPrompt;
bool _hooked = false;
final _listeners = <void Function()>[];

bool isPwaStandalone() {
  try {
    return web.window.matchMedia('(display-mode: standalone)').matches;
  } catch (_) {
    return false;
  }
}

bool canPromptPwaInstall() => _deferredPrompt != null;

bool isIosSafariNotStandalone() {
  final ua = web.window.navigator.userAgent.toLowerCase();
  final ios =
      ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
  return ios && !isPwaStandalone();
}

bool isPwaInstallDismissed() =>
    web.window.sessionStorage.getItem('dacha_install_dismissed') == '1';

void dismissPwaInstall() {
  web.window.sessionStorage.setItem('dacha_install_dismissed', '1');
}

void onPwaInstallAvailable(void Function() listener) {
  _listeners.add(listener);
  _ensureHook();
}

void _ensureHook() {
  if (_hooked) return;
  _hooked = true;
  web.window.addEventListener(
    'beforeinstallprompt',
    (web.Event event) {
      event.preventDefault();
      _deferredPrompt = event as _BeforeInstallPromptEvent;
      for (final listener in List.of(_listeners)) {
        listener();
      }
    }.toJS,
  );
}

Future<bool> promptPwaInstall() async {
  final prompt = _deferredPrompt;
  if (prompt == null) return false;
  try {
    await prompt.prompt().toDart;
    _deferredPrompt = null;
    return true;
  } catch (_) {
    return false;
  }
}

bool isPwaStandalone() => false;
bool canPromptPwaInstall() => false;
bool isIosSafariNotStandalone() => false;
bool isPwaInstallDismissed() => false;
void dismissPwaInstall() {}
void onPwaInstallAvailable(void Function() listener) {}
Future<bool> promptPwaInstall() async => false;

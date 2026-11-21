import 'package:web/web.dart' as web;

const _visitorKey = 'dacha_stats_visitor';
const _viewPrefix = 'dacha_stats_view:';

bool wasPathViewedThisSession(String path) =>
    web.window.sessionStorage.getItem('$_viewPrefix$path') == '1';

void markPathViewedThisSession(String path) {
  web.window.sessionStorage.setItem('$_viewPrefix$path', '1');
}

bool wasVisitorCounted() =>
    web.window.localStorage.getItem(_visitorKey) == '1';

void markVisitorCounted() {
  web.window.localStorage.setItem(_visitorKey, '1');
}

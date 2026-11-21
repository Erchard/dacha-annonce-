/// Non-web: no browser storage — never mark paths/visitors as already counted.
bool wasPathViewedThisSession(String path) => false;

void markPathViewedThisSession(String path) {}

bool wasVisitorCounted() => false;

void markVisitorCounted() {}

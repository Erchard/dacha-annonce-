enum ErrorCode {
  unauthenticated,
  permissionDenied,
  emailNotVerified,
  accountDisabled,
  validation,
  bookingConflict,
  staleVersion,
  notFound,
  networkUnavailable,
  quotaExceeded,
  unexpected,
  unsupported,
}

class DomainException implements Exception {
  const DomainException(this.code, {this.field, this.technicalCode});
  final ErrorCode code;
  final String? field;
  // Store a code, never a document payload or credential.
  final String? technicalCode;
  String get message => switch (code) {
    ErrorCode.unauthenticated => 'Увійдіть до облікового запису.',
    ErrorCode.permissionDenied => 'Недостатньо прав для цієї дії.',
    ErrorCode.emailNotVerified => 'Підтвердьте електронну адресу.',
    ErrorCode.accountDisabled => 'Обліковий запис заблоковано адміністратором.',
    ErrorCode.validation => 'Перевірте введені дані.',
    ErrorCode.bookingConflict =>
      'Цей час уже зайнятий. Виберіть інший інтервал.',
    ErrorCode.staleVersion =>
      'Запис змінився. Оновіть дані перед повторною дією.',
    ErrorCode.notFound => 'Запис не знайдено.',
    ErrorCode.networkUnavailable =>
      'Немає зв’язку із сервером. Спробуйте пізніше.',
    ErrorCode.quotaExceeded => 'Ліміт сервісу вичерпано. Спробуйте пізніше.',
    ErrorCode.unexpected => 'Не вдалося виконати дію.',
    ErrorCode.unsupported => 'Ця можливість ще не реалізована.',
  };
  @override
  String toString() =>
      'DomainException(${code.name}, field: $field, code: $technicalCode)';
}

String checkedText(String value, String field, int min, int max) {
  if (value != value.trim() ||
      value.runes.length < min ||
      value.runes.length > max) {
    throw DomainException(ErrorCode.validation, field: field);
  }
  return value;
}

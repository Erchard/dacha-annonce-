import '../../../core/errors/domain_exception.dart';

const eventDirections = <String>[
  'Емоційна підтримка',
  'Екологія',
  'Культура',
  'Громадська активність',
  'Освіта, просвіта',
  'Толока',
  'Благоустрій Дачі',
  'Психологічна допомога',
  'Майстер-клас',
  'Клуб',
  'Для людей старшого віку',
  'Для дітей',
  'Для молоді',
  'Творчі зустрічі',
  'Концерт',
];

String checkedContactPhone(String value) {
  final phone = value.trim();
  if (phone.isNotEmpty && !RegExp(r'^[+0-9() .-]{5,32}$').hasMatch(phone)) {
    throw const DomainException(ErrorCode.validation, field: 'contactPhone');
  }
  return phone;
}

List<String> checkedDirections(List<dynamic> values) {
  if (values.length > eventDirections.length ||
      values.toSet().length != values.length ||
      values.any((v) => v is! String || !eventDirections.contains(v))) {
    throw const DomainException(ErrorCode.validation, field: 'directions');
  }
  return List.unmodifiable(values.cast<String>());
}

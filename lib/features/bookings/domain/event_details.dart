import 'dart:typed_data';

import '../../../core/errors/domain_exception.dart';

/// Legacy multi-tags kept only for reading old documents.
const legacyEventDirections = <String>[
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

/// @Deprecated Use [eventDirectionOptions]. Kept as alias for gradual UI cleanup.
const eventDirections = eventDirectionOptions;

const participationConditionOptions = <String>[
  'Вхід вільний',
  'Попередня реєстрація',
  'За запрошеннями/ закрита зустріч',
];

const announcementStatusCodes = <String>['planned', 'postponed', 'cancelled'];

const announcementStatusLabels = <String, String>{
  'planned': 'Заплановано',
  'postponed': 'Перенесено',
  'cancelled': 'Скасовано',
};

const eventDirectionOptions = <String>[
  'Громадська активність',
  'Культура та спадщина',
  'Освіта і просвіта',
  'Екологія та зелені практики',
  'Відновлення Дачі',
  'Психологічна підтримка та відновлення',
  'Творчість і рукоділля',
  'Благодійність',
  'Партнерство та співпраця',
  'Дозвілля та спілкування',
];

const eventFormatOptions = <String>[
  'Засідання клубу / зустріч групи',
  'Зустріч / спілкування',
  'Творча зустріч',
  'Концерт / вистава',
  'Лекція',
  'Майстер-клас',
  'Тренінг',
  'Семінар',
  'Консультація',
  'Обговорення / дискусія',
  'Нарада/ робоча зустріч',
  'Толока',
  'Посиденьки',
  'Виставка',
  'Кінопоказ / перегляд з обговоренням',
  'Гра / ігрова зустріч',
  'Екскурсія / прогулянка',
  'Ярмарок',
];

const allWelcomeAudience = 'Усі охочі';

const targetAudienceOptions = <String>[
  allWelcomeAudience,
  'Діти',
  'Сім\'ї з дітьми',
  'Підлітки',
  'Молодь',
  'Дорослі',
  'Жінки',
  'Люди старшого віку',
  'Друзі/ партнери',
];

const coverImageContentTypes = {'image/jpeg', 'image/png', 'image/webp'};
const maxCoverImageBytes = 700000;

class CoverImage {
  CoverImage({
    required Uint8List bytes,
    required String contentType,
    required String fileName,
  }) : bytes = Uint8List.fromList(bytes),
       contentType = contentType.trim(),
       fileName = checkedText(fileName.trim(), 'coverImageFileName', 1, 160) {
    if (this.bytes.isEmpty || this.bytes.length > maxCoverImageBytes) {
      throw const DomainException(ErrorCode.validation, field: 'coverImage');
    }
    if (!coverImageContentTypes.contains(this.contentType)) {
      throw const DomainException(
        ErrorCode.validation,
        field: 'coverImageContentType',
      );
    }
  }

  final Uint8List bytes;
  final String contentType, fileName;

  static CoverImage? optional({
    required dynamic bytes,
    required dynamic contentType,
    required dynamic fileName,
  }) {
    if (bytes == null && contentType == null && fileName == null) return null;
    if (bytes is! Uint8List || contentType is! String || fileName is! String) {
      throw const DomainException(ErrorCode.validation, field: 'coverImage');
    }
    return CoverImage(
      bytes: bytes,
      contentType: contentType,
      fileName: fileName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! CoverImage ||
        contentType != other.contentType ||
        fileName != other.fileName ||
        bytes.length != other.bytes.length) {
      return false;
    }
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != other.bytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(contentType, fileName, bytes.length);
}

String checkedContactPhone(String value) {
  final phone = value.trim();
  if (phone.isNotEmpty && !RegExp(r'^[+0-9() .-]{5,32}$').hasMatch(phone)) {
    throw const DomainException(ErrorCode.validation, field: 'contactPhone');
  }
  return phone;
}

/// Read-compat for old `directions` arrays. Empty is allowed.
List<String> checkedDirections(List<dynamic> values) {
  if (values.isEmpty) return const [];
  if (values.length > legacyEventDirections.length ||
      values.toSet().length != values.length ||
      values.any((v) => v is! String || !legacyEventDirections.contains(v))) {
    throw const DomainException(ErrorCode.validation, field: 'directions');
  }
  return List.unmodifiable(values.cast<String>());
}

String checkedParticipationCondition(String value) {
  final v = value.trim();
  if (!participationConditionOptions.contains(v)) {
    throw const DomainException(
      ErrorCode.validation,
      field: 'participationCondition',
    );
  }
  return v;
}

String checkedAnnouncementStatus(String value) {
  final v = value.trim();
  if (!announcementStatusCodes.contains(v)) {
    throw const DomainException(
      ErrorCode.validation,
      field: 'announcementStatus',
    );
  }
  return v;
}

String checkedEventDirection(String value) {
  final v = value.trim();
  if (!eventDirectionOptions.contains(v)) {
    throw const DomainException(ErrorCode.validation, field: 'eventDirection');
  }
  return v;
}

String checkedEventFormat(String value) {
  final v = value.trim();
  if (!eventFormatOptions.contains(v)) {
    throw const DomainException(ErrorCode.validation, field: 'eventFormat');
  }
  return v;
}

List<String> checkedTargetAudiences(List<dynamic> values) {
  if (values.isEmpty ||
      values.length > targetAudienceOptions.length ||
      values.toSet().length != values.length ||
      values.any((v) => v is! String || !targetAudienceOptions.contains(v))) {
    throw const DomainException(ErrorCode.validation, field: 'targetAudiences');
  }
  final list = values.cast<String>().toList();
  if (list.contains(allWelcomeAudience) && list.length != 1) {
    throw const DomainException(ErrorCode.validation, field: 'targetAudiences');
  }
  return List.unmodifiable(list);
}

String announcementStatusLabel(String code) =>
    announcementStatusLabels[code] ?? code;

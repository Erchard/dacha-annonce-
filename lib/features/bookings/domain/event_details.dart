import 'dart:typed_data';

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

List<String> checkedDirections(List<dynamic> values) {
  if (values.length > eventDirections.length ||
      values.toSet().length != values.length ||
      values.any((v) => v is! String || !eventDirections.contains(v))) {
    throw const DomainException(ErrorCode.validation, field: 'directions');
  }
  return List.unmodifiable(values.cast<String>());
}

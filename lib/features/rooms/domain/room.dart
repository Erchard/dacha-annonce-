import '../../../core/errors/domain_exception.dart';

class Room {
  Room({
    required this.id,
    required this.name,
    required this.description,
    required this.locationLabel,
    required this.capacity,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    required this.lastAuditId,
  }) {
    checkedText(name, 'name', 2, 80);
    if (description.runes.length > 1000 ||
        locationLabel.runes.length > 160 ||
        capacity != null && (capacity! < 1 || capacity! > 1000) ||
        sortOrder < 0 ||
        sortOrder > 10000 ||
        revision < 1) {
      throw const DomainException(ErrorCode.validation, field: 'room');
    }
  }
  final String id, name, description, locationLabel, lastAuditId;
  final int? capacity;
  final bool isActive;
  final int sortOrder, revision;
  final DateTime createdAt, updatedAt;
}

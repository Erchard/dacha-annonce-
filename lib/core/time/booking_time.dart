import '../errors/domain_exception.dart';

abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  DateTime now() => DateTime.now().toUtc();
}

class FixedClock implements Clock {
  FixedClock(DateTime instant) : instant = instant.toUtc();
  final DateTime instant;
  @override
  DateTime now() => instant;
}

class BookingInterval {
  BookingInterval(DateTime start, DateTime end)
    : start = start.toUtc(),
      end = end.toUtc() {
    if (this.start.microsecondsSinceEpoch < 0 ||
        this.start.microsecondsSinceEpoch % slot.inMicroseconds != 0 ||
        this.end.microsecondsSinceEpoch % slot.inMicroseconds != 0 ||
        duration < slot ||
        duration > block) {
      throw const DomainException(ErrorCode.validation, field: 'interval');
    }
  }
  static const slot = Duration(minutes: 30);
  static const block = Duration(hours: 6);
  final DateTime start, end;
  Duration get duration => end.difference(start);
  void validateFuture(Clock clock) {
    final now = clock.now();
    if (!start.isAfter(now) ||
        start.isAfter(now.add(const Duration(days: 180)))) {
      throw const DomainException(ErrorCode.validation, field: 'startAt');
    }
  }

  bool overlaps(BookingInterval other) =>
      start.isBefore(other.end) && other.start.isBefore(end);
  Map<String, Set<String>> get slotsByBlock {
    final result = <String, Set<String>>{};
    for (
      var t = start.microsecondsSinceEpoch;
      t < end.microsecondsSinceEpoch;
      t += slot.inMicroseconds
    ) {
      final base = t ~/ block.inMicroseconds * block.inMicroseconds;
      final id = (base ~/ Duration.microsecondsPerSecond).toString();
      final index = (t - base) ~/ slot.inMicroseconds;
      (result[id] ??= <String>{}).add('s${index.toString().padLeft(2, '0')}');
    }
    return Map.unmodifiable(
      result.map((id, slots) => MapEntry(id, Set<String>.unmodifiable(slots))),
    );
  }

  List<String> get blockIds => List.unmodifiable(slotsByBlock.keys);
}

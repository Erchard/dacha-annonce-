import '../../../core/domain/page.dart';
import 'public_event.dart';

abstract interface class PublicEventRepository {
  Future<Page<PublicEvent>> listRange(
    DateTime start,
    DateTime end,
    PageRequest page, {
    String? roomId,
    List<String> directions = const [],
  });
  Future<PublicEvent?> getPublishedEvent(String id);
}

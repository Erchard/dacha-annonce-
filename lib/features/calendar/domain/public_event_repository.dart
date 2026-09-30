import '../../../core/domain/page.dart';
import 'public_event.dart';

abstract interface class PublicEventRepository {
  Future<Page<PublicEvent>> listRange(
    DateTime start,
    DateTime end,
    PageRequest page, {
    String? roomId,
  });
  Future<PublicEvent?> getPublishedEvent(String id);
}

import '../errors/domain_exception.dart';

class PageRequest {
  PageRequest({this.limit = 25, this.after}) {
    if (limit < 1 || limit > 100) {
      throw const DomainException(ErrorCode.validation, field: 'limit');
    }
  }
  final int limit;
  final PageCursor? after;
}

class PageCursor {
  const PageCursor({
    required this.queryKey,
    required this.value,
    required this.id,
  });
  final String queryKey, id;
  final Object value;
}

class Page<T> {
  Page(Iterable<T> items, this.next) : items = List.unmodifiable(items);
  final List<T> items;
  final PageCursor? next;
}

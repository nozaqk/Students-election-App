import '../api/models.dart';

const Map<String, int> _rank = {
  'ACTIVE': 0,
  'PAUSED': 1,
  'SCHEDULED': 2,
  'ENDED': 3,
  'COUNTING': 3,
  'VERIFIED': 3,
  'FINALIZED': 3,
  'PUBLISHED': 4,
  'DEACTIVATED': 5,
};

int rankOf(String status) => _rank[status] ?? 9;

/// Orders elections so the ones that need attention come first (open voting, then paused,
/// upcoming, ended, published, withdrawn). The sort is stable: elections with the same status keep
/// the order the server returned them in.
List<T> byImportance<T extends ElectionSummary>(Iterable<T> list) {
  final indexed = list.toList().asMap().entries.toList()
    ..sort((a, b) {
      final r = rankOf(a.value.status).compareTo(rankOf(b.value.status));
      return r != 0 ? r : a.key.compareTo(b.key);
    });
  return indexed.map((e) => e.value).toList();
}

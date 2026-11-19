/// Data returned by the election backend. Every type parses defensively so a missing or
/// unexpected field never crashes the app.
library;

String _str(Object? v, [String fallback = '']) => v == null ? fallback : v.toString();
String? _strOrNull(Object? v) => v?.toString();
int _int(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? fallback;
}

int? _intOrNull(Object? v) => v == null ? null : _int(v);
int _atLeastOne(int n) => n < 1 ? 1 : n;
bool _bool(Object? v) => v == true || v == 'true' || v == 1;
DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v.toString());
List<Map<String, dynamic>> _list(Object? v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];
Map<String, dynamic> _map(Object? v) => v is Map<String, dynamic> ? v : const {};

/// Server-composed status text shown to the student ("Voting open", "Results published", …).
class UiState {
  const UiState({required this.state, required this.headline, required this.body});

  factory UiState.fromJson(Map<String, dynamic> j) =>
      UiState(state: _str(j['state']), headline: _str(j['headline']), body: _str(j['body']));

  final String state;
  final String headline;
  final String body;
}

class ElectionSummary {
  const ElectionSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.startAt,
    required this.endAt,
    required this.startLabel,
    required this.endLabel,
    required this.requirePresence,
    required this.hasVoted,
    required this.canVote,
    required this.ui,
  });

  factory ElectionSummary.fromJson(Map<String, dynamic> j) => ElectionSummary(
        id: _str(j['id']),
        title: _str(j['title']),
        description: _str(j['description']),
        status: _str(j['status']),
        startAt: _date(j['startAt']),
        endAt: _date(j['endAt']),
        startLabel: _strOrNull(j['startLabel']),
        endLabel: _strOrNull(j['endLabel']),
        requirePresence: _bool(j['requirePresence']),
        hasVoted: _bool(j['hasVoted']),
        canVote: _bool(j['canVote']),
        ui: UiState.fromJson(_map(j['ui'])),
      );

  final String id;
  final String title;
  final String description;
  final String status;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? startLabel;
  final String? endLabel;
  final bool requirePresence;
  final bool hasVoted;
  final bool canVote;
  final UiState ui;

  bool get isActive => status == 'ACTIVE';
  bool get isScheduled => status == 'SCHEDULED';
  bool get isPublished => status == 'PUBLISHED';
}

class EmptyState {
  const EmptyState({required this.headline, required this.body});

  factory EmptyState.fromJson(Map<String, dynamic> j) =>
      EmptyState(headline: _str(j['headline']), body: _str(j['body']));

  final String headline;
  final String body;
}

class Overview {
  const Overview({required this.serverTime, required this.elections, required this.empty});

  factory Overview.fromJson(Map<String, dynamic> j) => Overview(
        serverTime: _date(j['serverTime']) ?? DateTime.now(),
        elections: _list(j['elections']).map(ElectionSummary.fromJson).toList(),
        empty: j['empty'] == null ? null : EmptyState.fromJson(_map(j['empty'])),
      );

  final DateTime serverTime;
  final List<ElectionSummary> elections;
  final EmptyState? empty;
}

class Candidate {
  const Candidate({
    required this.id,
    required this.name,
    required this.number,
    required this.photoUrl,
    required this.manifesto,
    required this.department,
    required this.programme,
  });

  factory Candidate.fromJson(Map<String, dynamic> j) => Candidate(
        id: _str(j['id']),
        name: _str(j['name']),
        number: _int(j['number']),
        photoUrl: _strOrNull(j['photoUrl']),
        manifesto: _str(j['manifesto']),
        department: _strOrNull(j['department']),
        programme: _strOrNull(j['programme']),
      );

  final String id;
  final String name;
  final int number;
  final String? photoUrl;
  final String manifesto;
  final String? department;
  final String? programme;
}

class Position {
  const Position({
    required this.id,
    required this.title,
    required this.maxSelections,
    required this.allowAbstain,
    required this.candidates,
  });

  factory Position.fromJson(Map<String, dynamic> j) => Position(
        id: _str(j['id']),
        title: _str(j['title']),
        maxSelections: _atLeastOne(_int(j['maxSelections'], 1)),
        allowAbstain: _bool(j['allowAbstain']),
        candidates: _list(j['candidates']).map(Candidate.fromJson).toList(),
      );

  final String id;
  final String title;
  final int maxSelections;
  final bool allowAbstain;
  final List<Candidate> candidates;

  bool get single => maxSelections == 1;
}

class ElectionDetail extends ElectionSummary {
  const ElectionDetail({
    required super.id,
    required super.title,
    required super.description,
    required super.status,
    required super.startAt,
    required super.endAt,
    required super.startLabel,
    required super.endLabel,
    required super.requirePresence,
    required super.hasVoted,
    required super.canVote,
    required super.ui,
    required this.positions,
    required this.serverTime,
  });

  factory ElectionDetail.fromJson(Map<String, dynamic> j) {
    final s = ElectionSummary.fromJson(j);
    return ElectionDetail(
      id: s.id,
      title: s.title,
      description: s.description,
      status: s.status,
      startAt: s.startAt,
      endAt: s.endAt,
      startLabel: s.startLabel,
      endLabel: s.endLabel,
      requirePresence: s.requirePresence,
      hasVoted: s.hasVoted,
      canVote: s.canVote,
      ui: s.ui,
      positions: _list(j['positions']).map(Position.fromJson).toList(),
      serverTime: _date(j['serverTime']) ?? DateTime.now(),
    );
  }

  final List<Position> positions;
  final DateTime serverTime;
}

class CandidateResult {
  const CandidateResult({
    required this.candidateId,
    required this.name,
    required this.number,
    required this.photoUrl,
    required this.votes,
    required this.winner,
    required this.tied,
  });

  factory CandidateResult.fromJson(Map<String, dynamic> j) => CandidateResult(
        candidateId: _str(j['candidateId']),
        name: _str(j['name']),
        number: _int(j['number']),
        photoUrl: _strOrNull(j['photoUrl']),
        votes: _int(j['votes']),
        winner: _bool(j['winner']),
        tied: _bool(j['tied']),
      );

  final String candidateId;
  final String name;
  final int number;
  final String? photoUrl;
  final int votes;
  final bool winner;
  final bool tied;
}

class PositionResult {
  const PositionResult({
    required this.positionId,
    required this.title,
    required this.seats,
    required this.abstained,
    required this.totalVotes,
    required this.tie,
    required this.runoffRequired,
    required this.candidates,
  });

  factory PositionResult.fromJson(Map<String, dynamic> j) => PositionResult(
        positionId: _str(j['positionId']),
        title: _str(j['title']),
        seats: _int(j['seats'], 1),
        abstained: _int(j['abstained']),
        totalVotes: _int(j['totalVotes']),
        tie: _bool(j['tie']),
        runoffRequired: _bool(j['runoffRequired']),
        candidates: _list(j['candidates']).map(CandidateResult.fromJson).toList(),
      );

  final String positionId;
  final String title;
  final int seats;
  final int abstained;
  final int totalVotes;
  final bool tie;
  final bool runoffRequired;
  final List<CandidateResult> candidates;

  /// Share of the position's votes a candidate received, 0..1.
  double share(CandidateResult c) => totalVotes > 0 ? c.votes / totalVotes : 0;
}

class Results {
  const Results({
    required this.id,
    required this.title,
    required this.status,
    required this.publishedLabel,
    required this.turnout,
    required this.results,
  });

  factory Results.fromJson(Map<String, dynamic> j) => Results(
        id: _str(j['id']),
        title: _str(j['title']),
        status: _str(j['status']),
        publishedLabel: _strOrNull(j['publishedLabel']),
        turnout: _int(j['turnout']),
        results: _list(j['results']).map(PositionResult.fromJson).toList(),
      );

  final String id;
  final String title;
  final String status;
  final String? publishedLabel;
  final int turnout;
  final List<PositionResult> results;
}

/// The signed-in student's profile.
class Me {
  const Me({
    required this.indexNumber,
    required this.fullName,
    required this.department,
    required this.programme,
    required this.level,
    required this.semester,
    required this.officialLevel,
  });

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        indexNumber: _str(j['indexNumber']),
        fullName: _str(j['fullName']),
        department: _str(j['department']),
        programme: _str(j['programme']),
        level: _int(j['level'], 100),
        semester: _intOrNull(j['semester']),
        officialLevel: _int(j['officialLevel'], 100),
      );

  final String indexNumber;
  final String fullName;
  final String department;
  final String programme;
  final int level;
  final int? semester;
  final int officialLevel;
}

/// Single-use permission to cast a ballot, issued after presence verification.
class VoteAuthorization {
  const VoteAuthorization({required this.token, required this.expiresAt});

  factory VoteAuthorization.fromJson(Map<String, dynamic> j) => VoteAuthorization(
        token: _str(j['authorization']),
        expiresAt: _date(j['expiresAt']) ?? DateTime.now(),
      );

  final String token;
  final DateTime expiresAt;
}

/// The student's selection for one position on the ballot.
class PositionChoice {
  const PositionChoice({this.candidateIds = const [], this.abstain = false});

  final List<String> candidateIds;
  final bool abstain;

  bool get complete => abstain || candidateIds.isNotEmpty;

  Map<String, dynamic> toJson(String positionId) => {
        'positionId': positionId,
        'candidateIds': abstain ? const <String>[] : candidateIds,
        'abstain': abstain,
      };
}

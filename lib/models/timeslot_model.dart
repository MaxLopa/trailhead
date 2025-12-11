class TimeRange {
  final String start;
  final String end;

  const TimeRange({required this.start, required this.end});

  factory TimeRange.fromMap(Map<String, dynamic> map) {
    return TimeRange(start: map['start'] as String, end: map['end'] as String);
  }

  Map<String, dynamic> toMap() {
    return {'start': start, 'end': end};
  }
}

class WeeklyAvailability {
  static final List<WeeklyAvailability> presets = [
    // Weekdays 9–5 (weekend off)
    WeeklyAvailability({
      DateTime.monday: [TimeRange(start: '09:00', end: '17:00')],
      DateTime.tuesday: [TimeRange(start: '09:00', end: '17:00')],
      DateTime.wednesday: [TimeRange(start: '09:00', end: '17:00')],
      DateTime.thursday: [TimeRange(start: '09:00', end: '17:00')],
      DateTime.friday: [TimeRange(start: '09:00', end: '17:00')],
      DateTime.saturday: [],
      DateTime.sunday: [],
    }, title: 'Weekdays 9AM to 5PM'),

    // Every day 10–6
    WeeklyAvailability({
      DateTime.monday: [TimeRange(start: '10:00', end: '18:00')],
      DateTime.tuesday: [TimeRange(start: '10:00', end: '18:00')],
      DateTime.wednesday: [TimeRange(start: '10:00', end: '18:00')],
      DateTime.thursday: [TimeRange(start: '10:00', end: '18:00')],
      DateTime.friday: [TimeRange(start: '10:00', end: '18:00')],
      DateTime.saturday: [TimeRange(start: '10:00', end: '18:00')],
      DateTime.sunday: [TimeRange(start: '10:00', end: '18:00')],
    }, title: 'Every day 10AM to 6PM'),

    // Weekend only 12–4 (weekdays off)
    WeeklyAvailability({
      DateTime.monday: [],
      DateTime.tuesday: [],
      DateTime.wednesday: [],
      DateTime.thursday: [],
      DateTime.friday: [],
      DateTime.saturday: [TimeRange(start: '12:00', end: '16:00')],
      DateTime.sunday: [TimeRange(start: '12:00', end: '16:00')],
    }, title: 'Weekend 12pm to 4PM'),
  ];

  final String title;
  final Map<int, List<TimeRange>> days;

  const WeeklyAvailability(this.days, {this.title = ''});

  /// Firestore -> WeeklyAvailability
  factory WeeklyAvailability.fromMap(Map<String, dynamic> map) {
    final title = map['title'] as String? ?? '';

    final rawDays = map['days'] as Map<String, dynamic>? ?? {};

    final parsed = <int, List<TimeRange>>{};

    rawDays.forEach((key, value) {
      final dayInt = int.parse(key); // "1" -> 1, etc.
      final list =
          (value as List)
              .map(
                (v) => TimeRange.fromMap(Map<String, dynamic>.from(v as Map)),
              )
              .toList();
      parsed[dayInt] = list;
    });

    return WeeklyAvailability(parsed, title: title);
  }

  /// WeeklyAvailability -> Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'days': days.map(
        (day, ranges) => MapEntry(
          day.toString(), // int -> String key
          ranges.map((r) => r.toMap()).toList(),
        ),
      ),
    };
  }

  TimeRange? getDayRange(
    DateTime weekday,
    Map<String, List<TimeRange>> exception,
  ) {
    if (!(days.isEmpty && exception.isEmpty)) {
      final key = _getDayKey(weekday);
      if (exception.containsKey(key)) return exception[key]!.first;
      return days[weekday.weekday]?.first;
    }
    return null;
  }

  String _getDayKey(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return "$y-$m-$d";
  }
}

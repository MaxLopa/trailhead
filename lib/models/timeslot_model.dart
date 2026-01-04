class TimeRange {
  final String start;
  final String end;
  bool booked;
  String bookingId;

  TimeRange({
    required this.start,
    required this.end,
    this.booked = false,
    this.bookingId = '',
  });

  factory TimeRange.fromMap(Map<String, dynamic> map) {
    return TimeRange(
      start: map['start'] as String,
      end: map['end'] as String,
      booked: map['booked'] as bool? ?? false,
      bookingId: map['bookingId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'start': start,
      'end': end,
      'booked': booked,
      'bookingId': bookingId,
    };
  }

  static bool equalRange(TimeRange a, TimeRange b) {
    return a.start == b.start && a.end == b.end;
  }
}

class WeeklyAvailability {
  final String title;
  final Map<int, List<TimeRange>> days;

  const WeeklyAvailability(this.days, {this.title = ''});

  const WeeklyAvailability.empty() : days = const {}, title = '';

  WeeklyAvailability.copy(WeeklyAvailability weeklyAvailability)
    : days = weeklyAvailability.days,
      title = weeklyAvailability.title;

  factory WeeklyAvailability.deepCopy(WeeklyAvailability other) {
    final newDays = other.days.map((day, ranges) {
      return MapEntry(
        day,
        ranges.map((r) => TimeRange.fromMap(r.toMap())).toList(),
      );
    });
    return WeeklyAvailability(newDays, title: other.title);
  }

  factory WeeklyAvailability.fromMap(Map<String, dynamic> map) {
    final title = map['title'] as String? ?? '';
    final rawDays = map['days'] as Map<String, dynamic>? ?? {};
    final parsed = <int, List<TimeRange>>{};

    rawDays.forEach((key, value) {
      final dayInt = int.parse(key);
      final list =
          (value as List)
              .map(
                (v) => TimeRange.fromMap(Map<String, dynamic>.from(v as Map)),
              )
              .toList();
      parsed[dayInt] = list;
    });

    var wkAvailability = WeeklyAvailability(parsed, title: title);
    return wkAvailability;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'days': days.map(
        (day, ranges) =>
            MapEntry(day.toString(), ranges.map((r) => r.toMap()).toList()),
      ),
    };
  }

  List<TimeRange> operator [](int weekday) {
    return days[weekday] ?? [];
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

  static final List<WeeklyAvailability> presets = [
    WeeklyAvailability({
      DateTime.monday: [TimeRange(start: '09:00', end: '17:00')],
      DateTime.tuesday: [TimeRange(start: '09:00', end: '17:00')],
      DateTime.wednesday: [TimeRange(start: '09:00', end: '17:00')],
      DateTime.thursday: [TimeRange(start: '09:00', end: '17:00')],
      DateTime.friday: [TimeRange(start: '09:00', end: '17:00')],
      DateTime.saturday: [],
      DateTime.sunday: [],
    }, title: 'Weekdays 9AM to 5PM'),
    WeeklyAvailability({
      DateTime.monday: [TimeRange(start: '10:00', end: '18:00')],
      DateTime.tuesday: [TimeRange(start: '10:00', end: '18:00')],
      DateTime.wednesday: [TimeRange(start: '10:00', end: '18:00')],
      DateTime.thursday: [TimeRange(start: '10:00', end: '18:00')],
      DateTime.friday: [TimeRange(start: '10:00', end: '18:00')],
      DateTime.saturday: [TimeRange(start: '10:00', end: '18:00')],
      DateTime.sunday: [TimeRange(start: '10:00', end: '18:00')],
    }, title: 'Every day 10AM to 6PM'),
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
}

class Availability {
  WeeklyAvailability defaultSchedule;
  List<WeeklyAvailability> schedules;
  List<WkOverride> overrides = [];
  Map<DateTime, WeeklyAvailability> currAvailability = {};

  Availability.initial(this.defaultSchedule, this.schedules);

  Availability(this.defaultSchedule, this.schedules, this.overrides, this.currAvailability);

  Availability.empty()
    : defaultSchedule = WeeklyAvailability.empty(),
      schedules = [],
      overrides = [],
      currAvailability = {};

  factory Availability.fromMap(Map<String, dynamic> map) {
    var availability = Availability.initial(
      WeeklyAvailability.fromMap(
        Map<String, dynamic>.from(map['defaultSchedule']),
      ),
      (map['schedules'] as List)
          .map((s) => WeeklyAvailability.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
    );
    availability.overrides =
        (map['overides'] as List)
            .map((o) => WkOverride.fromMap(Map<String, dynamic>.from(o)))
            .toList();
    availability.currAvailability =
        (map['currAvailability'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(
            DateTime.parse(key),
            WeeklyAvailability.fromMap(Map<String, dynamic>.from(value)),
          ),
        );
    return availability;
  }

  Map<String, dynamic> toMap() {
    return {
      'defaultSchedule': defaultSchedule.toMap(),
      'schedules': schedules.map((s) => s.toMap()).toList(),
      'overides': overrides.map((o) => o.toMap()).toList(),
      'currAvailability': currAvailability.map(
        (date, availability) =>
            MapEntry(date.toIso8601String(), availability.toMap()),
      ),
    };
  }

  bool get isNotEmpty => schedules.isNotEmpty;

  WeeklyAvailability getSchedule({DateTime? date}) {
    date = date ?? DateTime.now();
    if (overrides.isEmpty) {
      return defaultSchedule;
    } else {
      return WkOverride.checkException(overrides, targetDate: date) ??
          defaultSchedule;
    }
  }

  List<bool> areSlotsAvailable(List<TimeRange> slots, DateTime date) {
    List<bool> results = [];
    var keyDate = date.subtract(Duration(days: date.weekday - 1));
    if (!currAvailability.containsKey(keyDate)) {
      initWeek(date);
    }
    var weekSchedule = currAvailability[keyDate]!;
    for (var slot in slots) {
      bool isBooked = false;
      for (var bookedSlot in weekSchedule.days[date.weekday]!) {
        if (TimeRange.equalRange(slot, bookedSlot) && bookedSlot.booked) {
          isBooked = true;
          break;
        }
      }
      results.add(isBooked);
    }
    return results;
  }

  void bookSlots(List<TimeRange> slots, DateTime date) {
    var keyDate = date.subtract(Duration(days: date.weekday - 1));
    for (var slot in slots) {
      slot.booked = true;
    }

    if (currAvailability.containsKey(keyDate)) {
      currAvailability[keyDate]?.days[date.weekday] =
          currAvailability[keyDate]!.days[date.weekday]!.map((timeRange) {
            for (var slot in slots) {
              if (TimeRange.equalRange(timeRange, slot)) {
                return slot;
              }
            }
            return timeRange;
          }).toList();
    } else {
      var newWeek = WeeklyAvailability.deepCopy(getSchedule(date: date));
      newWeek.days[date.weekday] =
          newWeek.days[date.weekday]!.map((timeRange) {
            for (var slot in slots) {
              if (TimeRange.equalRange(timeRange, slot)) {
                return slot;
              }
            }
            return timeRange;
          }).toList();

      currAvailability.addAll({keyDate: newWeek});
    }
  }

  void unbookSlots(List<TimeRange> slots, DateTime date) {
    var keyDate = date.subtract(Duration(days: date.weekday - 1));
    if (!currAvailability.containsKey(keyDate)) return;

    for (var slot in slots) {
      slot.booked = false;
    }

    currAvailability[keyDate]?.days[date.weekday] =
        currAvailability[keyDate]!.days[date.weekday]!.map((timeRange) {
          for (var slot in slots) {
            if (TimeRange.equalRange(timeRange, slot)) {
              return slot;
            }
          }
          return timeRange;
        }).toList();
  }

  void initWeek(DateTime date) {
    var keyDate = date.subtract(Duration(days: date.weekday - 1));
    if (currAvailability.containsKey(keyDate)) return;

    var weekSchedule = WeeklyAvailability.deepCopy(getSchedule(date: date));
    (DateTime, DateTime) dayRange = (keyDate, keyDate.add(Duration(days: 6)));

    for (var override in overrides) {
      if (override.startException.isAfter(dayRange.$2) ||
          override.endException.isBefore(dayRange.$1)) {
        continue;
      } else {
        for (var i = 0; i < 7; i++) {
          DateTime currentDay = keyDate.add(Duration(days: i));
          if ((currentDay.isAfter(override.startException) ||
                  currentDay.isAtSameMomentAs(override.startException)) &&
              (currentDay.isBefore(override.endException) ||
                  currentDay.isAtSameMomentAs(override.endException))) {
            weekSchedule.days[currentDay.weekday] =
                override.overrideSchedule.days[currentDay.weekday]!;
          }
        }
      }
    }
    currAvailability.addAll({keyDate: weekSchedule});
  }

  void initMonth(DateTime date) {
    DateTime firstDayOfMonth = DateTime(date.year, date.month, 1);
    DateTime lastDayOfMonth = DateTime(date.year, date.month + 1, 0);

    for (
      var i = 0;
      i <= lastDayOfMonth.difference(firstDayOfMonth).inDays;
      i += 7
    ) {
      DateTime currentDay = firstDayOfMonth.add(Duration(days: i));
      initWeek(currentDay);
    }
  }

  void addOveride(List<WkOverride> overrides) =>
      this.overrides.addAll(overrides);

  void addSchedule(WeeklyAvailability schedule) => schedules.add(schedule);

  void removeSchedule(WeeklyAvailability schedule) =>
      schedules.remove(schedule);

  void setDefaultSchedule(WeeklyAvailability schedule) =>
      defaultSchedule = schedule;
}

class WkOverride {
  final WeeklyAvailability overrideSchedule;
  final DateTime startException;
  final DateTime endException;
  final int colorValue;

  WkOverride(
    this.overrideSchedule,
    this.startException,
    this.endException, {
    this.colorValue = 0xFF2196F3,
  });

  factory WkOverride.fromMap(Map<String, dynamic> map) {
    return WkOverride(
      WeeklyAvailability.fromMap(
        Map<String, dynamic>.from(map['overrideSchedule']),
      ),
      DateTime.parse(map['startException'] as String),
      DateTime.parse(map['endException'] as String),
      colorValue: map['colorValue'] as int? ?? 0xFF2196F3, // Handle migration
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'overrideSchedule': overrideSchedule.toMap(),
      'startException': startException.toIso8601String(),
      'endException': endException.toIso8601String(),
      'colorValue': colorValue, // Save it
    };
  }

  static WeeklyAvailability? checkException(
    List<WkOverride> overrides, {
    DateTime? targetDate,
  }) {
    final dateToCheck = targetDate ?? DateTime.now();
    for (final entry in overrides) {
      final start = DateTime(
        entry.startException.year,
        entry.startException.month,
        entry.startException.day,
      );
      final end = DateTime(
        entry.endException.year,
        entry.endException.month,
        entry.endException.day,
      );
      final current = DateTime(
        dateToCheck.year,
        dateToCheck.month,
        dateToCheck.day,
      );

      if ((current.isAtSameMomentAs(start) || current.isAfter(start)) &&
          (current.isAtSameMomentAs(end) || current.isBefore(end))) {
        return entry.overrideSchedule;
      }
    }
    return null;
  }
}

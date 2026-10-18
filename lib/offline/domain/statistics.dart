import 'offline_models.dart';

enum StatsPeriod { day, week, month }

class DaySummary {
  const DaySummary(
    this.date,
    this.intake,
    this.exercise,
    this.complete,
    this.recorded,
    this.estimatedCount,
  );

  final DateTime date;
  final double intake;
  final double exercise;
  final bool complete;
  final bool recorded;
  final int estimatedCount;
}

class PeriodSummary {
  PeriodSummary(this.start, this.end, this.days);

  final DateTime start;
  final DateTime end;
  final List<DaySummary> days;

  double get totalIntake => days.fold(0, (sum, day) => sum + day.intake);
  double get totalExercise => days.fold(0, (sum, day) => sum + day.exercise);
  int get completeCount => days.where((day) => day.complete).length;
  int get recordedCount => days.where((day) => day.recorded).length;
  double? get averageIntake => completeCount == 0
      ? null
      : days
                .where((day) => day.complete)
                .fold<double>(0, (sum, day) => sum + day.intake) /
            completeCount;
}

PeriodSummary summarize(
  OfflineState state,
  DateTime selected,
  StatsPeriod period, {
  DateTime? now,
}) {
  final day = calendarDay(selected);
  final today = calendarDay(now ?? DateTime.now());
  final DateTime start;
  final DateTime end;
  switch (period) {
    case StatsPeriod.day:
      start = day;
      end = DateTime(day.year, day.month, day.day + 1);
    case StatsPeriod.week:
      start = DateTime(day.year, day.month, day.day - day.weekday + 1);
      end = DateTime(start.year, start.month, start.day + 7);
    case StatsPeriod.month:
      start = DateTime(day.year, day.month);
      end = DateTime(day.year, day.month + 1);
  }
  final intake = <String, double>{};
  final estimated = <String, int>{};
  for (final log in state.logs) {
    final key = dayKey(log.date);
    intake.update(
      key,
      (value) => value + log.calories,
      ifAbsent: () => log.calories,
    );
    if (log.estimated) {
      estimated.update(key, (value) => value + 1, ifAbsent: () => 1);
    }
  }
  final days = <DaySummary>[];
  for (
    var date = start;
    date.isBefore(end) && !date.isAfter(today);
    date = DateTime(date.year, date.month, date.day + 1)
  ) {
    final key = dayKey(date);
    days.add(
      DaySummary(
        date,
        intake[key] ?? 0,
        state.exercise[key] ?? 0,
        state.completeDays.contains(key),
        intake.containsKey(key),
        estimated[key] ?? 0,
      ),
    );
  }
  return PeriodSummary(start, end, List.unmodifiable(days));
}

String normalizedSearch(String query) {
  const variants = {
    '雞': '鸡',
    '飯': '饭',
    '粥': '粥',
    '麵': '面',
    '麪': '面',
    '蝦': '虾',
    '魚': '鱼',
    '豬': '猪',
    '燒': '烧',
    '腸': '肠',
    '蒸': '蒸',
    '湯': '汤',
    '餃': '饺',
    '醬': '酱',
    '鳳': '凤',
    '爪': '爪',
    '絲': '丝',
    '鹽': '盐',
    '蔥': '葱',
    '薑': '姜',
    '燉': '炖',
    '鴨': '鸭',
    '鵝': '鹅',
    '餅': '饼',
  };
  return query
      .toLowerCase()
      .split('')
      .map((c) => variants[c] ?? c)
      .join()
      .replaceAll(RegExp(r'\s+'), '');
}

List<LocalFood> searchFoods(Iterable<LocalFood> foods, String query) {
  final tokens = query
      .trim()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .map(normalizedSearch)
      .toList();
  return foods.where((food) {
    final text = normalizedSearch(
      '${food.name} ${food.category} ${food.aliases.join(' ')}',
    );
    return tokens.every(text.contains);
  }).toList();
}

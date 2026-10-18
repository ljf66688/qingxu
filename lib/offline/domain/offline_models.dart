import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime calendarDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

double validNumber(Object? value, {double min = 0, double max = 100000}) {
  if (value is! num || !value.isFinite || value < min || value > max) {
    throw const FormatException('数值无效或超出范围');
  }
  return value.toDouble();
}

enum MealSlot {
  breakfast('早餐', IntakeTypeEntity.breakfast),
  lunch('午餐', IntakeTypeEntity.lunch),
  dinner('晚餐', IntakeTypeEntity.dinner);

  const MealSlot(this.label, this.upstreamType);
  final String label;
  final IntakeTypeEntity upstreamType;
}

class LocalFood {
  const LocalFood({
    required this.id,
    required this.name,
    required this.kcal100,
    required this.category,
    required this.note,
    required this.source,
    this.aliases = const [],
    this.custom = false,
    this.referenceKcal100,
  });

  final String id;
  final String name;
  final double kcal100;
  final String category;
  final String note;
  final String source;
  final List<String> aliases;
  final bool custom;
  final double? referenceKcal100;

  LocalFood withEnergy(double value) => LocalFood(
    id: id,
    name: name,
    kcal100: validNumber(value, max: 1000),
    category: category,
    note: note,
    source: source,
    aliases: aliases,
    custom: custom,
    referenceKcal100: referenceKcal100 ?? kcal100,
  );

  MealEntity toMealEntity() => MealEntity(
    code: id,
    name: name,
    url: source,
    mealQuantity: '100',
    mealUnit: 'g',
    servingQuantity: 100,
    servingUnit: 'g',
    servingSize: '100 g',
    nutriments: MealNutrimentsEntity(
      energyKcal100: kcal100,
      carbohydrates100: null,
      fat100: null,
      proteins100: null,
      sugars100: null,
      saturatedFat100: null,
      fiber100: null,
    ),
    source: MealSourceEntity.custom,
    detailed: true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kcal100': kcal100,
    'category': category,
    'note': note,
    'source': source,
    'aliases': aliases,
    'custom': custom,
    'referenceKcal100': referenceKcal100,
  };

  factory LocalFood.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String).trim();
    if (name.isEmpty) throw const FormatException('食物名称为空');
    return LocalFood(
      id: json['id'] as String,
      name: name,
      kcal100: validNumber(json['kcal100'], max: 1000),
      category: json['category'] as String,
      note: json['note'] as String,
      source: json['source'] as String,
      aliases: List<String>.from(json['aliases'] as List? ?? []),
      custom: json['custom'] as bool? ?? false,
      referenceKcal100: json['referenceKcal100'] == null
          ? null
          : validNumber(json['referenceKcal100'], max: 1000),
    );
  }
}

/// A food definition is copied into each log. Editing the catalogue can never
/// change historical calories. Energy scaling reuses OpenNutriTracker's intake.
class FoodLog {
  FoodLog({
    required this.id,
    required this.food,
    required double grams,
    required this.slot,
    required this.date,
    required this.estimated,
  }) : grams = validNumber(grams, min: 0.1, max: 10000);

  final String id;
  final LocalFood food;
  final double grams;
  final MealSlot slot;
  final DateTime date;
  final bool estimated;

  IntakeEntity get intake => IntakeEntity(
    id: id,
    unit: 'g',
    amount: grams,
    type: slot.upstreamType,
    meal: food.toMealEntity(),
    dateTime: date,
  );

  double get calories => intake.totalKcal;

  Map<String, dynamic> toJson() => {
    'id': id,
    'food': food.toJson(),
    'grams': grams,
    'slot': slot.name,
    'date': date.toIso8601String(),
    'estimated': estimated,
  };

  factory FoodLog.fromJson(Map<String, dynamic> json) => FoodLog(
    id: json['id'] as String,
    food: LocalFood.fromJson(Map<String, dynamic>.from(json['food'] as Map)),
    grams: validNumber(json['grams'], min: 0.1, max: 10000),
    slot: MealSlot.values.byName(json['slot'] as String),
    date: DateTime.parse(json['date'] as String),
    estimated: json['estimated'] as bool,
  );
}

class BodyProfile {
  BodyProfile({
    required this.male,
    required int age,
    required double height,
    required double weight,
  }) : age = validNumber(age, min: 19, max: 78).toInt(),
       height = validNumber(height, min: 100, max: 250),
       weight = validNumber(weight, min: 25, max: 350);

  final bool male;
  final int age;
  final double height;
  final double weight;

  double get restingCalories =>
      10 * weight + 6.25 * height - 5 * age + (male ? 5 : -161);

  Map<String, dynamic> toJson() => {
    'male': male,
    'age': age,
    'height': height,
    'weight': weight,
  };

  factory BodyProfile.fromJson(Map<String, dynamic> json) => BodyProfile(
    male: json['male'] as bool,
    age: (json['age'] as num).toInt(),
    height: validNumber(json['height']),
    weight: validNumber(json['weight']),
  );
}

class OfflineState {
  OfflineState({
    List<FoodLog> logs = const [],
    Map<String, LocalFood> customFoods = const {},
    Map<String, double> overrides = const {},
    Set<String> favorites = const {},
    Set<String> completeDays = const {},
    Map<String, double> exercise = const {},
    this.profile,
  }) : logs = List.unmodifiable(logs),
       customFoods = Map.unmodifiable(customFoods),
       overrides = Map.unmodifiable(overrides),
       favorites = Set.unmodifiable(favorites),
       completeDays = Set.unmodifiable(completeDays),
       exercise = Map.unmodifiable(exercise);

  final List<FoodLog> logs;
  final Map<String, LocalFood> customFoods;
  final Map<String, double> overrides;
  final Set<String> favorites;
  final Set<String> completeDays;
  final Map<String, double> exercise;
  final BodyProfile? profile;

  OfflineState copyWith({
    List<FoodLog>? logs,
    Map<String, LocalFood>? customFoods,
    Map<String, double>? overrides,
    Set<String>? favorites,
    Set<String>? completeDays,
    Map<String, double>? exercise,
    BodyProfile? profile,
  }) => OfflineState(
    logs: logs ?? this.logs,
    customFoods: customFoods ?? this.customFoods,
    overrides: overrides ?? this.overrides,
    favorites: favorites ?? this.favorites,
    completeDays: completeDays ?? this.completeDays,
    exercise: exercise ?? this.exercise,
    profile: profile ?? this.profile,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'logs': logs.map((log) => log.toJson()).toList(),
    'customFoods': customFoods.values.map((food) => food.toJson()).toList(),
    'overrides': overrides,
    'favorites': favorites.toList(),
    'completeDays': completeDays.toList(),
    'exercise': exercise,
    'profile': profile?.toJson(),
  };

  factory OfflineState.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('不支持的数据版本，请勿覆盖现有数据');
    }
    final foods = (json['customFoods'] as List).map(
      (value) => LocalFood.fromJson(Map<String, dynamic>.from(value as Map)),
    );
    final logs = (json['logs'] as List)
        .map(
          (value) => FoodLog.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList();
    if (logs.map((log) => log.id).toSet().length != logs.length) {
      throw const FormatException('存在重复的记录编号');
    }
    return OfflineState(
      logs: logs,
      customFoods: {for (final food in foods) food.id: food},
      overrides: (json['overrides'] as Map).map(
        (key, value) => MapEntry(key as String, validNumber(value, max: 1000)),
      ),
      favorites: Set<String>.from(json['favorites'] as List),
      completeDays: Set<String>.from(json['completeDays'] as List),
      exercise: (json['exercise'] as Map).map(
        (key, value) => MapEntry(key as String, validNumber(value, max: 20000)),
      ),
      profile: json['profile'] == null
          ? null
          : BodyProfile.fromJson(
              Map<String, dynamic>.from(json['profile'] as Map),
            ),
    );
  }
}

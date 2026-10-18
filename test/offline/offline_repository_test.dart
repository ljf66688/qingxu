import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/offline/data/offline_repository.dart';
import 'package:opennutritracker/offline/domain/offline_models.dart';
import 'package:opennutritracker/offline/domain/statistics.dart';

class MemoryStore implements OfflineStore {
  String? saved;
  bool failNext = false;

  @override
  Future<String?> read() async => saved;

  @override
  Future<void> write(String json) async {
    if (failNext) {
      failNext = false;
      throw const FileSystemException('simulated disk full');
    }
    saved = json;
  }
}

const exampleFood = LocalFood(
  id: 'test-rice',
  name: '白切鸡饭',
  kcal100: 150,
  category: '饭类',
  note: '含米饭，熟制可食部分',
  source: '测试用食物',
  aliases: ['鸡饭'],
);

void main() {
  late MemoryStore store;
  late OfflineRepository repository;
  final date = DateTime(2024, 1, 1);

  setUp(() async {
    store = MemoryStore();
    repository = OfflineRepository(store: store, seedFoods: [exampleFood]);
    await repository.load();
  });

  test(
    'gram scaling uses upstream intake and retains energy snapshots',
    () async {
      await repository.addFood(
        food: exampleFood,
        grams: 200,
        slot: MealSlot.breakfast,
        date: date,
        estimated: false,
      );
      expect(repository.state.logs.single.calories, 300);
      expect(repository.state.logs.single.intake.totalKcal, 300);
      await repository.setFoodEnergy(exampleFood.id, 200);
      expect(repository.foodById(exampleFood.id)!.kcal100, 200);
      expect(repository.state.logs.single.food.kcal100, 150);
      expect(repository.state.logs.single.calories, 300);
      await repository.addFood(
        food: repository.foodById(exampleFood.id)!,
        grams: 200,
        slot: MealSlot.lunch,
        date: date,
        estimated: true,
      );
      expect(repository.state.logs.last.calories, 400);
      await repository.setFoodEnergy(exampleFood.id, null);
      expect(repository.foodById(exampleFood.id)!.kcal100, 150);
      expect(repository.state.logs.last.calories, 400);
    },
  );

  test('edit and delete affect only the intended log', () async {
    for (final slot in [MealSlot.breakfast, MealSlot.lunch]) {
      await repository.addFood(
        food: exampleFood,
        grams: 100,
        slot: slot,
        date: date,
        estimated: false,
      );
    }
    final first = repository.state.logs.first;
    await repository.editLog(first, 250, true);
    expect(repository.state.logs.first.calories, 375);
    expect(repository.state.logs.first.estimated, isTrue);
    expect(repository.state.logs.last.calories, 150);
    await repository.deleteLog(first.id);
    expect(repository.state.logs.single.slot, MealSlot.lunch);
  });

  test(
    'full state survives reopen including custom zero-energy food',
    () async {
      final food = await repository.createFood('我的茶', 0, '不加糖，按克称重');
      await repository.toggleFavorite(food.id);
      await repository.addFood(
        food: food,
        grams: 250,
        slot: MealSlot.dinner,
        date: date,
        estimated: true,
      );
      await repository.setComplete(date, true);
      await repository.setExercise(date, 350.5);
      await repository.saveProfile(
        BodyProfile(male: false, age: 30, height: 165, weight: 60),
      );
      final reopened = OfflineRepository(
        store: store,
        seedFoods: [exampleFood],
      );
      await reopened.load();
      expect(reopened.foodById(food.id)!.name, '我的茶');
      expect(reopened.state.favorites, contains(food.id));
      expect(reopened.state.logs.single.estimated, isTrue);
      expect(reopened.state.logs.single.calories, 0);
      expect(reopened.state.exercise[dayKey(date)], 350.5);
      expect(reopened.state.completeDays, contains(dayKey(date)));
      expect(reopened.state.profile!.restingCalories, 1320.25);
      expect(reopened.lastGrams(food.id), 250);
    },
  );

  test(
    'disk failure publishes no phantom data and the queue recovers',
    () async {
      store.failNext = true;
      await expectLater(
        repository.setExercise(date, 500),
        throwsA(isA<FileSystemException>()),
      );
      expect(repository.state.exercise, isEmpty);
      await repository.setExercise(date, 200);
      expect(repository.state.exercise[dayKey(date)], 200);
      await Future.wait([
        repository.toggleFavorite(exampleFood.id),
        repository.setComplete(date, true),
        repository.setExercise(date, 300),
      ]);
      expect(repository.state.favorites, contains(exampleFood.id));
      expect(repository.state.completeDays, contains(dayKey(date)));
      expect(repository.state.exercise[dayKey(date)], 300);
    },
  );

  test(
    'invalid inputs and corrupt/future schemas do not reset stored data',
    () async {
      for (final value in [double.nan, double.infinity, -1.0, 10001.0, 0.0]) {
        await expectLater(
          repository.addFood(
            food: exampleFood,
            grams: value,
            slot: MealSlot.lunch,
            date: date,
            estimated: false,
          ),
          throwsFormatException,
        );
      }
      expect(repository.state.logs, isEmpty);
      store.saved = '{"schemaVersion":999}';
      await expectLater(repository.load(), throwsFormatException);
      expect(store.saved, '{"schemaVersion":999}');
      store.saved = 'broken-json';
      await expectLater(repository.load(), throwsFormatException);
      expect(store.saved, 'broken-json');
    },
  );

  test('search handles common traditional characters and aliases', () {
    expect(repository.search('白切雞 飯').single.id, exampleFood.id);
    expect(repository.search('鸡饭').single.id, exampleFood.id);
    expect(repository.search('不存在'), isEmpty);
  });

  test('adult resting-energy formulas keep sex coefficients separate', () {
    expect(
      BodyProfile(male: true, age: 30, height: 175, weight: 70).restingCalories,
      1648.75,
    );
    expect(
      BodyProfile(
        male: false,
        age: 30,
        height: 175,
        weight: 70,
      ).restingCalories,
      1482.75,
    );
    expect(
      () => BodyProfile(male: true, age: 18, height: 175, weight: 70),
      throwsFormatException,
    );
  });

  test(
    'complete-day average excludes both numerator and denominator of partial days',
    () {
      final food = exampleFood.withEnergy(100);
      final logs = [
        for (final (day, kcal) in [(1, 2000), (2, 1900), (3, 2100), (4, 500)])
          FoodLog(
            id: '$day',
            food: food,
            grams: kcal.toDouble(),
            slot: MealSlot.lunch,
            date: DateTime(2024, 1, day),
            estimated: day == 2,
          ),
      ];
      final state = OfflineState(
        logs: logs,
        completeDays: {'2024-01-01', '2024-01-02', '2024-01-03'},
        exercise: {'2024-01-01': 300, '2024-01-05': 200},
      );
      final week = summarize(
        state,
        date,
        StatsPeriod.week,
        now: DateTime(2024, 1, 7),
      );
      expect(week.totalIntake, 6500);
      expect(week.averageIntake, 2000);
      expect(week.completeCount, 3);
      expect(week.recordedCount, 4);
      expect(week.totalExercise, 500);
      expect(week.days[1].estimatedCount, 1);
      expect(week.days[4].recorded, isFalse);
    },
  );

  test(
    'week/year boundaries, leap months, and future exclusion use calendar dates',
    () {
      final state = OfflineState();
      final crossYear = summarize(
        state,
        DateTime(2023, 1, 1),
        StatsPeriod.week,
        now: DateTime(2026, 10, 16),
      );
      expect(crossYear.start, DateTime(2022, 12, 26));
      expect(crossYear.end, DateTime(2023, 1, 2));
      final leap = summarize(
        state,
        DateTime(2024, 2, 29),
        StatsPeriod.month,
        now: DateTime(2024, 3, 1),
      );
      expect(leap.days.length, 29);
      final partial = summarize(
        state,
        DateTime(2024, 2, 15),
        StatsPeriod.month,
        now: DateTime(2024, 2, 15),
      );
      expect(partial.days.length, 15);
      expect(partial.averageIntake, isNull);
      expect(
        summarize(
          state,
          date,
          StatsPeriod.day,
          now: DateTime(2023, 12, 31),
        ).days,
        isEmpty,
      );
    },
  );

  test('bundled catalogue is offline, numeric, unique, and traceable', () {
    final catalog =
        jsonDecode(File('assets/offline/foods.json').readAsStringSync()) as Map;
    final foods = (catalog['foods'] as List)
        .map(
          (entry) =>
              LocalFood.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
    expect(foods.length, 92);
    expect(foods.map((food) => food.id).toSet().length, foods.length);
    expect(
      foods.every((food) => food.source.isNotEmpty && food.note.isNotEmpty),
      isTrue,
    );
    expect(foods.singleWhere((food) => food.id == 'usda-168878').kcal100, 130);
    final rice = foods.singleWhere((food) => food.id == 'recipe-028');
    expect(rice.kcal100, closeTo(32.5, 0.0001));
    expect(rice.source, contains('600'));
  });
}

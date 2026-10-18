import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/utils/secure_app_storage_provider.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';

import '../domain/offline_models.dart';
import '../domain/statistics.dart';

abstract interface class OfflineStore {
  Future<String?> read();
  Future<void> write(String json);
}

class EncryptedOfflineStore implements OfflineStore {
  EncryptedOfflineStore(this.box);
  final Box<String> box;

  static Future<EncryptedOfflineStore> open() async {
    // Reuse upstream's Keystore-backed AES key and missing-key protection.
    final key = await SecureAppStorageProvider().getHiveEncryptionKey();
    await Hive.initFlutter();
    final box = await Hive.openBox<String>(
      'CantoneseOfflineV1',
      encryptionCipher: HiveAesCipher(key),
      crashRecovery: false,
    );
    return EncryptedOfflineStore(box);
  }

  @override
  Future<String?> read() async => box.get('state');

  @override
  Future<void> write(String json) => box.put('state', json);
}

class OfflineRepository extends ChangeNotifier {
  OfflineRepository({required this.store, required List<LocalFood> seedFoods})
    : _seedFoods = Map.unmodifiable({
        for (final food in seedFoods) food.id: food,
      });

  final OfflineStore store;
  final Map<String, LocalFood> _seedFoods;
  OfflineState _state = OfflineState();
  OfflineState get state => _state;
  Future<void> _pending = Future.value();

  static Future<OfflineRepository> open() async {
    final raw = await rootBundle.loadString('assets/offline/foods.json');
    final catalog = jsonDecode(raw) as Map<String, dynamic>;
    final foods = (catalog['foods'] as List)
        .map(
          (value) =>
              LocalFood.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList();
    final repository = OfflineRepository(
      store: await EncryptedOfflineStore.open(),
      seedFoods: foods,
    );
    await repository.load();
    return repository;
  }

  Future<void> load() async {
    final raw = await store.read();
    // A corrupt/unknown schema is surfaced to the recovery screen, never reset.
    _state = raw == null
        ? OfflineState()
        : OfflineState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    notifyListeners();
  }

  List<LocalFood> get foods =>
      [..._seedFoods.values, ...state.customFoods.values].map((food) {
        final override = state.overrides[food.id];
        return override == null ? food : food.withEnergy(override);
      }).toList();

  LocalFood? foodById(String id) {
    for (final food in foods) {
      if (food.id == id) return food;
    }
    return null;
  }

  List<FoodLog> logsFor(DateTime date, {MealSlot? slot}) => state.logs
      .where(
        (log) =>
            dayKey(log.date) == dayKey(date) &&
            (slot == null || log.slot == slot),
      )
      .toList();

  List<LocalFood> search(String query) => searchFoods(foods, query);

  List<LocalFood> get recentFoods {
    final logs = [...state.logs]..sort((a, b) => b.date.compareTo(a.date));
    final seen = <String>{};
    return [
      for (final log in logs)
        if (seen.add(log.food.id) && foodById(log.food.id) != null)
          foodById(log.food.id)!,
    ].take(30).toList();
  }

  double lastGrams(String foodId) {
    final logs = state.logs.where((log) => log.food.id == foodId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return logs.isEmpty ? 100 : logs.first.grams;
  }

  Future<void> _mutate(OfflineState Function(OfflineState) change) {
    final task = _pending.then((_) async {
      final candidate = change(_state);
      final encoded = jsonEncode(candidate.toJson());
      await store.write(encoded);
      // Publish only after the atomic single-record Hive write succeeds.
      _state = candidate;
      notifyListeners();
    });
    _pending = task.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return task;
  }

  Future<void> addFood({
    required LocalFood food,
    required double grams,
    required MealSlot slot,
    required DateTime date,
    required bool estimated,
  }) => _mutate((state) {
    final now = DateTime.now();
    if (calendarDay(date).isAfter(calendarDay(now))) {
      throw const FormatException('不能记录未来日期');
    }
    final log = FoodLog(
      id: IdGenerator.getUniqueID(),
      food: food,
      grams: grams,
      slot: slot,
      date: DateTime(
        date.year,
        date.month,
        date.day,
        now.hour,
        now.minute,
        now.second,
        now.millisecond,
        now.microsecond,
      ),
      estimated: estimated,
    );
    return state.copyWith(logs: [...state.logs, log]);
  });

  Future<void> editLog(FoodLog original, double grams, bool estimated) =>
      _mutate(
        (state) => state.copyWith(
          logs: [
            for (final log in state.logs)
              if (log.id == original.id)
                FoodLog(
                  id: log.id,
                  food: log.food,
                  grams: grams,
                  slot: log.slot,
                  date: log.date,
                  estimated: estimated,
                )
              else
                log,
          ],
        ),
      );

  Future<void> deleteLog(String id) => _mutate(
    (state) =>
        state.copyWith(logs: state.logs.where((log) => log.id != id).toList()),
  );

  Future<void> toggleFavorite(String id) => _mutate((state) {
    if (foodById(id) == null) throw const FormatException('食物不存在');
    final values = {...state.favorites};
    if (!values.remove(id)) values.add(id);
    return state.copyWith(favorites: values);
  });

  Future<void> setFoodEnergy(String id, double? kcal100) => _mutate((state) {
    if (foodById(id) == null) throw const FormatException('食物不存在');
    final values = {...state.overrides};
    if (kcal100 == null) {
      values.remove(id);
    } else {
      values[id] = validNumber(kcal100, max: 1000);
    }
    return state.copyWith(overrides: values);
  });

  Future<LocalFood> createFood(String name, double kcal100, String note) async {
    if (name.trim().isEmpty || name.trim().length > 80) {
      throw const FormatException('名称需为1—80个字符');
    }
    final food = LocalFood(
      id: 'custom-${IdGenerator.getUniqueID()}',
      name: name.trim(),
      kcal100: validNumber(kcal100, max: 1000),
      category: '我的食物',
      note: note.trim().isEmpty ? '用户自行填写，每100克可食部分' : note.trim(),
      source: '用户自建',
      custom: true,
    );
    await _mutate(
      (state) =>
          state.copyWith(customFoods: {...state.customFoods, food.id: food}),
    );
    return food;
  }

  Future<void> setComplete(DateTime date, bool complete) => _mutate((state) {
    if (calendarDay(date).isAfter(calendarDay(DateTime.now()))) {
      throw const FormatException('未来日期不能标记完整');
    }
    final values = {...state.completeDays};
    if (complete) {
      values.add(dayKey(date));
    } else {
      values.remove(dayKey(date));
    }
    return state.copyWith(completeDays: values);
  });

  Future<void> setExercise(DateTime date, double? calories) => _mutate((state) {
    if (calendarDay(date).isAfter(calendarDay(DateTime.now()))) {
      throw const FormatException('不能记录未来日期');
    }
    final values = {...state.exercise};
    if (calories == null) {
      values.remove(dayKey(date));
    } else {
      values[dayKey(date)] = validNumber(calories, max: 20000);
    }
    return state.copyWith(exercise: values);
  });

  Future<void> saveProfile(BodyProfile profile) =>
      _mutate((state) => state.copyWith(profile: profile));
}

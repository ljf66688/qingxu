import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/offline/data/offline_repository.dart';
import 'package:opennutritracker/offline/domain/offline_models.dart';
import 'package:opennutritracker/offline/presentation/offline_app.dart';

import 'offline_repository_test.dart' show MemoryStore, exampleFood;

void main() {
  testWidgets(
    'search, favorite, grams, complete day, exercise and statistics work together',
    (tester) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = OfflineRepository(
        store: MemoryStore(),
        seedFoods: [exampleFood],
      );
      await repository.load();
      await tester.pumpWidget(CantoneseOfflineApp(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsIdentifier('diary-previous-day'));
      await tester.pumpAndSettle();
      final selected = DateTime.now().subtract(const Duration(days: 1));
      await tester.tap(find.bySemanticsIdentifier('diary-add-breakfast'));
      await tester.pumpAndSettle();
      expect(find.text('${dayKey(selected)} · 早餐'), findsOneWidget);
      await tester.enterText(find.bySemanticsIdentifier('food-search'), '雞飯');
      await tester.pumpAndSettle();
      expect(find.text('白切鸡饭'), findsOneWidget);
      await tester.tap(find.byTooltip('收藏'));
      await tester.pumpAndSettle();
      expect(repository.state.favorites, contains(exampleFood.id));
      await tester.tap(find.text('白切鸡饭'));
      await tester.pumpAndSettle();
      await tester.enterText(find.bySemanticsIdentifier('food-grams'), '200');
      await tester.pumpAndSettle();
      expect(find.text('300 千卡'), findsOneWidget);
      await tester.tap(find.bySemanticsIdentifier('food-save'));
      await tester.pumpAndSettle();
      expect(repository.state.logs.single.calories, 300);
      expect(dayKey(repository.state.logs.single.date), dayKey(selected));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsIdentifier('diary-exercise'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.bySemanticsIdentifier('exercise-calories'),
        '250',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(repository.state.exercise[dayKey(selected)], 250);
      await tester.scrollUntilVisible(
        find.bySemanticsIdentifier('diary-complete-day'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.bySemanticsIdentifier('diary-complete-day'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '已记录完整'));
      await tester.pumpAndSettle();
      expect(repository.state.completeDays, contains(dayKey(selected)));
      await tester.tap(find.text('统计'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('每日'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsIdentifier('statistics-previous'));
      await tester.pumpAndSettle();
      expect(find.text('300 千卡'), findsOneWidget);
      expect(find.text('250 千卡'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile and empty monthly statistics work at small width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = OfflineRepository(
      store: MemoryStore(),
      seedFoods: [exampleFood],
    );
    await repository.load();
    await tester.pumpWidget(CantoneseOfflineApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('女性'));
    await tester.enterText(find.bySemanticsIdentifier('profile-age'), '30');
    await tester.enterText(find.bySemanticsIdentifier('profile-height'), '165');
    await tester.enterText(find.bySemanticsIdentifier('profile-weight'), '60');
    await tester.ensureVisible(find.bySemanticsIdentifier('profile-save'));
    await tester.tap(find.bySemanticsIdentifier('profile-save'));
    await tester.pumpAndSettle();
    expect(repository.state.profile!.restingCalories, 1320.25);
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('每月'));
    await tester.pumpAndSettle();
    expect(find.text('暂无完整记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

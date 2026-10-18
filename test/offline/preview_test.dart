import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/offline/data/offline_repository.dart';
import 'package:opennutritracker/offline/domain/offline_models.dart';
import 'package:opennutritracker/offline/presentation/offline_app.dart';

import 'offline_repository_test.dart' show MemoryStore;

void main() {
  testWidgets(
    'render the actual offline screens with isolated sample data',
    (tester) async {
      tester.view.physicalSize = const Size(420, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Test bindings omit the normal application's license collectors.
      // Restore the app license and the same bundled notices as the APK.
      LicenseRegistry.addLicense(() async* {
        yield LicenseEntryWithLineBreaks([
          'OpenNutriTracker',
        ], File('LICENSE').readAsStringSync());
        final notices = File('build/unit_test_assets/NOTICES.Z');
        if (notices.existsSync()) {
          final raw = utf8.decode(gzip.decode(notices.readAsBytesSync()));
          for (final entry in raw.split('\n${'-' * 80}\n')) {
            final split = entry.indexOf('\n\n');
            yield LicenseEntryWithLineBreaks(
              split < 0 ? [] : entry.substring(0, split).split('\n'),
              split < 0 ? entry : entry.substring(split + 2),
            );
          }
        }
      });
      final font = File(r'C:\Windows\Fonts\msyh.ttc');
      if (font.existsSync()) {
        final bytes = font.readAsBytesSync();
        await (FontLoader('Roboto')..addFont(
              Future.value(
                ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length),
              ),
            ))
            .load();
      }
      final icons = File(
        'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
      );
      if (icons.existsSync()) {
        final bytes = icons.readAsBytesSync();
        await (FontLoader('MaterialIcons')..addFont(
              Future.value(
                ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length),
              ),
            ))
            .load();
      }
      final data =
          jsonDecode(File('assets/offline/foods.json').readAsStringSync())
              as Map;
      final foods = (data['foods'] as List)
          .map(
            (value) =>
                LocalFood.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList();
      final repository = OfflineRepository(
        store: MemoryStore(),
        seedFoods: foods,
      );
      await repository.load();
      await repository.saveProfile(
        BodyProfile(male: true, age: 30, height: 175, weight: 70),
      );
      final today = calendarDay(DateTime.now());
      for (var offset = 6; offset >= 0; offset--) {
        final date = DateTime(today.year, today.month, today.day - offset);
        await repository.addFood(
          food: repository.foodById('recipe-028')!,
          grams: 300,
          slot: MealSlot.breakfast,
          date: date,
          estimated: false,
        );
        await repository.addFood(
          food: repository.foodById('usda-173424')!,
          grams: 50,
          slot: MealSlot.breakfast,
          date: date,
          estimated: false,
        );
        await repository.addFood(
          food: repository.foodById('recipe-001')!,
          grams: 130 + offset * 7,
          slot: MealSlot.lunch,
          date: date,
          estimated: offset == 1,
        );
        await repository.addFood(
          food: repository.foodById('usda-168878')!,
          grams: 200,
          slot: MealSlot.lunch,
          date: date,
          estimated: false,
        );
        if (offset > 0) {
          await repository.addFood(
            food: repository.foodById('recipe-038')!,
            grams: 350 + offset * 15,
            slot: MealSlot.dinner,
            date: date,
            estimated: false,
          );
          await repository.setComplete(date, true);
        }
        await repository.setExercise(date, 200 + offset * 40);
      }
      for (final id in [
        'recipe-001',
        'recipe-028',
        'usda-173424',
        'recipe-038',
      ]) {
        await repository.toggleFavorite(id);
      }
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: CantoneseOfflineApp(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      final output = Directory(
        const String.fromEnvironment(
          'OFFLINE_PREVIEW_DIR',
          defaultValue: 'build/offline-preview',
        ),
      );
      output.createSync(recursive: true);
      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '${output.path}/$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      }

      await capture('today');
      await tester.tap(find.text('统计'));
      await capture('statistics');
      await tester.tap(find.text('每日'));
      await capture('statistics-day');
      await tester.tap(find.text('每月'));
      await capture('statistics-month');
      await tester.tap(find.text('收藏'));
      await capture('favorites');
      await tester.tap(find.text('我的'));
      await capture('profile');

      Future<void> tapId(String id) async {
        final target = find.bySemanticsIdentifier(id);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      Future<void> closeRoute() async {
        FocusManager.instance.primaryFocus?.unfocus();
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
      }

      await tester.scrollUntilVisible(
        find.bySemanticsIdentifier('profile-sources'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await capture('profile-formula');
      await tapId('profile-sources');
      await capture('about');
      await tapId('profile-license');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await capture('licenses');
      await tester.scrollUntilVisible(
        find.text('OpenNutriTracker'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('OpenNutriTracker'));
      await capture('license-detail');
      await tester.tap(find.byTooltip('返回').last);
      await tester.pumpAndSettle();
      await closeRoute();
      await closeRoute();

      await tester.tap(find.text('今日'));
      await tester.pumpAndSettle();
      await tapId('diary-date');
      await capture('date-picker');
      await closeRoute();
      await tapId('diary-exercise');
      await tester.enterText(
        find.bySemanticsIdentifier('exercise-calories'),
        '350',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await capture('exercise');
      await closeRoute();

      await tester.scrollUntilVisible(
        find.bySemanticsIdentifier('diary-complete-day'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await capture('today-details');
      await tapId('diary-complete-day');
      await capture('complete-day');
      await closeRoute();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 1600));
      await tester.pumpAndSettle();

      final recordedFood = find.descendant(
        of: find.bySemanticsIdentifier('diary-breakfast-items'),
        matching: find.text(repository.foodById('recipe-028')!.name),
      );
      await tester.ensureVisible(recordedFood);
      await tester.tap(recordedFood);
      await capture('edit-food');
      await tapId('food-delete');
      await capture('delete-food');
      await closeRoute();
      await closeRoute();

      await tapId('diary-add-lunch');
      await capture('food-browse');
      await tester.enterText(find.bySemanticsIdentifier('food-search'), '白切鸡');
      FocusManager.instance.primaryFocus?.unfocus();
      await capture('food-search');
      await tester.tap(find.text(repository.foodById('recipe-001')!.name));
      await tester.pumpAndSettle();
      await tester.enterText(find.bySemanticsIdentifier('food-grams'), '200');
      FocusManager.instance.primaryFocus?.unfocus();
      await capture('food-amount');
      await tapId('food-source-details');
      await capture('food-source');
      await tapId('food-source-details');
      await tapId('food-adjust-energy');
      await capture('food-energy');
      await closeRoute();
      await closeRoute();
      await tapId('food-create');
      await tester.enterText(
        find.bySemanticsIdentifier('custom-food-name'),
        '自家蒸肉饼',
      );
      await tester.enterText(
        find.bySemanticsIdentifier('custom-food-energy'),
        '210',
      );
      await tester.enterText(
        find.bySemanticsIdentifier('custom-food-note'),
        '示例：按自家配方估算，熟制可食部分',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await capture('custom-food');
    },
    skip: !const bool.fromEnvironment('CAPTURE_OFFLINE_PREVIEW'),
  );
}

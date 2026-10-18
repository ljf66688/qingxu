import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/offline/data/offline_repository.dart';

import 'offline_repository_test.dart' show exampleFood;

void main() {
  test(
    'encrypted Hive persistence reopens without cleartext diary data',
    () async {
      final directory = await Directory.systemTemp.createTemp('yueshiji-hive-');
      addTearDown(() async {
        await Hive.close();
        final resolved = await directory.resolveSymbolicLinks();
        final tempRoot = await Directory.systemTemp.resolveSymbolicLinks();
        if (!resolved.startsWith(
          '$tempRoot${Platform.pathSeparator}yueshiji-hive-',
        )) {
          throw StateError('Refusing to remove an unexpected test directory');
        }
        await directory.delete(recursive: true);
      });
      Hive.init(directory.path);
      final key = Uint8List.fromList(Hive.generateSecureKey());
      var box = await Hive.openBox<String>(
        'offline-test',
        encryptionCipher: HiveAesCipher(key),
        crashRecovery: false,
      );
      var repository = OfflineRepository(
        store: EncryptedOfflineStore(box),
        seedFoods: [exampleFood],
      );
      await repository.load();
      final custom = await repository.createFood('加密的私人食物', 125, '自建条目');
      await repository.toggleFavorite(custom.id);
      await box.flush();
      await box.close();
      final stored = File(
        '${directory.path}/offline-test.hive',
      ).readAsBytesSync();
      expect(String.fromCharCodes(stored), isNot(contains('schemaVersion')));
      box = await Hive.openBox<String>(
        'offline-test',
        encryptionCipher: HiveAesCipher(key),
        crashRecovery: false,
      );
      repository = OfflineRepository(
        store: EncryptedOfflineStore(box),
        seedFoods: [exampleFood],
      );
      await repository.load();
      expect(repository.foodById(custom.id)!.kcal100, 125);
      expect(repository.state.favorites, contains(custom.id));
    },
  );
}

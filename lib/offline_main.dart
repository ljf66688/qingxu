import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'offline/data/offline_repository.dart';
import 'offline/presentation/offline_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'OpenNutriTracker',
    ], await rootBundle.loadString('LICENSE'));
  });
  runApp(const OfflineBootstrap());
}

class OfflineBootstrap extends StatefulWidget {
  const OfflineBootstrap({super.key});

  @override
  State<OfflineBootstrap> createState() => _OfflineBootstrapState();
}

class _OfflineBootstrapState extends State<OfflineBootstrap> {
  late Future<OfflineRepository> _opening = OfflineRepository.open();

  @override
  Widget build(BuildContext context) => FutureBuilder<OfflineRepository>(
    future: _opening,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return CantoneseOfflineApp(repository: snapshot.data!);
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: offlineTheme(),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: snapshot.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline, size: 48),
                          const SizedBox(height: 20),
                          const Text(
                            '暂时无法打开本地数据',
                            style: TextStyle(fontSize: 22),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '原有数据已保留。请重试；若仍然失败，保留应用并联系开发者，避免卸载导致数据丢失。',
                          ),
                          const SizedBox(height: 20),
                          Semantics(
                            identifier: 'offline-startup-retry',
                            child: FilledButton(
                              onPressed: () => setState(() {
                                _opening = OfflineRepository.open();
                              }),
                              child: const Text('重新打开'),
                            ),
                          ),
                        ],
                      )
                    : const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 20),
                          Text('正在打开本地日记…'),
                        ],
                      ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

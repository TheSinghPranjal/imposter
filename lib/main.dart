import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'features/imposter/data/repositories/settings_repository.dart';
import 'features/imposter/presentation/providers/game_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nunito is bundled under the SIL Open Font License, which must ship with it.
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Nunito'], license);
  });
  final prefs = await SharedPreferences.getInstance();
  final settingsRepo = SettingsRepository(prefs);

  final container = ProviderContainer(
    overrides: [settingsRepositoryProvider.overrideWithValue(settingsRepo)],
  );

  await container.read(gameControllerProvider.notifier).bootstrap();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FindTheImposterApp(),
    ),
  );
}

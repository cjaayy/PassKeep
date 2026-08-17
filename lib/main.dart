import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/database/database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local Hive database and register TypeAdapters
  await DatabaseService().initialize();

  runApp(
    const ProviderScope(
      child: PassKeepApp(),
    ),
  );
}

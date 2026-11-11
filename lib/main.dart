import 'package:flutter/material.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/presentation/my_app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  await ServiceLocator.configure(container);

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

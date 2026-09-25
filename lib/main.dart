import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) => FlutterError.presentError(details);
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[GlobalError] $error\n$stack');
    return true;
  };
  runApp(
    const ProviderScope(
      child: CountrApp(),
    ),
  );
}

/// Countr Application Root.
/// High-performance, offline-first collection management & social shell.
class CountrApp extends StatelessWidget {
  const CountrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Countr',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}

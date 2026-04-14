// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/core/notification_service.dart';
import 'package:mediflow/core/router.dart';
import 'package:mediflow/core/connectivity_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize notification service (non-fatal if it fails)
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('NotificationService init failed: $e');
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://dtmkzvptamydlgubmzlb.supabase.co',
    anonKey: 'sb_publishable_30AYi1oyhTvuzqtcN-BsbQ_j4MnFKHv',
    debug: false,
  );

  runApp(
    const ProviderScope(
      child: MediFlowApp(),
    ),
  );
}

class MediFlowApp extends ConsumerWidget {
  const MediFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      routerConfig: router,
      title: 'MediFlow',
      theme: AppTheme.neumorphicTheme,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Prevent font scaling from breaking layout
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).textScaler.scale(1.0).clamp(0.8, 1.2),
            ),
          ),
          child: ConnectivityWrapper(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
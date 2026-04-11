// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/core/notification_service.dart';
import 'package:mediflow/core/router.dart';
import 'package:mediflow/core/connectivity_wrapper.dart';

Future<void> main() async {
  // THIS LINE MUST BE FIRST
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService.instance.initialize();

  // SUPABASE MUST INIT BEFORE runApp
  await Supabase.initialize(
    url: 'https://dtmkzvptamydlgubmzlb.supabase.co',
    anonKey: 'sb_publishable_30AYi1oyhTvuzqtcN-BsbQ_j4MnFKHv',
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
        return ConnectivityWrapper(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

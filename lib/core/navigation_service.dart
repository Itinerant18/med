import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

void openPatientDetailFromNotification(String patientId) {
  final context = appNavigatorKey.currentContext;
  if (context == null || patientId.trim().isEmpty) return;
  GoRouter.of(context).push('/patients/$patientId/detail');
}

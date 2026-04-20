from pathlib import Path 
p = Path(r'lib/core/auth_gate.dart') 
text = p.read_text(encoding='utf-8') 
text = text.replace(\"import '../features/approval/rejected_screen.dart';\nimport 'realtime_service.dart';\", \"import '../features/approval/rejected_screen.dart';\nimport '../features/approval/approval_provider.dart';\nimport 'realtime_service.dart';\") 
text = text.replace(\"RealtimeService.instance.subscribeToPatientChanges(doctorName, ref);\", \"RealtimeService.instance.subscribeToPatientChanges(doctorName, ref);\n              if (userState.isHeadDoctor) {\n                ref.read(pendingApprovalsProvider.notifier).listenForNewRegistrations();\n              }\") 
p.write_text(text, encoding='utf-8') 

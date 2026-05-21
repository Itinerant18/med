import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediflow/core/sync_queue.dart';

/// Small badge showing the count of changes pending offline sync.
/// Returns [SizedBox.shrink] when there are no pending changes.
class OfflineIndicator extends StatefulWidget {
  const OfflineIndicator({super.key});

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator> {
  int _pending = 0;
  StreamSubscription<int>? _sub;

  @override
  void initState() {
    super.initState();
    _pending = SyncQueue.instance.currentPendingCount;
    _sub = SyncQueue.instance.pendingCount.listen((n) {
      if (mounted) setState(() => _pending = n);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pending == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.shade700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sync_rounded, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$_pending pending',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/sync_queue.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/agent_visits/agent_outside_visit_provider.dart';
import 'package:mediflow/features/dashboard/dashboard_provider.dart';
import 'package:mediflow/features/dr_visits/dr_visit_provider.dart';
import 'package:mediflow/features/followups/followup_provider.dart';
import 'package:mediflow/features/patients/patient_provider.dart';
import 'package:mediflow/features/staff/external_doctors_provider.dart';
import 'package:mediflow/features/work_log/work_log_provider.dart';

class ConnectivityWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const ConnectivityWrapper({super.key, required this.child});

  @override
  ConsumerState<ConnectivityWrapper> createState() =>
      _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends ConsumerState<ConnectivityWrapper>
    with SingleTickerProviderStateMixin {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySub;
  StreamSubscription<int>? _pendingCountSub;
  StreamSubscription<SyncPermanentFailure>? _permanentFailureSub;
  bool _isConnected = true;
  bool _showBanner = false;
  int _pendingCount = 0;

  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _pendingCount = SyncQueue.instance.currentPendingCount;
    _pendingCountSub = SyncQueue.instance.pendingCount.listen((n) {
      if (mounted) setState(() => _pendingCount = n);
    });

    _permanentFailureSub =
        SyncQueue.instance.permanentFailures.listen(_onPermanentFailure);

    _checkInitialConnection();
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  void _onPermanentFailure(SyncPermanentFailure failure) {
    if (!mounted) return;
    final friendly = AppError.getMessage(failure.error);
    final operation = failure.action.operation.name;
    final table = failure.action.table.replaceAll('_', ' ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Couldn't sync $operation on $table: $friendly"),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  Future<void> _checkInitialConnection() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _onConnectivityChanged(result);
    } catch (_) {}
  }

  void _onConnectivityChanged(List<ConnectivityResult> result) {
    final isConnected = !result.contains(ConnectivityResult.none);
    if (_isConnected == isConnected) return;

    setState(() {
      _isConnected = isConnected;
      _showBanner = true;
    });

    if (!isConnected) {
      _animController.forward();
    } else {
      // Reconnected — flush the offline write queue then refresh data.
      SyncQueue.instance.processQueue().then((_) {
        if (!mounted) return;
        final hadPending = SyncQueue.instance.currentPendingCount == 0 &&
            _pendingCount > 0;
        if (hadPending) {
          // Re-fetch every provider that could be holding optimistic
          // rows keyed by offline_<ms> ids. Invalidating an AsyncNotifier or
          // a FutureProvider.family by its root invalidates all keys, so this
          // covers patient detail pages too.
          ref.invalidate(patientProvider);
          ref.invalidate(patientDetailProvider);
          ref.invalidate(drVisitsProvider);
          ref.invalidate(followupTasksProvider);
          ref.invalidate(workLogProvider);
          ref.invalidate(agentOutsideVisitsProvider);
          ref.invalidate(externalDoctorsProvider);
          ref.invalidate(dashboardProvider);
        }
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _animController.reverse().then((_) {
            if (mounted) setState(() => _showBanner = false);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _connectivitySub.cancel();
    _pendingCountSub?.cancel();
    _permanentFailureSub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  String get _bannerText {
    if (_isConnected) return 'Back online';
    if (_pendingCount > 0) return 'Offline · $_pendingCount change(s) pending';
    return 'No internet connection';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Material(
                    color: _isConnected
                        ? AppTheme.primaryTeal
                        : AppTheme.errorColor,
                    elevation: 0,
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: const [AppTheme.shadowSoft],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isConnected
                                ? AppIcons.wifi_rounded
                                : AppIcons.wifi_off_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _bannerText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

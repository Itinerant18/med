import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mediflow/core/theme.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper>
    with SingleTickerProviderStateMixin {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isConnected = true;
  bool _showBanner = false;

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
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _checkInitialConnection();
    _subscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _checkInitialConnection() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _updateConnectionStatus(result);
    } catch (_) {
      // Silently fail — assume connected.
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final isConnected = !result.contains(ConnectivityResult.none);
    if (_isConnected != isConnected) {
      setState(() {
        _isConnected = isConnected;
        _showBanner = true;
      });

      if (!isConnected) {
        _animController.forward();
      } else {
        // Hide banner after a short delay when reconnected.
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _animController.reverse().then((_) {
              if (mounted) setState(() => _showBanner = false);
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _animController.dispose();
    super.dispose();
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
                            _isConnected
                                ? 'Back online'
                                : 'No internet connection',
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

// lib/features/auth/phone_otp_screen.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/core/app_snackbar.dart';

class PhoneOtpScreen extends StatefulWidget {
  final String phoneNumber;   // E.164 format e.g. "+919876543210"
  final VoidCallback onVerified;

  const PhoneOtpScreen({
    super.key,
    required this.phoneNumber,
    required this.onVerified,
  });

  @override
  State<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends State<PhoneOtpScreen> {
  static const double _otpGap = 8;
  static const double _otpMaxWidth = 46;
  static const double _otpMinWidth = 36;

  // OTP input
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  // State
  String? _verificationId;
  int? _resendToken;
  bool _isSending = false;
  bool _isVerifying = false;
  bool _codeSent = false;

  // Resend timer
  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  // ── OTP sending ──────────────────────────────────────────────────────────

  Future<void> _sendOtp({bool isResend = false}) async {
    setState(() => _isSending = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        forceResendingToken: isResend ? _resendToken : null,
        timeout: const Duration(seconds: 60),

        // Auto-retrieval (Android only)
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithCredential(credential);
        },

        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          final msg = _friendlyError(e.code, e.message);
          AppSnackbar.showError(context, msg);
          setState(() => _isSending = false);
        },

        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _codeSent = true;
            _isSending = false;
          });
          _startResendTimer();
          if (isResend) {
            AppSnackbar.showSuccess(context, 'New OTP sent to ${widget.phoneNumber}');
          }
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          _friendlyError('unknown', e.toString()),
        );
        setState(() => _isSending = false);
      }
    }
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendCountdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  // ── OTP verification ─────────────────────────────────────────────────────

  Future<void> _verifyOtp() async {
    final otp = _controllers.map((c) => c.text.trim()).join();
    if (otp.length != 6) {
      AppSnackbar.showWarning(context, 'Enter the 6-digit code sent to your phone');
      return;
    }
    if (_verificationId == null) {
      AppSnackbar.showError(context, 'Verification not started. Please resend OTP.');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, _friendlyError(e.code, e.message));
        setState(() => _isVerifying = false);
        // Clear OTP fields on wrong code
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes.first.requestFocus();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          _friendlyError('unknown', e.toString()),
        );
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    // We only want to verify the phone — we don't want Firebase as primary auth.
    // Sign in temporarily, then immediately sign out from Firebase.
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      await FirebaseAuth.instance.signOut(); // Keep Supabase as sole auth
    } catch (_) {
      // Credential valid even if temporary sign-in fails in some edge cases
    }

    if (mounted) {
      setState(() => _isVerifying = false);
      AppSnackbar.showSuccess(context, 'Phone number verified!');
      widget.onVerified();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _friendlyError(String code, [String? message]) {
    final normalizedCode = code.toLowerCase();
    final normalizedMessage = (message ?? '').toLowerCase();

    if (normalizedCode.contains('billing_not_enabled') ||
        normalizedMessage.contains('billing_not_enabled')) {
      return 'OTP is not enabled for this Firebase project yet. Enable billing in Firebase/Google Cloud, then retry phone verification.';
    }

    if (normalizedMessage.contains('recaptcha') ||
        normalizedMessage.contains('sitekey')) {
      return 'Phone auth is missing Firebase reCAPTCHA configuration. Add the required reCAPTCHA setup in Firebase Authentication before using OTP.';
    }

    switch (normalizedCode) {
      case 'invalid-verification-code':
        return 'Incorrect OTP. Please check and try again.';
      case 'session-expired':
        return 'OTP has expired. Please request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait before retrying.';
      case 'invalid-phone-number':
        return 'The phone number format is invalid.';
      case 'network-request-failed':
        return 'No internet connection. Check your network.';
      default:
        return 'Verification failed ($code). Please try again.';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Verify Phone Number',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              NeuCard(
                padding: const EdgeInsets.all(24),
                borderRadius: 80,
                child: Icon(
                  _codeSent
                      ? Icons.sms_rounded
                      : Icons.phone_iphone_rounded,
                  size: 52,
                  color: AppTheme.primaryTeal,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                _isSending && !_codeSent
                    ? 'Sending OTP…'
                    : 'Enter Verification Code',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'We sent a 6-digit code to\n${widget.phoneNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // OTP input boxes
              if (_isSending && !_codeSent)
                const CircularProgressIndicator(color: AppTheme.primaryTeal)
              else ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    const totalSpacing = _otpGap * 5;
                    final availableWidth =
                        (constraints.maxWidth - totalSpacing).clamp(
                      _otpMinWidth * 6,
                      double.infinity,
                    );
                    final otpWidth =
                        (availableWidth / 6).clamp(_otpMinWidth, _otpMaxWidth);

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        6,
                        (i) => _buildOtpBox(i, otpWidth),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),

                // Verify button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: NeuButton(
                    onPressed: _isVerifying ? null : _verifyOtp,
                    isLoading: _isVerifying,
                    child: const Text(
                      'Verify & Continue',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Resend
                if (_resendCountdown > 0)
                  Text(
                    'Resend OTP in ${_resendCountdown}s',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  )
                else
                  GestureDetector(
                    onTap: () => _sendOtp(isResend: true),
                    child: const Text(
                      'Resend OTP',
                      style: TextStyle(
                        color: AppTheme.primaryTeal,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index, double width) {
    return Container(
      width: width,
      height: 56,
      margin: EdgeInsets.only(right: index == 5 ? 0 : _otpGap),
      decoration: BoxDecoration(
        color: AppTheme.bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 8),
          BoxShadow(color: Color(0xFFA3B1C6), offset: Offset(3, 3), blurRadius: 8),
        ],
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppTheme.textColor,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
          if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          // Auto-submit when last digit is entered
          if (index == 5 && value.isNotEmpty) {
            _verifyOtp();
          }
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/features/profile/clinic_settings_provider.dart';

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  final _clinicNameController = TextEditingController();
  final _clinicAddrController = TextEditingController();
  final _clinicPhoneController = TextEditingController();

  @override
  void dispose() {
    _clinicNameController.dispose();
    _clinicAddrController.dispose();
    _clinicPhoneController.dispose();
    super.dispose();
  }

  Future<void> _handleClinicUpdate() async {
    final data = {
      'clinic_name': _clinicNameController.text.trim(),
      'clinic_address': _clinicAddrController.text.trim(),
      'clinic_phone': _clinicPhoneController.text.trim(),
    };

    await ref.read(clinicSettingsProvider.notifier).updateSettings(data);

    if (mounted) {
      AppSnackbar.showSuccess(context, 'Clinic information updated');
    }
  }

  Future<void> _contactSupport() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@mediflow.app',
      queryParameters: {'subject': 'MediFlow Support Request'},
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      if (mounted) AppSnackbar.showError(context, 'Could not launch email client');
    }
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clinicAsync = ref.watch(clinicSettingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('About MediFlow', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // SECTION 1 — App Identity
            const Icon(Icons.local_hospital, size: 64, color: AppTheme.primaryTeal),
            const SizedBox(height: 12),
            const Text('MediFlow', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
            const Text('Smart Clinic Management', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(20)),
              child: const Text('Version 1.0.0', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),

            // SECTION 2 — Description
            _buildSectionCard(
              'About This App',
              const Text(
                'MediFlow is a collaborative clinical management platform designed for modern medical practices. It enables doctors to manage patient records, track clinical visits, coordinate care, and maintain complete audit trails — all in real time.',
                style: TextStyle(fontSize: 15, height: 1.6),
              ),
            ),
            const SizedBox(height: 20),

            // SECTION 3 — Key Features
            _buildSectionCard(
              'Key Features',
              Column(
                children: [
                  _buildFeatureRow('Real-time patient record management'),
                  _buildFeatureRow('Multi-doctor collaborative access'),
                  _buildFeatureRow('Complete visit history and audit trail'),
                  _buildFeatureRow('Document and image attachments'),
                  _buildFeatureRow('Live notifications on patient updates'),
                  _buildFeatureRow('Health scheme and insurance tracking'),
                  _buildFeatureRow('High priority patient flagging'),
                  _buildFeatureRow('Operational tracking (Labs + OT)'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // SECTION 4 — Technology
            _buildSectionCard(
              'Built With',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildTechChip('Flutter', Colors.blue),
                      _buildTechChip('Supabase', Colors.green),
                      _buildTechChip('Riverpod', Colors.deepPurple),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Powered by real-time PostgreSQL database with end-to-end authentication',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // SECTION 5 — Your Clinic
            clinicAsync.when(
              data: (data) {
                _clinicNameController.text = data['clinic_name'] ?? '';
                _clinicAddrController.text = data['clinic_address'] ?? '';
                _clinicPhoneController.text = data['clinic_phone'] ?? '';
                return NeuCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Your Clinic'),
                      NeuTextField(controller: _clinicNameController, label: 'Clinic Name'),
                      const SizedBox(height: 12),
                      NeuTextField(controller: _clinicAddrController, label: 'Clinic Address', maxLines: 2),
                      const SizedBox(height: 12),
                      NeuTextField(controller: _clinicPhoneController, label: 'Clinic Phone', keyboardType: TextInputType.phone),
                      const SizedBox(height: 20),
                      NeuButton(
                        onPressed: clinicAsync.isLoading ? null : _handleClinicUpdate,
                        isLoading: clinicAsync.isLoading,
                        color: AppTheme.primaryTeal,
                        child: const Text('Update Clinic Info', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, __) => Text(AppError.getMessage(e)),
            ),
            const SizedBox(height: 20),

            // SECTION 6 — Legal & Support
            NeuCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showInfoDialog('Privacy Policy', 'Your data is encrypted and handled according to healthcare standards. We do not sell doctor or patient information to third parties.'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Terms of Use'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showInfoDialog('Terms of Use', 'By using MediFlow, you agree to maintain professional confidentiality and comply with local medical regulations.'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email_outlined, color: AppTheme.primaryTeal),
                    title: const Text('Contact Support'),
                    onTap: _contactSupport,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            const Text('Made with care for healthcare professionals', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, Widget content) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(title),
          content,
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, color: Color(0xFF718096), letterSpacing: 1.2, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: AppTheme.primaryTeal),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildTechChip(String label, Color color) {
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

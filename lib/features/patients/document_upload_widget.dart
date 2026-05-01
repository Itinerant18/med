import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/core/app_snackbar.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/features/patients/document_provider.dart';
import 'package:mediflow/shared/widgets/confirm_dialog.dart';

class DocumentUploadWidget extends ConsumerStatefulWidget {
  final String patientId;

  const DocumentUploadWidget({super.key, required this.patientId});

  @override
  ConsumerState<DocumentUploadWidget> createState() =>
      _DocumentUploadWidgetState();
}

class _DocumentUploadWidgetState extends ConsumerState<DocumentUploadWidget> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Handle Permissions
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        if (status.isPermanentlyDenied) {
          if (mounted) {
            AppSnackbar.showWarning(context,
                'Camera permission required. Please enable in settings.');
            openAppSettings();
          }
          return;
        }
        if (!status.isGranted) return;
      }

      final XFile? image =
          await _picker.pickImage(source: source, imageQuality: 80);
      if (image == null) return;

      setState(() => _isUploading = true);

      await ref
          .read(documentNotifierProvider(widget.patientId).notifier)
          .uploadDocument(image);

      if (mounted) {
        AppSnackbar.showSuccess(context, 'Document uploaded successfully');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, AppError.getMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(AppIcons.camera_alt,
                    color: AppTheme.primaryTeal),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(AppIcons.photo_library,
                    color: AppTheme.primaryTeal),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentNotifierProvider(widget.patientId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Patient Documents',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTeal),
            ),
            IconButton(
              icon:
                  const Icon(AppIcons.add_a_photo, color: AppTheme.primaryTeal),
              onPressed: _isUploading ? null : _showSourcePicker,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: docsAsync.when(
            data: (urls) {
              if (urls.isEmpty && !_isUploading) {
                return GestureDetector(
                  onTap: _showSourcePicker,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.grey.shade400, style: BorderStyle.none),
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.grey.shade200.withValues(alpha: 0.5),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(AppIcons.add_photo_alternate_outlined,
                            color: Colors.grey, size: 32),
                        SizedBox(height: 4),
                        Text('Tap + to add documents',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: urls.length + (_isUploading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isUploading && index == urls.length) {
                    return _buildLoadingSlot();
                  }

                  final doc = urls[index];
                  final url = doc.url;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onLongPress: () => _confirmDelete(doc),
                      onTap: () => _viewImage(doc),
                      child: NeuCard(
                        padding: EdgeInsets.zero,
                        borderRadius: 12,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: url,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            errorWidget: (context, url, error) =>
                                const Icon(AppIcons.error),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error: $err'),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSlot() {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppTheme.primaryTeal),
        ),
      ),
    );
  }

  void _confirmDelete(PatientDocument doc) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete Document',
      message: 'Are you sure you want to permanently remove this document?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    try {
      await ref
          .read(documentNotifierProvider(widget.patientId).notifier)
          .deleteDocument(doc);
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Document deleted');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, AppError.getMessage(e));
      }
    }
  }

  void _viewImage(PatientDocument doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          url: doc.url,
          onDelete: () => _confirmDelete(doc),
        ),
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String url;
  final VoidCallback onDelete;

  const FullScreenImageViewer(
      {super.key, required this.url, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(AppIcons.share),
            onPressed: () async {
              // Using SharePlus as per linter suggestion
              await SharePlus.instance.share(ShareParams(text: url));
            },
          ),
          IconButton(
            icon: const Icon(AppIcons.delete),
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}

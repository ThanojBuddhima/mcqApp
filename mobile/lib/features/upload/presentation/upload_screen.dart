import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key, this.mode});

  /// `scan`, `pdf`, or `gallery` — auto-starts the matching picker when set.
  final String? mode;

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  String? _jobId;
  Map<String, dynamic>? _jobStatus;
  Timer? _pollTimer;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runModeAction());
    }
  }

  Future<void> _runModeAction() async {
    switch (widget.mode) {
      case 'scan':
        await _pickCamera();
      case 'pdf':
        await _pickPdf();
      case 'gallery':
        await _pickGallery();
    }
  }

  String get _title {
    return switch (widget.mode) {
      'scan' => 'Scan paper',
      'pdf' => 'Upload PDF',
      'gallery' => 'Choose photo',
      _ => 'Upload paper',
    };
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _upload(List<int> bytes, String filename, String contentType) async {
    setState(() {
      _uploading = true;
      _jobId = null;
      _jobStatus = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final res = await dio.post('/documents/upload', data: formData);
      setState(() {
        _jobId = res.data['id'];
        _jobStatus = Map<String, dynamic>.from(res.data);
      });
      _startPolling();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      setState(() => _uploading = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_jobId == null) return;
      try {
        final dio = ref.read(dioProvider);
        final res = await dio.get('/documents/jobs/$_jobId');
        setState(() => _jobStatus = Map<String, dynamic>.from(res.data));
        final status = res.data['status'];
        if (status == 'completed' || status == 'failed') {
          _pollTimer?.cancel();
          if (status == 'completed' && res.data['result_quiz_id'] != null && mounted) {
            context.push('/quiz/edit/${res.data['result_quiz_id']}');
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _pickCamera() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await _upload(bytes, file.name, 'image/jpeg');
  }

  Future<void> _pickGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await _upload(bytes, file.name, 'image/jpeg');
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.bytes == null) return;
    await _upload(result.files.single.bytes!, result.files.single.name, 'application/pdf');
  }

  @override
  Widget build(BuildContext context) {
    final progress = _jobStatus?['progress_percent'] ?? 0;
    final status = _jobStatus?['status'] ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.mode == null) ...[
              Text(
                'Upload a scanned paper, photo, or PDF. PaddleOCR will extract Sinhala & English text and preserve diagrams.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              _UploadOption(
                icon: Icons.camera_alt_outlined,
                label: 'Take photo',
                onTap: _uploading ? null : _pickCamera,
              ),
              const SizedBox(height: 12),
              _UploadOption(
                icon: Icons.photo_library_outlined,
                label: 'Choose from gallery',
                onTap: _uploading ? null : _pickGallery,
              ),
              const SizedBox(height: 12),
              _UploadOption(
                icon: Icons.picture_as_pdf_outlined,
                label: 'Upload PDF',
                onTap: _uploading ? null : _pickPdf,
              ),
            ] else if (_jobStatus == null && !_uploading) ...[
              Text(
                widget.mode == 'scan'
                    ? 'Point your camera at the paper. OCR will extract questions automatically.'
                    : widget.mode == 'pdf'
                        ? 'Select a PDF file to upload and process.'
                        : 'Pick a photo from your gallery to scan.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              _UploadOption(
                icon: widget.mode == 'scan'
                    ? Icons.camera_alt_outlined
                    : widget.mode == 'pdf'
                        ? Icons.picture_as_pdf_outlined
                        : Icons.photo_library_outlined,
                label: widget.mode == 'scan'
                    ? 'Open camera'
                    : widget.mode == 'pdf'
                        ? 'Choose PDF'
                        : 'Open gallery',
                onTap: _uploading ? null : _runModeAction,
              ),
            ],
            if (_uploading) ...[
              const SizedBox(height: 40),
              const Center(child: CircularProgressIndicator(color: AppColors.black)),
              const SizedBox(height: 12),
              const Center(child: Text('Uploading…', style: TextStyle(color: AppColors.textSecondary))),
            ],
            if (_jobStatus != null) ...[
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: $status', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: progress / 100, minHeight: 4),
                    ),
                    const SizedBox(height: 8),
                    Text('$progress% complete', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    if (_jobStatus?['error_log'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_jobStatus!['error_log'], style: const TextStyle(color: AppColors.error, fontSize: 13)),
                      ),
                    if (status == 'failed') ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _jobId = null;
                              _jobStatus = null;
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ),
                    ],
                    if (status == 'completed' && _jobStatus?['result_quiz_id'] != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/quiz/edit/${_jobStatus!['result_quiz_id']}'),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Review & edit quiz'),
                        ),
                      ),
                    ],
                    if (status == 'completed' && _jobStatus?['result_quiz_id'] == null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Processing completed but no questions were extracted. Try uploading a clearer image.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _jobId = null;
                              _jobStatus = null;
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UploadOption extends StatelessWidget {
  const _UploadOption({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textPrimary),
              const SizedBox(width: 16),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15))),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

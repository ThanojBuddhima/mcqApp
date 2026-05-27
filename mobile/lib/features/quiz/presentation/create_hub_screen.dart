import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

class CreateHubScreen extends StatelessWidget {
  const CreateHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Create')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text('How would you like to create?', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Scan a paper, upload a PDF, or build a quiz manually.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 28),
          _CreateOption(
            icon: Icons.document_scanner_outlined,
            title: 'Scan',
            subtitle: 'Take a photo of a paper to extract questions',
            onTap: () => context.push('/upload?mode=scan'),
          ),
          const SizedBox(height: 12),
          _CreateOption(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Upload PDF',
            subtitle: 'Upload a PDF file for OCR processing',
            onTap: () => context.push('/upload?mode=pdf'),
          ),
          const SizedBox(height: 12),
          _CreateOption(
            icon: Icons.photo_library_outlined,
            title: 'Gallery',
            subtitle: 'Choose a photo from your gallery to scan',
            onTap: () => context.push('/upload?mode=gallery'),
          ),
          const SizedBox(height: 12),
          _CreateOption(
            icon: Icons.edit_note_outlined,
            title: 'Create new quiz',
            subtitle: 'Add topic, questions, and answers manually',
            onTap: () => context.push('/quiz/create'),
          ),
        ],
      ),
    );
  }
}

class _CreateOption extends StatelessWidget {
  const _CreateOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

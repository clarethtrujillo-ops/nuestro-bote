import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../profile/domain/models/user_profile.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';

class WishFormSection extends StatelessWidget {
  const WishFormSection({
    required this.controller,
    required this.noteController,
    required this.selectedCategory,
    required this.selectedProposer,
    required this.selectedDate,
    required this.onCategoryChanged,
    required this.onSelectDate,
    this.proposerProfile,
    super.key,
  });

  final TextEditingController controller;
  final TextEditingController noteController;

  final String selectedCategory;
  final String selectedProposer;
  final UserProfile? proposerProfile;
  final DateTime? selectedDate;

  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onSelectDate;

  @override
  Widget build(BuildContext context) {
    final profile = proposerProfile;
    final name = profile?.name.trim() ?? selectedProposer.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldTitle(text: '¿Qué quieren hacer?'),
          const SizedBox(height: 7),
          TextField(
            controller: controller,
            maxLength: 80,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              height: 1.35,
            ),
            decoration: _fieldDecoration(
              hintText: 'Ej. Ver el amanecer junto al mar',
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              _FieldTitle(text: 'Nota'),
              SizedBox(width: 6),
              Text(
                'Opcional',
                style: TextStyle(
                  color: AppColors.inactive,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          TextField(
            controller: noteController,
            maxLength: 140,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              height: 1.35,
            ),
            decoration: _fieldDecoration(
              hintText:
                  'Añade un lugar, una idea o algo que no quieran olvidar',
            ),
          ),
          const SizedBox(height: 12),
          const _FieldTitle(text: 'Categoría'),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final category in const [
                'Plan',
                'Experiencia',
                'Detalle',
              ]) ...[
                if (category != 'Plan') const SizedBox(width: 7),
                Expanded(
                  child: _SelectionButton(
                    label: category,
                    selected: selectedCategory == category,
                    onPressed: () => onCategoryChanged(category),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 17),
          const _FieldTitle(text: 'Fecha para cumplirlo'),
          const SizedBox(height: 8),
          Material(
            color: AppColors.elevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onSelectDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.textSecondary,
                      size: 17,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        selectedDate == null
                            ? 'Elegir una fecha'
                            : _formatDate(selectedDate!),
                        style: TextStyle(
                          color: selectedDate == null
                              ? AppColors.inactive
                              : AppColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 17),
          const _FieldTitle(text: 'Propuesto por'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                if (profile != null)
                  ProfileAvatar(
                    profile: profile,
                    size: 40,
                    borderColor: AppColors.coral,
                    borderWidth: 1.2,
                  )
                else
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name.isEmpty ? 'Autor no disponible' : name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static InputDecoration _fieldDecoration({
    required String hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: AppColors.inactive,
        fontSize: 11,
        height: 1.35,
      ),
      counterStyle: const TextStyle(
        color: AppColors.inactive,
        fontSize: 9,
      ),
      filled: true,
      fillColor: AppColors.elevated,
      contentPadding: const EdgeInsets.all(13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.coral),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }
}

class _FieldTitle extends StatelessWidget {
  const _FieldTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _SelectionButton extends StatelessWidget {
  const _SelectionButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? AppColors.coral : AppColors.textSecondary,
        backgroundColor: selected
            ? AppColors.coral.withValues(alpha: 0.08)
            : AppColors.elevated,
        side: BorderSide(
          color: selected ? AppColors.coral : AppColors.border,
        ),
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(
          horizontal: 3,
          vertical: 10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
      ),
    );
  }
}

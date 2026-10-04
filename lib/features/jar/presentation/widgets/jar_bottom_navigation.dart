import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class JarBottomNavigation extends StatelessWidget {
  const JarBottomNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.border,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _NavigationItem(
                icon: Icons.inventory_2_outlined,
                selectedIcon: Icons.inventory_2_rounded,
                label: 'Bote',
                selected: selectedIndex == 0,
                onTap: () => onDestinationSelected(0),
              ),
            ),
            Expanded(
              child: _NavigationItem(
                icon: Icons.auto_awesome_outlined,
                selectedIcon: Icons.auto_awesome_rounded,
                label: 'Recuerdos',
                selected: selectedIndex == 1,
                onTap: () => onDestinationSelected(1),
              ),
            ),
            Expanded(
              child: _NavigationItem(
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: 'Perfil',
                selected: selectedIndex == 2,
                onTap: () => onDestinationSelected(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.coral : AppColors.inactive;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.coral.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: Icon(
                  selected ? selectedIcon : icon,
                  key: ValueKey(selected),
                  size: 21,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

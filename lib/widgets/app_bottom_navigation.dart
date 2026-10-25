import 'package:flutter/material.dart';

import '../providers/language_provider.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.index,
    required this.onSelected,
    required this.language,
    this.cartCount = 0,
  });

  final int index;
  final ValueChanged<int> onSelected;
  final LanguageProvider language;
  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              index: 0,
              icon: Icons.home_outlined,
              activeIcon: Icons.home_filled,
              label: language.tr('Beranda'),
            ),
            _buildNavItem(
              index: 1,
              icon: Icons.shopping_cart_outlined,
              activeIcon: Icons.shopping_cart,
              label: language.tr('Keranjang'),
              badgeCount: cartCount,
            ),
            _buildNavItem(
              index: 2,
              icon: Icons.local_shipping_outlined,
              activeIcon: Icons.local_shipping,
              label: language.tr('Status'),
            ),
            _buildNavItem(
              index: 3,
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long,
              label: language.tr('Riwayat'),
            ),
            _buildNavItem(
              index: 4,
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: language.tr('Profil'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int badgeCount = 0,
  }) {
    final bool isSelected = this.index == index;
    return Flexible(
      child: GestureDetector(
        onTap: () => onSelected(index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 14 : 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4A3022).withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Badge(
                  isLabelVisible: badgeCount > 0,
                  label: Text(
                    '$badgeCount',
                    style: const TextStyle(fontSize: 9, color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFFE57373),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      isSelected ? activeIcon : icon,
                      key: ValueKey(isSelected),
                      color: isSelected
                          ? const Color(0xFF4A3022)
                          : const Color(0xFFB0B0B0),
                      size: isSelected ? 24 : 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontFamily: 'CiksSans',
                  fontSize: isSelected ? 10 : 9,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected
                      ? const Color(0xFF4A3022)
                      : const Color(0xFFB0B0B0),
                ),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

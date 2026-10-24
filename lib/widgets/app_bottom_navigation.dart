import 'package:flutter/material.dart';

import '../providers/language_provider.dart';
import 'coffee_overlays.dart';

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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: CoffeeColors.ink.withValues(alpha: 0.07),
                blurRadius: 22,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: NavigationBarTheme(
            data: const NavigationBarThemeData(
              labelTextStyle: WidgetStatePropertyAll(
                TextStyle(
                  fontFamily: 'CiksSans',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: onSelected,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              height: 66,
              indicatorColor: CoffeeColors.ink.withValues(alpha: 0.08),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded),
                  label: language.tr('Beranda'),
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: cartCount > 0,
                    label: Text('$cartCount'),
                    child: const Icon(Icons.shopping_bag_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: cartCount > 0,
                    label: Text('$cartCount'),
                    child: const Icon(Icons.shopping_bag_rounded),
                  ),
                  label: language.tr('Keranjang'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.local_shipping_outlined),
                  selectedIcon: const Icon(Icons.local_shipping_rounded),
                  label: language.tr('Status'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.receipt_long_outlined),
                  selectedIcon: const Icon(Icons.receipt_long_rounded),
                  label: language.tr('Riwayat'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline_rounded),
                  selectedIcon: const Icon(Icons.person_rounded),
                  label: language.tr('Profil'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

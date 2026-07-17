import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import 'cart_screen.dart';
import 'order_status_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  
  List<dynamic> _categories = [];
  List<dynamic> _products = [];
  
  bool _isLoadingCategories = true;
  bool _isLoadingProducts = true;
  
  int _selectedCategoryId = 0; // 0 means 'All'
  int _currentIndex = 0; // For BottomNavigationBar
  String? _userName;

  bool _bannerAnimReady = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchProducts();
    _fetchProfile();

    // Trigger entrance animation after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _bannerAnimReady = true);
      }
    });
  }

  Future<void> _fetchProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedName = prefs.getString('user_name');
    if (cachedName != null && cachedName.isNotEmpty) {
      if (mounted) {
        setState(() {
          _userName = cachedName;
        });
      }
    }

    final result = await _apiService.getProfile();
    if (result['success'] && result['data'] != null) {
      final name = result['data']['name']?.toString();
      if (name != null && name.isNotEmpty && mounted) {
        await prefs.setString('user_name', name);
        setState(() {
          _userName = name;
        });
      }
    }
  }

  Future<void> _fetchCategories() async {
    final result = await _apiService.getCategories();
    if (result['success']) {
      if (mounted) {
        setState(() {
          _categories = result['data'];
          _isLoadingCategories = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    }
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoadingProducts = true;
    });
    final result = await _apiService.getProducts(categoryId: _selectedCategoryId);
    if (result['success']) {
      if (mounted) {
        setState(() {
          _products = result['data'];
          _isLoadingProducts = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    }
  }

  void _onCategorySelected(int categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
    _fetchProducts();
    _fetchProfile();
  }

  String _formatPrice(dynamic price) {
    if (price == null) return 'Rp 0';
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatCurrency.format(double.parse(price.toString()));
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  String _getGreeting(LanguageProvider lang) {
    final hour = DateTime.now().hour;
    if (hour < 11) {
      return lang.tr('Selamat Pagi');
    } else if (hour < 15) {
      return lang.tr('Selamat Siang');
    } else if (hour < 18) {
      return lang.tr('Selamat Sore');
    } else {
      return lang.tr('Selamat Malam');
    }
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 11) {
      return Icons.wb_sunny_rounded;
    } else if (hour < 15) {
      return Icons.wb_cloudy_rounded;
    } else if (hour < 18) {
      return Icons.wb_twilight_rounded;
    } else {
      return Icons.nightlight_round;
    }
  }

  /// Show variant picker for coffee products, or add directly
  void _handleAddToCart(Map<String, dynamic> productJson) {
    final product = ProductModel.fromJson(productJson);
    final cart = Provider.of<CartProvider>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    if (product.hasLitePrice) {
      // Coffee product: show variant picker
      _showVariantPicker(product, cart, lang);
    } else {
      // Non-coffee: add directly
      cart.addItem(product);
      _showAddedSnackbar(product.name, lang);
    }
  }

  void _showVariantPicker(ProductModel product, CartProvider cart, LanguageProvider lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A3022).withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD2B48C).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                lang.tr('Pilih Varian'),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C1810),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.name,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF8B7355),
                ),
              ),
              const SizedBox(height: 20),
              // Base variant
              _buildVariantOption(
                label: 'Base',
                subtitle: 'Original size',
                price: _formatPrice(product.price),
                icon: Icons.coffee,
                onTap: () {
                  Navigator.pop(ctx);
                  cart.addItem(product, variant: 'base');
                  _showAddedSnackbar('${product.name} (Base)', lang);
                },
              ),
              const SizedBox(height: 12),
              // Lite variant
              _buildVariantOption(
                label: 'Lite',
                subtitle: 'Smaller size',
                price: _formatPrice(product.priceLite),
                icon: Icons.local_cafe,
                onTap: () {
                  Navigator.pop(ctx);
                  cart.addItem(product, variant: 'lite');
                  _showAddedSnackbar('${product.name} (Lite)', lang);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVariantOption({
    required String label,
    required String subtitle,
    required String price,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE8DDD0)),
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFFAF6F1),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5D3A1A), Color(0xFF8B6B4A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: const Color(0xFF2C1810),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF8B7355),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: const Color(0xFF2C1810),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddedSnackbar(String productName, LanguageProvider lang) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$productName ${lang.tr('ditambahkan ke keranjang')}',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2C1810),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F1E8),
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeContent(),
          const CartScreen(),
          const OrderStatusScreen(),
          const HistoryScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Consumer<CartProvider>(
        builder: (context, cart, child) {
          return Container(
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
                  label: lang.tr('Beranda'),
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.shopping_cart_outlined,
                  activeIcon: Icons.shopping_cart,
                  label: lang.tr('Keranjang'),
                  badgeCount: cart.totalItemCount,
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.local_shipping_outlined,
                  activeIcon: Icons.local_shipping,
                  label: lang.tr('Status'),
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: lang.tr('Riwayat'),
                ),
                _buildNavItem(
                  index: 4,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: lang.tr('Profil'),
                ),
              ],
            ),
          );
        },
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
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onBottomNavTapped(index),
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
              style: GoogleFonts.inter(
                fontSize: isSelected ? 10 : 9,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? const Color(0xFF4A3022)
                    : const Color(0xFFB0B0B0),
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    final lang = Provider.of<LanguageProvider>(context);
    
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchCategories();
        await _fetchProducts();
      },
      color: const Color(0xFF2C1810),
      backgroundColor: Colors.white,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ============================================
          // PROMO BANNER SECTION
          // ============================================
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: AnimatedSlide(
                offset: _bannerAnimReady ? Offset.zero : const Offset(0, 0.1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _bannerAnimReady ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOut,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Container(
                      height: 130,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF5D3A1A),
                            Color(0xFF8B6B4A),
                            Color(0xFFD4A574),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5D3A1A).withValues(alpha: 0.30),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Decorative circles
                          Positioned(
                            right: -20,
                            top: -20,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 30,
                            bottom: -30,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.04),
                              ),
                            ),
                          ),
                          // Content
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getGreetingIcon(),
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              _getGreeting(lang).toUpperCase(),
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                                letterSpacing: 1.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        lang.tr('Nikmati kopi\nterbaik kami'),
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Time-based icon area
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    _getGreetingIcon(),
                                    size: 36,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
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

          // ============================================
          // CATEGORIES SECTION
          // ============================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD4A574), Color(0xFF8B6B4A)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    lang.tr('Kategori'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2C1810),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _isLoadingCategories
                ? const SizedBox(
                    height: 44,
                    child: Center(child: CircularProgressIndicator(
                      color: Color(0xFF5D3A1A),
                      strokeWidth: 2.5,
                    )),
                  )
                : SizedBox(
                    height: 44,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _categories.length + 1,
                      itemBuilder: (context, index) {
                        final isAll = index == 0;
                        final category = isAll ? null : _categories[index - 1];
                        final id = isAll ? 0 : category['id'];
                        final name = isAll ? lang.tr('Semua') : category['name'];
                        final isSelected = _selectedCategoryId == id;

                        // Category icons mapping
                        IconData categoryIcon = Icons.grid_view_rounded;
                        if (isAll) {
                          categoryIcon = Icons.apps_rounded;
                        } else {
                          final catName = (category['name'] ?? '').toString().toLowerCase();
                          if (catName.contains('kopi') || catName.contains('coffee')) {
                            categoryIcon = Icons.coffee_rounded;
                          } else if (catName.contains('non') || catName.contains('minuman')) {
                            categoryIcon = Icons.local_cafe_rounded;
                          } else if (catName.contains('makan') || catName.contains('food') || catName.contains('snack')) {
                            categoryIcon = Icons.restaurant_rounded;
                          } else if (catName.contains('dessert') || catName.contains('kue')) {
                            categoryIcon = Icons.cake_rounded;
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () {
                              if (!isSelected) _onCategorySelected(id);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                              decoration: BoxDecoration(
                                gradient: isSelected 
                                  ? const LinearGradient(
                                      colors: [Color(0xFF2C1810), Color(0xFF5D3A1A)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                                color: isSelected ? null : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: isSelected 
                                  ? null 
                                  : Border.all(
                                      color: const Color(0xFFE8DDD0),
                                      width: 1,
                                    ),
                                boxShadow: isSelected 
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF2C1810).withValues(alpha: 0.25),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      categoryIcon,
                                      size: 15,
                                      color: isSelected 
                                        ? const Color(0xFFD4A574) 
                                        : const Color(0xFF8B7355),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      name,
                                      style: GoogleFonts.inter(
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        fontSize: 13,
                                        color: isSelected ? Colors.white : const Color(0xFF4A3930),
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),

          // ============================================
          // PRODUCTS SECTION HEADER
          // ============================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD4A574), Color(0xFF8B6B4A)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    lang.tr('Menu Pilihan'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2C1810),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_products.length} ${lang.tr('item')}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF8B7355),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ============================================
          // PRODUCTS GRID
          // ============================================
          _isLoadingProducts
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(
                    color: Color(0xFF5D3A1A),
                    strokeWidth: 2.5,
                  )),
                )
              : _products.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8DDD0).withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.search_off_rounded,
                                size: 36,
                                color: Color(0xFF8B7355),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              lang.tr('Tidak ada produk ditemukan.'),
                              style: GoogleFonts.inter(
                                color: const Color(0xFF8B7355),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.64,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = _products[index];
                            final imageUrl = _apiService.getImageUrl(product['image_url'] ?? '');
                            final isAvailable = (product['is_available'] ?? true) == true;
                            
                            return _buildProductCard(product, imageUrl, isAvailable, lang);
                          },
                          childCount: _products.length,
                        ),
                      ),
                    ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    Map<String, dynamic> product,
    String imageUrl,
    bool isAvailable,
    LanguageProvider lang,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C1810).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF2C1810).withValues(alpha: 0.02),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          color: isAvailable ? null : const Color(0xFF000000).withValues(alpha: 0.55),
                          colorBlendMode: isAvailable ? null : BlendMode.darken,
                          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                  // Category tag
                  if (product['category']?['name'] != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C1810).withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              product['category']['name'],
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Sold out overlay
                  if (!isAvailable)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C1810).withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              lang.tr('Habis'),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Info section
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    product['name'],
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: const Color(0xFF2C1810),
                      height: 1.3,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          _formatPrice(product['price']),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: const Color(0xFF5D3A1A),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: isAvailable ? () => _handleAddToCart(product) : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            gradient: isAvailable 
                              ? const LinearGradient(
                                  colors: [Color(0xFF2C1810), Color(0xFF5D3A1A)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                            color: isAvailable ? null : const Color(0xFFCCC5BC),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isAvailable 
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF2C1810).withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF5E6D3).withValues(alpha: 0.7),
            const Color(0xFFE8DDD0).withValues(alpha: 0.5),
          ],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.coffee_rounded,
            size: 32,
            color: Color(0xFFD4A574),
          ),
        ),
      ),
    );
  }
}

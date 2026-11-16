import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';
import '../widgets/brand_mark.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/coffee_overlays.dart';
import 'cart_screen.dart';
import 'order_status_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'table_availability_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialIndex = 0, this.apiService});

  final int initialIndex;
  final ApiService? apiService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final ApiService _apiService = widget.apiService ?? ApiService();
  StreamSubscription<void>? _statusNavigationSubscription;
  Timer? _stockTimer;
  int _catalogueRequest = 0;
  bool _catalogueBusy = false;

  List<dynamic> _categories = [];
  List<dynamic> _products = [];

  bool _isLoadingCategories = true;
  bool _isLoadingProducts = true;

  int _selectedCategoryId = 0; // 0 means 'All'
  int _currentIndex = 0; // For BottomNavigationBar
  bool _bannerAnimReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex.clamp(0, 4);
    _statusNavigationSubscription = PushNotificationService
        .instance
        .statusNavigation
        .listen((_) {
          PushNotificationService.instance.consumePendingStatusNavigation();
          if (mounted) {
            setState(() => _currentIndex = 2);
          }
        });
    _fetchCategories();
    _fetchProducts();
    _fetchProfile();
    _stockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          (_currentIndex == 0 || _currentIndex == 1)) {
        _fetchProducts(silent: true);
      }
    });

    // Trigger entrance animation after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _bannerAnimReady = true);
      }
    });
  }

  @override
  void dispose() {
    _stockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _statusNavigationSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _fetchProducts(silent: true);
  }

  Future<void> _fetchProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final result = await _apiService.getProfile();
    if (result['success'] && result['data'] != null) {
      final name = result['data']['name']?.toString();
      if (name != null && name.isNotEmpty) {
        await prefs.setString('user_name', name);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result['message'])));
      }
    }
  }

  Future<void> _fetchProducts({bool silent = false}) async {
    if (!mounted || (silent && _catalogueBusy)) return;
    final request = ++_catalogueRequest;
    _catalogueBusy = true;
    if (!silent) setState(() => _isLoadingProducts = true);
    // Refresh the full catalogue so cart stock stays current across categories.
    final result = await _apiService.getProducts();
    if (!mounted || request != _catalogueRequest) return;
    _catalogueBusy = false;
    if (result['success']) {
      if (mounted) {
        final all = List<Map<String, dynamic>>.from(
          (result['data'] as List).map(
            (row) => Map<String, dynamic>.from(row as Map),
          ),
        );
        context.read<CartProvider>().updateCatalogue(
          all.map(ProductModel.fromJson).toList(),
        );
        setState(() {
          _products = all
              .where(
                (product) =>
                    _selectedCategoryId == 0 ||
                    product['category_id'] == _selectedCategoryId,
              )
              .toList();
          _isLoadingProducts = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
        if (!silent) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result['message'])));
        }
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
    final formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatCurrency.format(double.parse(price.toString()));
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (index == 0 || index == 1) _fetchProducts(silent: true);
  }

  String _getGreeting(LanguageProvider lang) {
    final hour = DateTime.now().toUtc().add(const Duration(hours: 7)).hour;
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
    final hour = DateTime.now().toUtc().add(const Duration(hours: 7)).hour;
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
    if (!product.hasStock) return;

    if (product.isCoffee) {
      if (product.hasLitePrice) {
        // Coffee with two sizes: let the customer choose the recipe variant.
        _showVariantPicker(product, cart, lang);
      } else {
        // A coffee without Lite pricing still uses the Base recipe.
        _addProduct(product, cart, lang, variant: 'base');
      }
    } else {
      // Non-coffee products do not have a recipe variant.
      _addProduct(product, cart, lang);
    }
  }

  void _addProduct(
    ProductModel product,
    CartProvider cart,
    LanguageProvider lang, {
    String? variant,
  }) {
    if (cart.addItem(product, variant: variant)) {
      _showAddedSnackbar(
        '${product.name}${variant == null ? '' : ' (${variant == 'base' ? 'Base' : 'Lite'})'}',
        lang,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.isEnglish
                ? 'This product is sold out or its remaining stock is already in your cart.'
                : 'Produk habis atau sisa stoknya sudah ada di keranjang.',
          ),
        ),
      );
    }
  }

  void _showVariantPicker(
    ProductModel product,
    CartProvider cart,
    LanguageProvider lang,
  ) {
    showCoffeeSheet<void>(
      context: context,
      builder: (ctx) => CoffeeSheet(
        title: lang.isEnglish ? 'Choose your coffee' : 'Pilih varian kopimu',
        subtitle: product.name,
        dismissLabel: lang.tr('Tutup'),
        child: Consumer<CartProvider>(
          builder: (context, cart, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CoffeeOptionTile(
                title: 'Base',
                subtitle: lang.isEnglish
                    ? 'Regular coffee intensity · ${_variantStockLabel(product, cart, 'base', lang)}'
                    : 'Takaran kopi reguler · ${_variantStockLabel(product, cart, 'base', lang)}',
                value: _formatPrice(product.price),
                icon: Icons.coffee_outlined,
                onTap: !cart.canAddItem(product, variant: 'base')
                    ? null
                    : () {
                        Navigator.of(ctx).pop();
                        _addProduct(product, cart, lang, variant: 'base');
                      },
              ),
              const SizedBox(height: 12),
              CoffeeOptionTile(
                title: 'Lite',
                subtitle: lang.isEnglish
                    ? 'A milder coffee taste · ${_variantStockLabel(product, cart, 'lite', lang)}'
                    : 'Takaran kopi lebih ringan · ${_variantStockLabel(product, cart, 'lite', lang)}',
                value: _formatPrice(product.priceLite),
                icon: Icons.local_cafe_outlined,
                onTap: !cart.canAddItem(product, variant: 'lite')
                    ? null
                    : () {
                        Navigator.of(ctx).pop();
                        _addProduct(product, cart, lang, variant: 'lite');
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _variantStockLabel(
    ProductModel product,
    CartProvider cart,
    String? variant,
    LanguageProvider lang,
  ) {
    final remaining = cart.remainingFor(product, variant: variant);
    if (remaining == null) return lang.isEnglish ? 'Available' : 'Tersedia';
    if (remaining == 0) return lang.isEnglish ? 'Sold out' : 'Habis';
    return lang.isEnglish
        ? '$remaining portions left'
        : 'Sisa $remaining porsi';
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
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$productName ${lang.tr('ditambahkan ke keranjang')}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
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
          CartScreen(apiService: _apiService),
          const OrderStatusScreen(),
          const HistoryScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Consumer<CartProvider>(
        builder: (context, cart, _) => AppBottomNavigation(
          index: _currentIndex,
          onSelected: _onBottomNavTapped,
          language: lang,
          cartCount: cart.totalItemCount,
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    final lang = Provider.of<LanguageProvider>(context);
    context.watch<CartProvider>();

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchCategories();
        await _fetchProducts();
      },
      color: const Color(0xFF2C1810),
      backgroundColor: Colors.white,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
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
                      clipBehavior: Clip.antiAlias,
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
                            color: const Color(
                              0xFF5D3A1A,
                            ).withValues(alpha: 0.30),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                // CiksCoffee identity
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Center(
                                    child: BrandMark(
                                      size: 48,
                                      color: BrandMark.cream,
                                    ),
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
          // TABLE AVAILABILITY SHORTCUT
          // ============================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TableAvailabilityScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFFDCC7B4).withValues(alpha: 0.8),
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF5D3A1A,
                          ).withValues(alpha: 0.07),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F7F1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.event_seat_rounded,
                            color: Color(0xFF16856F),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.tr('Cari meja yang tersedia'),
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF2C1810),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                lang.tr(
                                  'Lihat denah dan status meja secara langsung',
                                ),
                                style: GoogleFonts.inter(
                                  color: const Color(
                                    0xFF5D3A1A,
                                  ).withValues(alpha: 0.58),
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFF805434),
                          size: 20,
                        ),
                      ],
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
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF5D3A1A),
                        strokeWidth: 2.5,
                      ),
                    ),
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
                        final name = isAll
                            ? lang.tr('Semua')
                            : category['name'];
                        final isSelected = _selectedCategoryId == id;

                        // Category icons mapping
                        IconData categoryIcon = Icons.grid_view_rounded;
                        if (isAll) {
                          categoryIcon = Icons.apps_rounded;
                        } else {
                          final catName = (category['name'] ?? '')
                              .toString()
                              .toLowerCase();
                          if (catName.contains('kopi') ||
                              catName.contains('coffee')) {
                            categoryIcon = Icons.coffee_rounded;
                          } else if (catName.contains('non') ||
                              catName.contains('minuman')) {
                            categoryIcon = Icons.local_cafe_rounded;
                          } else if (catName.contains('makan') ||
                              catName.contains('food') ||
                              catName.contains('snack')) {
                            categoryIcon = Icons.restaurant_rounded;
                          } else if (catName.contains('dessert') ||
                              catName.contains('kue')) {
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 0,
                              ),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFF2C1810),
                                          Color(0xFF5D3A1A),
                                        ],
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
                                          color: const Color(
                                            0xFF2C1810,
                                          ).withValues(alpha: 0.25),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.03,
                                          ),
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
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        fontSize: 13,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF4A3930),
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
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF5D3A1A),
                      strokeWidth: 2.5,
                    ),
                  ),
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
                            color: const Color(
                              0xFFE8DDD0,
                            ).withValues(alpha: 0.5),
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
                  sliver: SliverToBoxAdapter(
                    child: _buildProductMasonryGrid(lang),
                  ),
                ),

          SliverToBoxAdapter(
            child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
          ),
        ],
      ),
    );
  }

  Widget _buildProductMasonryGrid(LanguageProvider lang) {
    final leftColumn = <Widget>[];
    final rightColumn = <Widget>[];

    for (var index = 0; index < _products.length; index++) {
      final product = Map<String, dynamic>.from(_products[index] as Map);
      final imageUrl = _apiService.getImageUrl(product['image_url'] ?? '');
      final model = ProductModel.fromJson(product);
      final cart = context.read<CartProvider>();
      final isAvailable =
          (cart.currentProduct(model)?.hasStock ?? false) &&
          (model.isCoffee
              ? cart.canAddItem(model, variant: 'base') ||
                    (model.hasLitePrice &&
                        cart.canAddItem(model, variant: 'lite'))
              : cart.canAddItem(model));
      final column = index.isEven ? leftColumn : rightColumn;

      column.add(_buildProductCard(product, imageUrl, isAvailable, lang));
      if (index + 2 < _products.length) {
        column.add(const SizedBox(height: 14));
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: leftColumn,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rightColumn,
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(
    Map<String, dynamic> product,
    String imageUrl,
    bool isAvailable,
    LanguageProvider lang,
  ) {
    final description = product['description']?.toString().trim() ?? '';
    final model = ProductModel.fromJson(product);
    final cart = context.read<CartProvider>();
    final inCart =
        (cart.currentProduct(model)?.hasStock ?? false) && !isAvailable;
    final stockLabel = model.isCoffee && model.hasLitePrice
        ? 'Base: ${cart.remainingFor(model, variant: 'base') ?? '—'} · Lite: ${cart.remainingFor(model, variant: 'lite') ?? '—'} ${lang.isEnglish ? 'portions' : 'porsi'}'
        : _variantStockLabel(model, cart, model.isCoffee ? 'base' : null, lang);

    return Opacity(
      opacity: isAvailable ? 1 : 0.65,
      child: Container(
        key: ValueKey('menu-product-${model.id}'),
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
            AspectRatio(
              aspectRatio: 1.24,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            color: isAvailable
                                ? null
                                : Colors.white.withValues(alpha: 0.6),
                            colorBlendMode: isAvailable
                                ? null
                                : BlendMode.lighten,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholder(),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF2C1810,
                                ).withValues(alpha: 0.55),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF2C1810,
                                ).withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                inCart
                                    ? (lang.isEnglish
                                          ? 'In cart'
                                          : 'Di keranjang')
                                    : lang.tr('Habis'),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description.isNotEmpty
                        ? description
                        : 'Deskripsi produk belum tersedia.',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w400,
                      fontSize: 9.5,
                      color: const Color(0xFF8B7355),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stockLabel,
                    key: ValueKey('menu-stock-${model.id}'),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8B7355),
                    ),
                  ),
                  if (!isAvailable)
                    Text(
                      inCart
                          ? (lang.isEnglish
                                ? 'Remaining stock is in your cart'
                                : 'Sisa stok sudah di keranjang')
                          : (lang.isEnglish ? 'Sold out' : 'Stok habis'),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: const Color(0xFF8B7355),
                      ),
                    ),
                  const SizedBox(height: 8),
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
                        key: ValueKey('menu-add-${model.id}'),
                        onTap: isAvailable
                            ? () => _handleAddToCart(product)
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            gradient: isAvailable
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF2C1810),
                                      Color(0xFF5D3A1A),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isAvailable ? null : const Color(0xFFCCC5BC),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isAvailable
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF2C1810,
                                      ).withValues(alpha: 0.25),
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
          ],
        ),
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

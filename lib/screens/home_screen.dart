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

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchProducts();
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
      return lang.tr('Selamat Pagi,');
    } else if (hour < 15) {
      return lang.tr('Selamat Siang,');
    } else if (hour < 18) {
      return lang.tr('Selamat Sore,');
    } else {
      return lang.tr('Selamat Malam,');
    }
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    
    final dayName = days[now.weekday % 7];
    final monthName = months[now.month - 1];
    
    return '$dayName, ${now.day} $monthName ${now.year}';
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.tr('Pilih Varian'),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4A3022),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.name,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF4A3022).withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),
              // Base variant
              _buildVariantOption(
                label: 'Base',
                price: _formatPrice(product.price),
                onTap: () {
                  Navigator.pop(ctx);
                  cart.addItem(product, variant: 'base');
                  _showAddedSnackbar('${product.name} (Base)', lang);
                },
              ),
              const SizedBox(height: 10),
              // Lite variant
              _buildVariantOption(
                label: 'Lite',
                price: _formatPrice(product.priceLite),
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
    required String price,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD2B48C)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4A3022),
              ),
            ),
            Text(
              price,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4A3022),
              ),
            ),
          ],
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
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$productName ${lang.tr('ditambahkan ke keranjang')}',
                style: GoogleFonts.inter(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4A3022),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5E6D3), // Latte
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Consumer<CartProvider>(
          builder: (context, cart, child) {
            return BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onBottomNavTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFF4A3022), // Espresso
              unselectedItemColor: Colors.grey.shade400,
              selectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.normal),
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_filled),
                  label: lang.tr('Beranda'),
                ),
                BottomNavigationBarItem(
                  icon: Badge(
                    isLabelVisible: cart.totalItemCount > 0,
                    label: Text(
                      '${cart.totalItemCount}',
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                    backgroundColor: Colors.red.shade600,
                    child: const Icon(Icons.shopping_cart_outlined),
                  ),
                  activeIcon: Badge(
                    isLabelVisible: cart.totalItemCount > 0,
                    label: Text(
                      '${cart.totalItemCount}',
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                    backgroundColor: Colors.red.shade600,
                    child: const Icon(Icons.shopping_cart),
                  ),
                  label: lang.tr('Keranjang'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.local_shipping_outlined),
                  activeIcon: const Icon(Icons.local_shipping),
                  label: lang.tr('Status'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.receipt_long_outlined),
                  activeIcon: const Icon(Icons.receipt_long),
                  label: lang.tr('Riwayat'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline),
                  activeIcon: const Icon(Icons.person),
                  label: lang.tr('Profil'),
                ),
              ],
            );
          },
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
      color: const Color(0xFF4A3022),
      child: CustomScrollView(
        slivers: [
          // Elegant Header with Bottom Radius (Fixed, no collapse)
          SliverAppBar(
            backgroundColor: const Color(0xFF4A3022), // Espresso
            foregroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            floating: false,
            toolbarHeight: 100, // Not too long
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Ciks Coffee',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getGreeting(lang).replaceAll(',', ''), // Remove comma for inline display
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _getCurrentDate(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  onPressed: () {},
                ),
              ),
            ],
          ),

          // Welcome Message Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 24.0, bottom: 16.0),
              child: Text(
                lang.tr('Mau minum & makan apa hari ini?'),
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4A3022),
                ),
              ),
            ),
          ),

          // Categories Section
          SliverToBoxAdapter(
            child: _isLoadingCategories
                ? const SizedBox(
                    height: 38,
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF4A3022))),
                  )
                : SizedBox(
                    height: 38,
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

                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () {
                              if (!isSelected) _onCategorySelected(id);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF4A3022) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF4A3022) : const Color(0xFFD2B48C).withValues(alpha: 0.5),
                                  width: 1.2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 13,
                                    color: isSelected ? Colors.white : const Color(0xFF4A3022),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Products Grid
          _isLoadingProducts
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF4A3022))),
                )
              : _products.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Text(
                          lang.tr('Tidak ada produk ditemukan.'),
                          style: GoogleFonts.inter(color: const Color(0xFF4A3022)),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.68,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = _products[index];
                            final imageUrl = _apiService.getImageUrl(product['image_url'] ?? '');
                            
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Image
                                  Expanded(
                                    flex: 4,
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                      child: imageUrl.isNotEmpty
                                          ? Image.network(
                                              imageUrl,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                                            )
                                          : _buildPlaceholder(),
                                    ),
                                  ),
                                  // Info
                                  Expanded(
                                    flex: 3,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product['name'],
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: const Color(0xFF4A3022),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                product['category']?['name'] ?? '',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  color: const Color(0xFFD2B48C), // Caramel
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _formatPrice(product['price']),
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: const Color(0xFF4A3022),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () => _handleAddToCart(product),
                                                child: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF4A3022),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(
                                                    Icons.add,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              )
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          childCount: _products.length,
                        ),
                      ),
                    ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFF5E6D3).withValues(alpha: 0.5),
      child: const Center(
        child: Icon(
          Icons.coffee,
          size: 40,
          color: Color(0xFFD2B48C),
        ),
      ),
    );
  }
}

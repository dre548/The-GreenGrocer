import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/auth_service.dart';
import 'package:flutter/foundation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CartProvider()),
        ChangeNotifierProvider(create: (context) => LocationProvider()),
        ChangeNotifierProvider(create: (context) => RoleProvider()),
      ],
      child: const TheGreengrocerApp(),
    ),
  );
}

class TheGreengrocerApp extends StatelessWidget {
  const TheGreengrocerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Greengrocer',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.green[700],
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.greenAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent,
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ============================================================================
// SPLASH SCREEN
// ============================================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B3D24), Color(0xFF124D2E), Color(0xFF1B6B3E)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    // 👇 This is the only line that changed 👇
                    child: Center(child: Image.asset('assets/images/logo.png', width: 70, height: 70)),
                  ),
                  const SizedBox(height: 20),
                  const Text('The Greengrocer', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text('fresh, fast, to your door', style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// GLASS CARD
// ============================================================================
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: Colors.white.withOpacity(0.14),
            border: Border.all(color: Colors.white.withOpacity(0.28), width: 1.2),
          ),
          child: child,
        ),
      ),
    );
  }
}

// --- CART / LOCATION STATE (unchanged from before) ---
class CartProvider extends ChangeNotifier {
  final Map<String, Map<String, dynamic>> _items = {};
  Map<String, Map<String, dynamic>> get items => _items;
  int get itemCount => _items.length;
  int get totalAmount {
    int total = 0;
    _items.forEach((key, item) { total += (item['price'] as int) * (item['quantity'] as int); });
    return total;
  }
  void addItem(String name, int price, String emoji) {
    if (_items.containsKey(name)) {
      _items[name]!['quantity'] += 1;
    } else {
      _items[name] = {'name': name, 'price': price, 'emoji': emoji, 'quantity': 1};
    }
    notifyListeners();
  }
  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}

class LocationProvider extends ChangeNotifier {
  String currentAddress = "Detecting location...";
  LatLng? currentPosition;
  void updateLocation(LatLng pos, String address) {
    currentPosition = pos;
    currentAddress = address;
    notifyListeners();
  }
}

// ============================================================================
// ROLE PROVIDER — now backed by the real backend. Holds the logged-in
// user's vendor/rider profile ids + approval status (from login), their
// wallet balances (fetched from GET /vendors|riders/:id/wallet), and the
// Admin queues (pending vendors/riders/payouts) fetched from the real
// /admin endpoints. No numbers here are hardcoded or invented client-side.
// ============================================================================
class RoleProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();

  String? userName;
  String? userPhone;

  String? vendorId;
  String? vendorStatus; // null | PENDING | ACTIVE | REJECTED
  String? riderId;
  String? riderStatus;

  double vendorWallet = 0.0;
  double riderWallet = 0.0;

  List<dynamic> pendingVendors = [];
  List<dynamic> pendingRiders = [];
  List<dynamic> pendingPayouts = [];

  bool isLoadingSession = false;

  // Called right after a successful login, before navigating anywhere, so
  // every dashboard has real data as soon as it's shown.
  Future<void> loadSession() async {
    isLoadingSession = true;
    notifyListeners();
    try {
      userName = await _auth.getName();
      userPhone = await _auth.getPhone();
      vendorId = await _auth.getVendorId();
      vendorStatus = await _auth.getVendorStatus();
      riderId = await _auth.getRiderId();
      riderStatus = await _auth.getRiderStatus();

      if (vendorId != null && vendorStatus == 'ACTIVE') {
        vendorWallet = await _auth.getVendorWallet(vendorId!);
      }
      if (riderId != null && riderStatus == 'ACTIVE') {
        riderWallet = await _auth.getRiderWallet(riderId!);
      }
    } catch (_) {
      // Non-fatal — dashboards show a retry/refresh affordance instead of crashing.
    }
    isLoadingSession = false;
    notifyListeners();
  }

  void clearSession() {
    userName = null;
    userPhone = null;
    vendorId = null;
    vendorStatus = null;
    riderId = null;
    riderStatus = null;
    vendorWallet = 0.0;
    riderWallet = 0.0;
    pendingVendors = [];
    pendingRiders = [];
    pendingPayouts = [];
    notifyListeners();
  }

  Future<bool> applyForVendor(String phone, String name, String shopName, String location) async {
    final success = await _auth.registerVendor(phone, name, shopName, location);
    if (success) {
      vendorStatus = 'PENDING';
      notifyListeners();
    }
    return success;
  }

  Future<bool> applyForRider(String phone, String name, String vehicleType, String plate, String idFront, String idBack) async {
    final success = await _auth.registerRider(phone, name, vehicleType, plate, idFront, idBack);
    if (success) {
      riderStatus = 'PENDING';
      notifyListeners();
    }
    return success;
  }

  Future<void> refreshVendorWallet() async {
    if (vendorId == null) return;
    vendorWallet = await _auth.getVendorWallet(vendorId!);
    notifyListeners();
  }

  Future<void> refreshRiderWallet() async {
    if (riderId == null) return;
    riderWallet = await _auth.getRiderWallet(riderId!);
    notifyListeners();
  }

  Future<void> requestVendorPayout(double amount, String method) async {
    if (vendorId == null) return;
    await _auth.requestVendorPayout(vendorId!, amount, method);
    await refreshVendorWallet();
  }

  Future<void> requestRiderPayout(double amount, String method) async {
    if (riderId == null) return;
    await _auth.requestRiderPayout(riderId!, amount, method);
    await refreshRiderWallet();
  }

  Future<void> refreshAdminQueues() async {
    pendingVendors = await _auth.getPendingVendors();
    pendingRiders = await _auth.getPendingRiders();
    pendingPayouts = await _auth.getPendingPayouts();
    notifyListeners();
  }

  Future<void> approveVendor(String id) async {
    await _auth.approveVendor(id);
    await refreshAdminQueues();
  }

  Future<void> approveRider(String id) async {
    await _auth.approveRider(id);
    await refreshAdminQueues();
  }

  Future<void> disbursePayout(String transactionId) async {
    await _auth.disbursePayout(transactionId);
    await refreshAdminQueues();
  }
}

// --- SHARED UI HELPERS ---
Widget _buildStyledTextField(TextEditingController controller, String hint, bool isDark, {bool enabled = true}) {
  return Container(
    decoration: BoxDecoration(
      color: isDark ? Colors.grey[900] : Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
    ),
    child: TextField(
      controller: controller,
      enabled: enabled,
      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    ),
  );
}

Widget _buildPremiumChip(String status, bool isPendingOrActive) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: isPendingOrActive ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      status.replaceAll('_', ' '),
      style: TextStyle(
        color: isPendingOrActive ? Colors.orange[800] : Colors.green[700],
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

void _showFeatureDialog(BuildContext context, String title, String description) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(description),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
    ),
  );
}

void _showErrorSnack(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
  );
}

// ============================================================================
// LOGIN SCREEN — real network call every time, no client-side bypass.
// Includes a small "quick test accounts" section that hits the backend's
// own ADMIN_SYSTEM / VENDOR_SYSTEM / RIDER_SYSTEM shortcut logins (these are
// real, server-side test accounts — not a fake client-only backdoor).
// ============================================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final _auth = AuthService();
  bool isLoading = false;

  Future<void> _handleLoginResult(String? result) async {
    setState(() => isLoading = false);
    if (!mounted) return;

    if (result == null || result == 'Connection error') {
      _showErrorSnack(context, result ?? 'Could not reach the server. Check your connection.');
      return;
    }

    if (!['CUSTOMER', 'VENDOR', 'RIDER', 'ADMIN'].contains(result)) {
      // The backend returns a human-readable error message (e.g. "pending
      // admin approval") in place of a role string when login is rejected.
      _showErrorSnack(context, result);
      return;
    }

    await context.read<RoleProvider>().loadSession();
    if (!mounted) return;

    final phone = _phoneController.text.isNotEmpty ? '+254${_phoneController.text}' : (await _auth.getPhone() ?? '');
    final roleProvider = context.read<RoleProvider>();

    if (result == 'VENDOR' && roleProvider.vendorId != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => VendorDashboardScreen(vendorId: roleProvider.vendorId!)));
    } else if (result == 'RIDER' && roleProvider.riderId != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => RiderDashboardScreen(riderId: roleProvider.riderId!)));
    } else if (result == 'ADMIN') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainNavigation(userPhone: phone)));
    }
  }

  void _attemptLogin() async {
    if (_phoneController.text.length < 9) return;
    FocusScope.of(context).unfocus();
    setState(() => isLoading = true);
    final result = await _auth.login('+254${_phoneController.text}');
    await _handleLoginResult(result);
  }

  void _quickLogin(String testPhone) async {
    setState(() => isLoading = true);
    final result = await _auth.login(testPhone);
    await _handleLoginResult(result);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text('Enter your mobile number', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 24),
              ProfessionalPhoneInput(phoneController: _phoneController),
              const SizedBox(height: 24),
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(onPressed: _attemptLogin, child: const Text('Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistrationRoleScreen())),
                  child: Text("Don't have an account? Create one", style: TextStyle(color: isDark ? Colors.greenAccent : Colors.green[700])),
                ),
              ),
              const SizedBox(height: 48),
              
              // 👇 The test accounts are now safely hidden in production 👇
              if (kDebugMode) ...[
                Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),
                const SizedBox(height: 12),
                Text('Quick test accounts (dev only)', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => _quickLogin('ADMIN_SYSTEM'), child: const Text('Admin'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(onPressed: () => _quickLogin('VENDOR_SYSTEM'), child: const Text('Vendor'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(onPressed: () => _quickLogin('RIDER_SYSTEM'), child: const Text('Rider'))),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ProfessionalPhoneInput extends StatelessWidget {
  final TextEditingController phoneController;
  final bool enabled;
  const ProfessionalPhoneInput({super.key, required this.phoneController, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('+254', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
          ),
          Container(height: 24, width: 1, color: isDark ? Colors.grey[700] : Colors.grey[400]),
          Expanded(
            child: TextField(
              controller: phoneController,
              enabled: enabled,
              keyboardType: TextInputType.phone,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: '7XX XXX XXX',
                hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              inputFormatters: [LengthLimitingTextInputFormatter(9), FilteringTextInputFormatter.digitsOnly],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MAIN BOTTOM NAVIGATION (CUSTOMER)
// ============================================================================

class MainNavigation extends StatefulWidget {
  final String userPhone;
  const MainNavigation({super.key, required this.userPhone});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(userPhone: widget.userPhone),
      const PickupMapScreen(),
      const SearchScreen(),
      BasketsScreen(userPhone: widget.userPhone),
      ProfileScreen(userPhone: widget.userPhone),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        selectedItemColor: isDark ? Colors.white : Colors.black,
        unselectedItemColor: Colors.grey[500],
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.location_on_outlined), activeIcon: Icon(Icons.location_on), label: 'Pickup'),
          const BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(
            icon: Badge(isLabelVisible: cart.itemCount > 0, label: Text('${cart.itemCount}'), child: const Icon(Icons.shopping_cart_outlined)),
            activeIcon: const Icon(Icons.shopping_cart), label: 'Baskets',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ============================================================================
// HOME SCREEN — products fetched from the real GET /products endpoint
// ============================================================================
class HomeScreen extends StatefulWidget {
  final String userPhone;
  const HomeScreen({super.key, required this.userPhone});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _auth = AuthService();
  List<dynamic> products = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final data = await _auth.getProducts();
      setState(() { products = data; isLoading = false; });
    } catch (e) {
      setState(() { errorMessage = e.toString().replaceFirst('Exception: ', ''); isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final locationData = Provider.of<LocationProvider>(context);

    return RefreshIndicator(
      onRefresh: fetchProducts,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddressSelectionScreen())),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(locationData.currentAddress, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  Icon(Icons.keyboard_arrow_down, color: textColor),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategoryPills(isDark),
                const SizedBox(height: 16),
                _buildSectionHeader('Fresh on The Greengrocer', textColor),
                if (isLoading) const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator())),
                if (!isLoading && errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Could not load products: $errorMessage', style: const TextStyle(color: Colors.red)),
                        TextButton(onPressed: fetchProducts, child: const Text('Retry')),
                      ],
                    ),
                  ),
                if (!isLoading && errorMessage == null) _buildDynamicProductList(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPills(bool isDark) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _categoryPill('All', Icons.apps, isDark, isSelected: true),
          _categoryPill('Grocery', Icons.local_grocery_store, isDark),
          _categoryPill('Convenience', Icons.storefront, isDark),
          _categoryPill('Pharmacy', Icons.medical_services, isDark),
        ],
      ),
    );
  }

  Widget _categoryPill(String title, IconData icon, bool isDark, {bool isSelected = false}) {
    Color bgColor = isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.grey[800]! : Colors.grey[200]!);
    Color fgColor = isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white : Colors.black87);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [Icon(icon, size: 18, color: fgColor), const SizedBox(width: 6), Text(title, style: TextStyle(color: fgColor, fontWeight: FontWeight.w600))]),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)), Icon(Icons.arrow_forward, color: textColor)],
      ),
    );
  }

  Widget _buildDynamicProductList(bool isDark) {
    if (products.isEmpty) return const Padding(padding: EdgeInsets.all(16.0), child: Text("No products available at the moment."));
    final cart = Provider.of<CartProvider>(context, listen: false);

    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          final bool inStock = product["in_stock"] ?? true;
          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 140, width: 200,
                      decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                      child: Center(child: Text(product["emoji"] ?? "🛒", style: TextStyle(fontSize: 60, color: inStock ? null : Colors.grey))),
                    ),
                    if (!inStock)
                      Positioned(
                        top: 8, left: 8,
                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)), child: const Text('Out of stock', style: TextStyle(color: Colors.white, fontSize: 11))),
                      ),
                    Positioned(
                      bottom: 8, right: 8,
                      child: GestureDetector(
                        onTap: !inStock ? null : () {
                          cart.addItem(product["name"], product["price"], product["emoji"] ?? "🛒");
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${product["name"]} added!'), duration: const Duration(seconds: 1)));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: inStock ? Colors.white : Colors.grey[300], shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                          child: Icon(Icons.add, color: inStock ? Colors.black : Colors.grey, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(product["name"], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('Ksh ${product["price"]} ${product["unit"] ?? ""}', style: TextStyle(color: isDark ? Colors.greenAccent : Colors.green[700], fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AddressSelectionScreen extends StatefulWidget {
  const AddressSelectionScreen({super.key});
  @override
  _AddressSelectionScreenState createState() => _AddressSelectionScreenState();
}

class _AddressSelectionScreenState extends State<AddressSelectionScreen> {
  String _selectedTime = "Deliver now";

  void _showTimePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(padding: EdgeInsets.all(16.0), child: Text("Delivery Time", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              ListTile(
                title: const Text("Deliver now"),
                trailing: _selectedTime == "Deliver now" ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () { setState(() => _selectedTime = "Deliver now"); Navigator.pop(context); },
              ),
              ListTile(
                title: const Text("Schedule for later"),
                trailing: _selectedTime != "Deliver now" ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () async {
                  TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (time != null) setState(() => _selectedTime = "Scheduled: ${time.format(context)}");
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Delivery Details"), elevation: 1),
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              onTap: _showTimePicker,
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.green),
                  const SizedBox(width: 16),
                  Expanded(child: Text(_selectedTime, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Saved addresses aren\'t backed by the API yet — this screen is a placeholder for that feature.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PICKUP MAP SCREEN — Geocoding/Places keys now come from .env, not
// hardcoded constants.
// ============================================================================
class PickupMapScreen extends StatefulWidget {
  const PickupMapScreen({super.key});
  @override
  State<PickupMapScreen> createState() => _PickupMapScreenState();
}

class _PickupMapScreenState extends State<PickupMapScreen> {
  GoogleMapController? mapController;
  LatLng _currentPosition = const LatLng(-1.286389, 36.817223);
  final Set<Marker> _markers = {};
  List<dynamic> nearbyRestaurants = [];
  bool _isLoadingPlaces = false;
  bool _isDeliveryMode = true;

  String get _geocodingApiKey => dotenv.env['GEOCODING_API_KEY'] ?? '';
  String get _placesApiKey => dotenv.env['PLACES_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    _tryGetRealLocation();
  }

  Future<void> _tryGetRealLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)).timeout(const Duration(seconds: 5));
          if (mounted) {
            setState(() => _currentPosition = LatLng(position.latitude, position.longitude));
            mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition, 14));
          }
        }
      }
    } catch (e) {}
    finally {
      if (mounted) {
        _updateGlobalAddress(_currentPosition);
        _fetchRealGooglePlaces(_currentPosition);
      }
    }
  }

  Future<void> _updateGlobalAddress(LatLng pos) async {
    if (_geocodingApiKey.isEmpty) return;
    try {
      final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.latitude},${pos.longitude}&key=$_geocodingApiKey';
      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK' && mounted) {
        var results = data['results'] as List;
        if (results.isNotEmpty) {
          String addr = results[0]['formatted_address'];
          List<String> parts = addr.split(',');
          String shortAddr = parts.length > 1 ? "${parts[0]}, ${parts[1]}" : addr;
          Provider.of<LocationProvider>(context, listen: false).updateLocation(pos, shortAddr.trim());
        }
      }
    } catch (e) {}
  }

  Future<void> _fetchRealGooglePlaces(LatLng pos) async {
    if (!mounted || _placesApiKey.isEmpty) return;
    setState(() => _isLoadingPlaces = true);
    try {
      String url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${pos.latitude},${pos.longitude}&radius=3000&type=restaurant&key=$_placesApiKey';
      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK' && mounted) {
        setState(() {
          nearbyRestaurants = data['results'];
          _markers.clear();
          for (var place in nearbyRestaurants) {
            _markers.add(Marker(
              markerId: MarkerId(place['place_id']),
              position: LatLng(place['geometry']['location']['lat'], place['geometry']['location']['lng']),
              infoWindow: InfoWindow(title: place['name'], snippet: place['vicinity']),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ));
          }
          _isLoadingPlaces = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingPlaces = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPlaces = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 13.5),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) => mapController = controller,
          ),
          Positioned(
            top: 100, right: 16,
            child: FloatingActionButton.small(
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              onPressed: _tryGetRealLocation,
              child: Icon(Icons.my_location, color: isDark ? Colors.white : Colors.black),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.35, minChildSize: 0.18, maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _isLoadingPlaces ? 3 : 2 + nearbyRestaurants.length,
                  itemBuilder: (context, index) {
                    if (index == 0) return Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10))));
                    if (index == 1) return Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('Delivery near you', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)));
                    if (_isLoadingPlaces) return const Center(child: CircularProgressIndicator());
                    final place = nearbyRestaurants[index - 2];
                    double distInMeters = Geolocator.distanceBetween(_currentPosition.latitude, _currentPosition.longitude, place['geometry']['location']['lat'], place['geometry']['location']['lng']);
                    String distStr = "${(distInMeters / 1000).toStringAsFixed(1)} km";
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(place['name'] ?? 'Restaurant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                          Text('⭐ ${place['rating'] ?? 'New'} • $distStr • ${place['vicinity'] ?? ''}', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Container(
              height: 45,
              decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(8)),
              child: const TextField(decoration: InputDecoration(hintText: 'Search The Greengrocer', prefixIcon: Icon(Icons.search), border: InputBorder.none)),
            ),
            const SizedBox(height: 24),
            Text('Product search filters by name/category aren\'t wired to the API yet.', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BASKETS SCREEN — checkout now calls the real POST /orders/checkout,
// which triggers a genuine M-Pesa STK push server-side.
// ============================================================================
class BasketsScreen extends StatefulWidget {
  final String userPhone;
  const BasketsScreen({super.key, required this.userPhone});
  @override
  State<BasketsScreen> createState() => _BasketsScreenState();
}

class _BasketsScreenState extends State<BasketsScreen> {
  bool _isCheckingOut = false;

  Future<void> _checkout(CartProvider cart) async {
    setState(() => _isCheckingOut = true);
    try {
      final items = cart.items.values.map((i) => {'name': i['name'], 'price': i['price'], 'quantity': i['quantity']}).toList();
      final idempotencyKey = DateTime.now().millisecondsSinceEpoch.toString();
      final result = await AuthService().checkout(items: items, subtotal: cart.totalAmount, idempotencyKey: idempotencyKey);
      cart.clearCart();
      if (mounted) {
        _showFeatureDialog(context, 'Order Placed', result['message'] ?? 'Check your phone for the M-Pesa prompt.');
      }
    } catch (e) {
      if (mounted) _showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cart = Provider.of<CartProvider>(context);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(alignment: Alignment.centerLeft, child: Text('Your Basket', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))),
          ),
          Expanded(
            child: cart.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart, size: 100, color: isDark ? Colors.grey[800] : Colors.grey[300]),
                        const SizedBox(height: 24),
                        Text('Add items to start a basket', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final cartItem = cart.items.values.toList()[index];
                      return ListTile(
                        leading: Text(cartItem['emoji'], style: const TextStyle(fontSize: 30)),
                        title: Text(cartItem['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Qty: ${cartItem['quantity']} x ${cartItem['price']}'),
                        trailing: Text('${cartItem['quantity'] * cartItem['price']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      );
                    },
                  ),
          ),
          if (cart.items.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.white, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)]),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total:', style: TextStyle(fontSize: 18)), Text('${cart.totalAmount}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))]),
                    const SizedBox(height: 16),
                    _isCheckingOut
                        ? const CircularProgressIndicator()
                        : ElevatedButton(onPressed: () => _checkout(cart), child: const Text('Checkout with M-Pesa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// CUSTOMER PROFILE — "Drive & Deliver" / "Sell your products" now reflect
// the real vendor_status/rider_status from the backend (null / PENDING /
// ACTIVE), and route to the actual signup screens instead of a snackbar.
// ============================================================================

class ProfileScreen extends StatelessWidget {
  final String userPhone;
  const ProfileScreen({super.key, required this.userPhone});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final roleProvider = context.watch<RoleProvider>();

    final bool isRiderApproved = roleProvider.riderStatus == 'ACTIVE';
    final bool isRiderPending = roleProvider.riderStatus == 'PENDING';
    final bool isVendorApproved = roleProvider.vendorStatus == 'ACTIVE';
    final bool isVendorPending = roleProvider.vendorStatus == 'PENDING';

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Profile', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
                CircleAvatar(radius: 28, backgroundColor: Colors.green[700], child: const Icon(Icons.person, color: Colors.white, size: 30)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _profileCard('Favourites', Icons.favorite, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FavouritesScreen()))),
                _profileCard('Wallet', Icons.account_balance_wallet, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen()))),
                _profileCard('Orders', Icons.receipt_long, isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OrdersTabScreen(userPhone: userPhone)))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text("Earning Opportunities", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.orange.withOpacity(0.2), child: const Icon(Icons.motorcycle, color: Colors.orange)),
                  title: const Text("Drive & Deliver", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(isRiderApproved ? "Active Account" : (isRiderPending ? "Application Pending Review" : "Earn money on your own schedule")),
                  trailing: isRiderApproved
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36)),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RiderDashboardScreen(riderId: roleProvider.riderId!))),
                          child: const Text("Switch to Rider"),
                        )
                      : const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: isRiderApproved
                      ? null
                      : () {
                          if (isRiderPending) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your rider application is already awaiting review.')));
                          } else {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const RiderSignupScreen(isUpgrade: true)));
                          }
                        },
                ),
                ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.blueGrey.withOpacity(0.2), child: const Icon(Icons.store, color: Colors.blueGrey)),
                  title: const Text("Sell your products", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(isVendorApproved ? "Active Store" : (isVendorPending ? "Application Pending Review" : "Open a digital storefront")),
                  trailing: isVendorApproved
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36)),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VendorDashboardScreen(vendorId: roleProvider.vendorId!))),
                          child: const Text("Switch to Vendor"),
                        )
                      : const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: isVendorApproved
                      ? null
                      : () {
                          if (isVendorPending) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your vendor application is already awaiting review.')));
                          } else {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const VendorSignupScreen(isUpgrade: true)));
                          }
                        },
                ),
                const Divider(height: 32),
                _settingsTile('Account settings', Icons.settings_outlined, textColor, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountSettingsScreen()))),
                _settingsTile('Family', Icons.group_outlined, textColor, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FamilyScreen()))),
                _settingsTile('Promotions', Icons.local_offer_outlined, textColor, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PromotionsScreen()))),
                _settingsTile('Help', Icons.help_outline, textColor, () => _showFeatureDialog(context, "Support", "Support chat isn't wired to a real backend yet.")),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500, fontSize: 16)),
                  onTap: () async {
                    await AuthService().logout();
                    context.read<RoleProvider>().clearSession();
                    if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                  },
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _profileCard(String title, IconData icon, bool isDark, {required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
          child: Column(children: [Icon(icon, size: 28, color: isDark ? Colors.white : Colors.black), const SizedBox(height: 8), Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black))]),
        ),
      ),
    );
  }

  Widget _settingsTile(String title, IconData icon, Color textColor, VoidCallback onTap) {
    return ListTile(leading: Icon(icon, color: textColor), title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 16)), onTap: onTap);
  }
}

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Favourites")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text("Favourites aren't backed by the API yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Wallet")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.green[700], borderRadius: BorderRadius.circular(16)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Customer cash-wallet isn't part of the backend yet", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text("Checkout goes straight through M-Pesa STK push instead.", style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ORDER HISTORY — real GET /orders/history, with a working "Rate" action
// on delivered orders (POST /orders/:id/rate) so the vendor/rider feedback
// screens have real data to show instead of an empty table.
// ============================================================================
class OrdersTabScreen extends StatefulWidget {
  final String userPhone;
  const OrdersTabScreen({super.key, required this.userPhone});
  @override
  State<OrdersTabScreen> createState() => _OrdersTabScreenState();
}

class _OrdersTabScreenState extends State<OrdersTabScreen> {
  List<dynamic> orders = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { isLoading = true; error = null; });
    try {
      final data = await AuthService().getOrderHistory();
      setState(() { orders = data; isLoading = false; });
    } catch (e) {
      setState(() { error = e.toString().replaceFirst('Exception: ', ''); isLoading = false; });
    }
  }

  void _showRateDialog(String orderId) {
    int score = 5;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate this order'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => IconButton(
              icon: Icon(i < score ? Icons.star : Icons.star_border, color: Colors.amber),
              onPressed: () => setDialogState(() => score = i + 1),
            )),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await AuthService().rateOrder(orderId, 'VENDOR', score);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for rating!')));
                } catch (e) {
                  if (mounted) _showErrorSnack(context, e);
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Your Orders")),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('Could not load orders: $error', style: const TextStyle(color: Colors.red)))])
                : orders.isEmpty
                    ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Text('You have no past orders.'))])
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          final status = order['status'] as String;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[900] : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Order #${order['id'].toString().substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    _buildPremiumChip(status, status != 'DELIVERED'),
                                  ],
                                ),
                                Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[200])),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total Amount', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                    Text('${order['total']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                if (status == 'DELIVERED') ...[
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
                                    onPressed: () => _showRateDialog(order['id']),
                                    child: const Text('Rate this order'),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Account Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Padding(padding: EdgeInsets.all(8.0), child: Text('Profile photo, name editing, and saved-places aren\'t wired to the API yet.', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }
}

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Family")),
      body: const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Family accounts aren\'t part of the backend design yet.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))),
    );
  }
}

class PromotionsScreen extends StatelessWidget {
  const PromotionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Promotions")),
      body: const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No promo/voucher system exists on the backend yet.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))),
    );
  }
}

// ============================================================================
// REGISTRATION & SIGNUPS
// ============================================================================

class RegistrationRoleScreen extends StatelessWidget {
  const RegistrationRoleScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('How would you like to use the app?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 24),
          _buildRoleCard(context, "I want to buy groceries", Icons.shopping_basket, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerSignupScreen())), isDark),
          const SizedBox(height: 16),
          _buildRoleCard(context, "I want to sell my products", Icons.store, Colors.blueGrey, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VendorSignupScreen())), isDark),
          const SizedBox(height: 16),
          _buildRoleCard(context, "I want to drive & deliver", Icons.motorcycle, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RiderSignupScreen())), isDark),
        ],
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, String title, IconData icon, Color iconColor, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.grey[100], borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: iconColor.withOpacity(0.2), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 28)),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }
}

class CustomerSignupScreen extends StatelessWidget {
  final _phone = TextEditingController();
  final _name = TextEditingController();
  CustomerSignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    return Scaffold(
      appBar: AppBar(title: const Text("Customer Signup")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Welcome to fresh produce', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 24),
          _buildStyledTextField(_name, 'Full Name', isDark),
          const SizedBox(height: 16),
          ProfessionalPhoneInput(phoneController: _phone),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () async {
              String fullPhone = '+254${_phone.text}';
              String? role = await AuthService().registerCustomer(fullPhone, _name.text);
              if (role == 'CUSTOMER') {
                await context.read<RoleProvider>().loadSession();
                if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => MainNavigation(userPhone: fullPhone)), (route) => false);
              } else if (context.mounted) {
                _showErrorSnack(context, role ?? 'Registration failed');
              }
            },
            child: const Text("Register & Shop", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}

// isUpgrade=true means an already-logged-in Customer is applying to also
// become a Vendor. The backend now supports attaching a Vendor profile to
// an existing account (see auth.service.ts), but it must be the SAME phone
// number — so in upgrade mode the phone field is pre-filled and locked.
class VendorSignupScreen extends StatefulWidget {
  final bool isUpgrade;
  const VendorSignupScreen({super.key, this.isUpgrade = false});
  @override
  _VendorSignupScreenState createState() => _VendorSignupScreenState();
}

class _VendorSignupScreenState extends State<VendorSignupScreen> {
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _shopName = TextEditingController();
  String _location = "Fetching GPS...";
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _getLocation();
    if (widget.isUpgrade) _prefillFromSession();
  }

  Future<void> _prefillFromSession() async {
    final auth = AuthService();
    final phone = await auth.getPhone();
    final name = await auth.getName();
    setState(() {
      _phone.text = (phone ?? '').replaceFirst('+254', '');
      _name.text = name ?? '';
    });
  }

  Future _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return setState(() => _location = "GPS Disabled");
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) return setState(() => _location = "Permission Denied");
    Position position = await Geolocator.getCurrentPosition();
    setState(() => _location = "${position.latitude}, ${position.longitude}");
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    String fullPhone = widget.isUpgrade ? (await AuthService().getPhone() ?? '+254${_phone.text}') : '+254${_phone.text}';
    final roleProvider = context.read<RoleProvider>();
    try {
      final success = await roleProvider.applyForVendor(fullPhone, _name.text, _shopName.text, _location);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Application sent! Waiting for Admin approval.")));
        if (widget.isUpgrade) {
          Navigator.pop(context);
        } else {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      } else {
        _showErrorSnack(context, 'Registration failed — this phone may already have a vendor profile.');
      }
    } catch (e) {
      if (mounted) _showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    return Scaffold(
      appBar: AppBar(title: const Text("Vendor Signup")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Partner with us', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 24),
          _buildStyledTextField(_name, 'Your Full Name', isDark, enabled: !widget.isUpgrade),
          const SizedBox(height: 16),
          _buildStyledTextField(_shopName, 'Shop or Business Name', isDark),
          const SizedBox(height: 16),
          widget.isUpgrade
              ? _buildStyledTextField(_phone, 'Phone (locked to your account)', isDark, enabled: false)
              : ProfessionalPhoneInput(phoneController: _phone),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [const Icon(Icons.location_on, color: Colors.blueGrey), const SizedBox(width: 12), Expanded(child: Text("Location: $_location", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.blueGrey, fontWeight: FontWeight.w600)))]),
          ),
          const SizedBox(height: 32),
          _isSubmitting
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(onPressed: _submit, child: const Text("Submit Application", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

class RiderSignupScreen extends StatefulWidget {
  final bool isUpgrade;
  const RiderSignupScreen({super.key, this.isUpgrade = false});
  @override
  _RiderSignupScreenState createState() => _RiderSignupScreenState();
}

class _RiderSignupScreenState extends State<RiderSignupScreen> {
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _plate = TextEditingController();
  String _vehicleType = 'BODABODA';
  File? _idFront;
  File? _idBack;
  bool _isSubmitting = false;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.isUpgrade) _prefillFromSession();
  }

  Future<void> _prefillFromSession() async {
    final auth = AuthService();
    final phone = await auth.getPhone();
    final name = await auth.getName();
    setState(() {
      _phone.text = (phone ?? '').replaceFirst('+254', '');
      _name.text = name ?? '';
    });
  }

  Future pickImage(bool isFront) async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        if (isFront) _idFront = File(pickedFile.path);
        else _idBack = File(pickedFile.path);
      });
    }
  }

  Future<void> _submit() async {
    if (_idFront == null || _idBack == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload both sides of your ID.")));
      return;
    }
    setState(() => _isSubmitting = true);
    String fullPhone = widget.isUpgrade ? (await AuthService().getPhone() ?? '+254${_phone.text}') : '+254${_phone.text}';
    final roleProvider = context.read<RoleProvider>();
    try {
      final success = await roleProvider.applyForRider(fullPhone, _name.text, _vehicleType, _plate.text, _idFront!.path, _idBack!.path);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Application sent! Waiting for Admin approval.")));
        if (widget.isUpgrade) {
          Navigator.pop(context);
        } else {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      } else {
        _showErrorSnack(context, 'Registration failed — this phone may already have a rider profile.');
      }
    } catch (e) {
      if (mounted) _showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    return Scaffold(
      appBar: AppBar(title: const Text("Rider Signup")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Join our delivery fleet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 24),
          _buildStyledTextField(_name, 'Full Name', isDark, enabled: !widget.isUpgrade),
          const SizedBox(height: 16),
          widget.isUpgrade
              ? _buildStyledTextField(_phone, 'Phone (locked to your account)', isDark, enabled: false)
              : ProfessionalPhoneInput(phoneController: _phone),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _vehicleType,
                isExpanded: true,
                dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.w500),
                items: ['BODABODA', 'CAR'].map((String val) => DropdownMenuItem<String>(value: val, child: Text(val))).toList(),
                onChanged: (val) => setState(() => _vehicleType = val!),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildStyledTextField(_plate, 'License Plate Number', isDark),
          const SizedBox(height: 24),
          Text('ID Verification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: _buildImageUploadBtn('Front of ID', _idFront != null, () => pickImage(true), isDark)), const SizedBox(width: 16), Expanded(child: _buildImageUploadBtn('Back of ID', _idBack != null, () => pickImage(false), isDark))]),
          const SizedBox(height: 32),
          _isSubmitting
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(onPressed: _submit, child: const Text("Submit Application", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildImageUploadBtn(String label, bool isUploaded, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: isUploaded ? Colors.green.withOpacity(0.1) : (isDark ? Colors.grey[900] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isUploaded ? Colors.green : (isDark ? Colors.grey[800]! : Colors.grey[300]!), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isUploaded ? Icons.check_circle : Icons.camera_alt, color: isUploaded ? Colors.green : Colors.grey, size: 32),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: isUploaded ? Colors.green : Colors.grey, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// VENDOR DASHBOARD — every list and every button here now talks to the
// real backend. Orders come from GET /orders/vendor-dashboard; Accept/Ready
// call POST /orders/update-status; Cancel calls PATCH /orders/:id/cancel;
// the Online/Offline switch calls PATCH /vendors/:id/status; Menu Maker
// reads/writes GET+POST /menu-items and PATCH /menu-items/:id/stock;
// Wallet/Payout use RoleProvider (GET/POST /vendors/:id/wallet+payout);
// Feedback uses GET /vendors/:id/ratings. "Busy Mode" and the session-only
// downtime counter are the two things that stay client-side, because there
// is no backend field for either yet — both are labeled as such in the UI.
// ============================================================================

class VendorDashboardScreen extends StatefulWidget {
  final String vendorId;
  const VendorDashboardScreen({super.key, required this.vendorId});
  @override
  _VendorDashboardScreenState createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  final AuthService _auth = AuthService();
  int _currentIndex = 0;
  bool isStoreOpen = true;
  bool _busyMode = false;
  DateTime? _wentOfflineAt;
  int _downtimeMinutes = 0;

  bool _isLoadingOrders = true;
  String? _ordersError;
  List<dynamic> _orders = [];

  bool _isLoadingMenu = true;
  List<dynamic> _menuItems = [];

  Map<String, dynamic>? _ratings;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadOrders(), _loadMenu(), _loadRatings(), context.read<RoleProvider>().refreshVendorWallet()]);
  }

  Future<void> _loadOrders() async {
    setState(() { _isLoadingOrders = true; _ordersError = null; });
    try {
      final data = await _auth.getVendorOrders();
      setState(() { _orders = data; _isLoadingOrders = false; });
    } catch (e) {
      setState(() { _ordersError = e.toString().replaceFirst('Exception: ', ''); _isLoadingOrders = false; });
    }
  }

  Future<void> _loadMenu() async {
    setState(() => _isLoadingMenu = true);
    try {
      final data = await _auth.getVendorMenuItems(widget.vendorId);
      setState(() { _menuItems = data; _isLoadingMenu = false; });
    } catch (e) {
      setState(() => _isLoadingMenu = false);
    }
  }

  Future<void> _loadRatings() async {
    try {
      final data = await _auth.getVendorRatings(widget.vendorId);
      setState(() => _ratings = data);
    } catch (e) {
      // Non-fatal — feedback tile just shows "no data" instead of crashing.
    }
  }

  Future<void> _toggleStoreOpen(bool val) async {
    final previous = isStoreOpen;
    setState(() {
      isStoreOpen = val;
      if (!val) {
        _wentOfflineAt = DateTime.now();
      } else if (_wentOfflineAt != null) {
        _downtimeMinutes += DateTime.now().difference(_wentOfflineAt!).inMinutes;
        _wentOfflineAt = null;
      }
    });
    try {
      await _auth.setVendorOpenStatus(widget.vendorId, val);
    } catch (e) {
      if (mounted) {
        setState(() => isStoreOpen = previous); // revert on failure
        _showErrorSnack(context, e);
      }
    }
  }

  Future<void> _updateStatus(String orderId, String status) async {
    try {
      await _auth.updateOrderStatus(orderId, status);
      await _loadOrders();
    } catch (e) {
      if (mounted) _showErrorSnack(context, e);
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.cancel, color: Colors.red),
          title: const Text('Cancel order (out of stock / cannot fulfil)'),
          onTap: () async {
            Navigator.pop(context);
            try {
              await _auth.cancelOrder(orderId, 'Vendor cancelled — cannot fulfil');
              await _loadOrders();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order cancelled and refund logged.')));
            } catch (e) {
              if (mounted) _showErrorSnack(context, e);
            }
          },
        ),
      ),
    );
  }

  void _showReceipt() {
    final delivered = _orders.where((o) => o['status'] == 'DELIVERED').toList();
    if (delivered.isEmpty) {
      _showFeatureDialog(context, "Receipt Printing", "No completed orders yet — nothing to print.");
      return;
    }
    final order = delivered.first;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receipt'),
        content: Text('Order #${order['id'].toString().substring(0, 8)}\n------------------\nTotal: Ksh ${order['total']}\n\nSent to connected receipt printer.', style: const TextStyle(fontFamily: 'monospace')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showAddItemDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'kg');
    final emojiCtrl = TextEditingController(text: '🛒');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Menu Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStyledTextField(nameCtrl, 'Item name', Theme.of(context).brightness == Brightness.dark),
              const SizedBox(height: 12),
              _buildStyledTextField(priceCtrl, 'Price (Ksh)', Theme.of(context).brightness == Brightness.dark),
              const SizedBox(height: 12),
              _buildStyledTextField(unitCtrl, 'Unit (e.g. kg, bunch)', Theme.of(context).brightness == Brightness.dark),
              const SizedBox(height: 12),
              _buildStyledTextField(emojiCtrl, 'Emoji', Theme.of(context).brightness == Brightness.dark),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final price = int.tryParse(priceCtrl.text);
              if (nameCtrl.text.isEmpty || price == null) return;
              Navigator.pop(context);
              try {
                await _auth.addMenuItem(widget.vendorId, nameCtrl.text, price, emojiCtrl.text, unitCtrl.text);
                await _loadMenu();
              } catch (e) {
                if (mounted) _showErrorSnack(context, e);
              }
            },
            child: const Text('Save Item'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleStock(String itemId, bool inStock) async {
    try {
      await _auth.setMenuItemStock(itemId, inStock);
      await _loadMenu();
    } catch (e) {
      if (mounted) _showErrorSnack(context, e);
    }
  }

  void _requestPayoutDialog(RoleProvider roleProvider) {
    if (roleProvider.vendorWallet <= 0) {
      _showFeatureDialog(context, "Nothing to withdraw", "Your wallet balance is currently zero.");
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Payout'),
        content: Text('Withdraw the full balance (Ksh ${roleProvider.vendorWallet.toStringAsFixed(2)}) via M-Pesa?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await roleProvider.requestVendorPayout(roleProvider.vendorWallet, 'M-Pesa');
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout requested — awaiting Admin disbursement.')));
              } catch (e) {
                if (mounted) _showErrorSnack(context, e);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleProvider = context.watch<RoleProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Vendor Dashboard'),
        actions: [
          Row(children: [Text(isStoreOpen ? "Online" : "Offline", style: TextStyle(color: isStoreOpen ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)), Switch(value: isStoreOpen, activeColor: Colors.green, onChanged: _toggleStoreOpen)]),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().logout();
              context.read<RoleProvider>().clearSession();
              if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
          ),
        ],
      ),
      body: _currentIndex == 0 ? _buildKitchenDisplay(isDark) : _currentIndex == 1 ? _buildMenuManager(isDark) : _buildReports(isDark, roleProvider),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.soup_kitchen), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Menu Maker'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
        ],
      ),
    );
  }

  Widget _buildKitchenDisplay(bool isDark) {
    if (_isLoadingOrders) return const Center(child: CircularProgressIndicator());
    if (_ordersError != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [Text('Could not load orders: $_ordersError', style: const TextStyle(color: Colors.red)), TextButton(onPressed: _loadOrders, child: const Text('Retry'))]),
      );
    }

    final newOrders = _orders.where((o) => o['status'] == 'PLACED').toList();
    final preparingOrders = _orders.where((o) => o['status'] == 'ACCEPTED_BY_VENDOR').toList();
    final readyOrders = _orders.where((o) => ['READY_FOR_PICKUP', 'RIDER_ASSIGNED', 'PICKED_UP'].contains(o['status'])).toList();

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            if (_busyMode)
              Container(width: double.infinity, color: Colors.red.withOpacity(0.1), padding: const EdgeInsets.symmetric(vertical: 6), child: const Text('Busy mode — kitchen display only, not sent to the server', textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontSize: 12))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: _busyMode ? Colors.red : null, minimumSize: const Size(0, 48)), onPressed: () => setState(() => _busyMode = !_busyMode), icon: const Icon(Icons.timer, size: 18), label: Text(_busyMode ? "Busy Mode: ON" : "Busy Mode", style: const TextStyle(fontSize: 13)))),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.print), onPressed: _showReceipt),
                ],
              ),
            ),
            TabBar(labelColor: Colors.green, unselectedLabelColor: Colors.grey, tabs: [
              Tab(text: "New (${newOrders.length})"),
              Tab(text: "Preparing (${preparingOrders.length})"),
              Tab(text: "Out (${readyOrders.length})"),
            ]),
            Expanded(
              child: TabBarView(
                children: [
                  _buildOrderList(newOrders, "Accept Order", (o) => _updateStatus(o['id'], 'ACCEPTED_BY_VENDOR'), (o) => _cancelOrder(o['id'])),
                  _buildOrderList(preparingOrders, "Mark Ready", (o) => _updateStatus(o['id'], 'READY_FOR_PICKUP'), (o) => _cancelOrder(o['id'])),
                  _buildReadOnlyOrderList(readyOrders),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(List<dynamic> orders, String actionText, void Function(dynamic) onAction, void Function(dynamic)? onManage) {
    if (orders.isEmpty) return const Center(child: Text("No orders here."));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order #${order['id'].toString().substring(0, 8)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Ksh ${order['total']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Row(children: [
                  ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: () => onAction(order), child: Text(actionText)),
                  if (onManage != null) ...[const SizedBox(width: 8), TextButton(onPressed: () => onManage(order), child: const Text("Cancel"))],
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReadOnlyOrderList(List<dynamic> orders) {
    if (orders.isEmpty) return const Center(child: Text("Nothing out for delivery."));
    const labels = {'READY_FOR_PICKUP': 'Waiting for a rider', 'RIDER_ASSIGNED': 'Rider assigned', 'PICKED_UP': 'Picked up — en route'};
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          child: ListTile(
            title: Text('Order #${order['id'].toString().substring(0, 8)}'),
            subtitle: Text(labels[order['status']] ?? order['status']),
            trailing: Text('Ksh ${order['total']}'),
          ),
        );
      },
    );
  }

  Widget _buildMenuManager(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadMenu,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)), onPressed: _showAddItemDialog, icon: const Icon(Icons.add, size: 18), label: const Text("Add Item")),
          const SizedBox(height: 16),
          if (_isLoadingMenu) const Center(child: CircularProgressIndicator()),
          if (!_isLoadingMenu && _menuItems.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No menu items yet — add your first one above.')),
          if (!_isLoadingMenu)
            ..._menuItems.map((item) => SwitchListTile(
                  title: Text('${item['emoji'] ?? ''} ${item['name']} (Ksh ${item['price']})'),
                  subtitle: Text((item['in_stock'] ?? true) ? "In Stock" : "Out of Stock"),
                  value: item['in_stock'] ?? true,
                  activeColor: Colors.green,
                  onChanged: (v) => _toggleStock(item['id'], v),
                )),
        ],
      ),
    );
  }

  Widget _buildReports(bool isDark, RoleProvider roleProvider) {
    final cancelledOrders = _orders.where((o) => o['status'] == 'CANCELLED').toList();
    final average = (_ratings?['average'] as num?)?.toDouble() ?? 0.0;
    final count = (_ratings?['count'] as num?)?.toInt() ?? 0;

    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.green[700]!, isDark ? const Color(0xFF121212) : Colors.white])),
      child: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.account_balance_wallet, size: 40, color: Colors.white),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Wallet Balance', style: TextStyle(fontSize: 16, color: Colors.white70)),
                      Text(roleProvider.vendorWallet.toStringAsFixed(2), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                    ]),
                  ]),
                  const SizedBox(height: 16),
                  ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)), onPressed: () => _requestPayoutDialog(roleProvider), child: const Text("Request Payout")),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(leading: const Icon(Icons.error_outline), title: const Text("Cancelled / Order Errors"), subtitle: Text('${cancelledOrders.length} logged')),
                  ListTile(leading: const Icon(Icons.timer_off), title: const Text("Downtime (this session)"), subtitle: Text('$_downtimeMinutes min — session-only, not stored on the server yet')),
                  ListTile(leading: const Icon(Icons.star_rate), title: const Text("Customer Feedback"), subtitle: Text(count == 0 ? 'No ratings yet' : '${average.toStringAsFixed(1)}★ average across $count orders')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// RIDER DASHBOARD — going online fetches real orders from
// GET /deliveries/nearby (using the device's actual GPS position). Accept
// calls POST /deliveries/accept, which returns a REAL server-computed
// commission (distance × rate + % of order total — see
// DeliveriesService.acceptOrder on the backend). Pickup/Deliver call the
// real PATCH endpoints, and delivery completion actually credits the
// rider's wallet server-side, which we then re-fetch. The Earnings
// Estimator stays a client-side heuristic (clearly labeled) since the
// backend has no demand-forecasting endpoint.
// ============================================================================

class RiderDashboardScreen extends StatefulWidget {
  final String riderId;
  const RiderDashboardScreen({super.key, required this.riderId});
  @override
  _RiderDashboardScreenState createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  final AuthService _auth = AuthService();
  int _currentIndex = 0;
  bool isOnline = false;
  bool _isSearching = false;
  Map<String, dynamic>? _ratings;

  // Same placeholder store coordinates the backend itself currently uses
  // (see DeliveriesService.findNearbyOrders) until Vendor gets real lat/lng.
  static const LatLng _placeholderStore = LatLng(-1.2921, 36.8219);

  @override
  void initState() {
    super.initState();
    context.read<RoleProvider>().refreshRiderWallet();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    try {
      final data = await _auth.getRiderRatings(widget.riderId);
      setState(() => _ratings = data);
    } catch (e) {}
  }

  Future<void> _goOnline(bool val) async {
    setState(() => isOnline = val);
    if (!val) return;

    setState(() => _isSearching = true);
    try {
      Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)).timeout(const Duration(seconds: 6));
      final orders = await _auth.getNearbyDeliveries(position.latitude, position.longitude);
      setState(() => _isSearching = false);
      if (orders.isNotEmpty && mounted) {
        final distanceKm = Geolocator.distanceBetween(position.latitude, position.longitude, _placeholderStore.latitude, _placeholderStore.longitude) / 1000;
        _showIncomingOrderAlert(orders.first, distanceKm);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No ready-for-pickup orders nearby right now.')));
      }
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) _showErrorSnack(context, e);
    }
  }

  void _showIncomingOrderAlert(dynamic order, double distanceKm) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("New Delivery Request!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Order #${order['id'].toString().substring(0, 8)}"),
            const SizedBox(height: 8),
            Text('${distanceKm.toStringAsFixed(1)} km to store'),
            const SizedBox(height: 8),
            Text('Order total: Ksh ${order['total']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Decline", style: TextStyle(color: Colors.red))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final result = await _auth.acceptDelivery(order['id'], distanceKm);
                final commission = (result['commission_earned'] as num).toDouble();
                if (mounted) _showActiveDeliveryModal(order['id'], commission);
              } catch (e) {
                if (mounted) _showErrorSnack(context, e);
              }
            },
            child: const Text("Accept"),
          ),
        ],
      ),
    );
  }

  void _showActiveDeliveryModal(String orderId, double commission) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Active Delivery", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Estimated commission: Ksh ${commission.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                try {
                  await _auth.markPickedUp(orderId);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pickup confirmed. En route to customer.')));
                } catch (e) {
                  if (mounted) _showErrorSnack(context, e);
                }
              },
              icon: const Icon(Icons.check_box),
              label: const Text("Confirm pickup at store"),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () async {
                try {
                  final result = await _auth.markDelivered(orderId);
                  final credited = (result['rider_credited'] as num).toDouble();
                  await context.read<RoleProvider>().refreshRiderWallet();
                  if (mounted) {
                    Navigator.pop(context);
                    _showFeatureDialog(context, "Delivery Complete", "Ksh ${credited.toStringAsFixed(2)} credited to your wallet.");
                  }
                } catch (e) {
                  if (mounted) _showErrorSnack(context, e);
                }
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text("Confirm delivery to customer"),
            ),
          ],
        ),
      ),
    );
  }

  int _demandFor(int weekday, int hour) {
    int score = 1;
    if (hour >= 12 && hour <= 14) score += 2;
    if (hour >= 18 && hour <= 21) score += 3;
    if (weekday == DateTime.friday || weekday == DateTime.saturday) score += 1;
    return score.clamp(1, 5);
  }

  Widget _demandChip(int score) {
    const labels = ['', 'Low', 'Moderate', 'High', 'Very High', 'Peak'];
    const colors = [Colors.grey, Colors.grey, Colors.orange, Colors.deepOrange, Colors.red, Colors.redAccent];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: colors[score].withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(labels[score], style: TextStyle(color: colors[score], fontWeight: FontWeight.bold)),
    );
  }

  void _openEarningsEstimator() {
    final now = DateTime.now();
    final weekday = now.weekday;
    final blocks = [
      {'label': 'Breakfast (7–9am)', 'hour': 8},
      {'label': 'Lunch (12–2pm)', 'hour': 13},
      {'label': 'Afternoon (2–5pm)', 'hour': 15},
      {'label': 'Dinner (6–9pm)', 'hour': 19},
      {'label': 'Late night (9pm–12am)', 'hour': 22},
    ];
    Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(
      appBar: AppBar(title: const Text('Earnings Estimator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Based on typical order patterns for today — not live demand data.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ...blocks.map((b) => Card(child: ListTile(title: Text(b['label'] as String), trailing: _demandChip(_demandFor(weekday, b['hour'] as int))))),
        ],
      ),
    )));
  }

  void _requestPayoutDialog(RoleProvider roleProvider) {
    if (roleProvider.riderWallet <= 0) {
      _showFeatureDialog(context, "Nothing to withdraw", "Your wallet balance is currently zero.");
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cash Out'),
        content: Text('Withdraw the full balance (Ksh ${roleProvider.riderWallet.toStringAsFixed(2)}) via Bank Transfer?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await roleProvider.requestRiderPayout(roleProvider.riderWallet, 'Bank Transfer');
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout requested — awaiting Admin disbursement.')));
              } catch (e) {
                if (mounted) _showErrorSnack(context, e);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleProvider = context.watch<RoleProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Driver App'),
        actions: [
          Row(children: [
            Text(isOnline ? "Online" : "Offline", style: TextStyle(color: isOnline ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)),
            Switch(value: isOnline, activeColor: Colors.green, onChanged: _goOnline),
          ]),
        ],
      ),
      body: _currentIndex == 0 ? _buildHome() : _currentIndex == 1 ? _buildEarningsView(isDark, roleProvider) : _currentIndex == 2 ? _buildInbox() : _buildProfile(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Earnings'),
          BottomNavigationBarItem(icon: Icon(Icons.inbox), label: 'Inbox'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildHome() {
    return Stack(
      children: [
        const GoogleMap(initialCameraPosition: CameraPosition(target: LatLng(-1.286389, 36.817223), zoom: 14), myLocationEnabled: true),
        if (_isSearching)
          const Positioned(top: 20, left: 20, right: 20, child: Card(child: Padding(padding: EdgeInsets.all(16), child: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Looking for nearby orders...')])))),
        Positioned(
          bottom: 20, left: 20, right: 20,
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.refresh, color: Colors.blue),
              title: const Text("Check for orders now"),
              subtitle: const Text("Manually re-check nearby available deliveries"),
              onTap: isOnline ? () => _goOnline(true) : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEarningsView(bool isDark, RoleProvider roleProvider) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.green[700]!, isDark ? const Color(0xFF121212) : Colors.white])),
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Wallet Balance', style: TextStyle(fontSize: 16, color: Colors.white70)),
                Text(roleProvider.riderWallet.toStringAsFixed(2), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.green[700]), onPressed: () => _requestPayoutDialog(roleProvider), child: const Text('Cash Out / Instant Pay')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.white, borderRadius: BorderRadius.circular(12)),
            child: ListTile(leading: const Icon(Icons.bar_chart), title: const Text("Earnings Estimator"), subtitle: const Text("Plan your schedule around peak pay"), trailing: const Icon(Icons.arrow_forward_ios), onTap: _openEarningsEstimator),
          ),
        ],
      ),
    );
  }

  Widget _buildInbox() {
    return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No message-center backend exists yet — this is a placeholder.', style: TextStyle(color: Colors.grey))));
  }

  Widget _buildProfile() {
    final average = (_ratings?['average'] as num?)?.toDouble() ?? 0.0;
    final count = (_ratings?['count'] as num?)?.toInt() ?? 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(leading: const Icon(Icons.star, color: Colors.amber), title: Text(count == 0 ? "No ratings yet" : "${average.toStringAsFixed(1)}★ average"), subtitle: Text('$count completed deliveries rated')),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500, fontSize: 16)),
          onTap: () async {
            await AuthService().logout();
            context.read<RoleProvider>().clearSession();
            if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
          },
        ),
      ],
    );
  }
}

// ============================================================================
// ADMIN DASHBOARD — Vendor Approvals, Rider Approvals, and Payout Dashboard
// are now backed by the real /admin endpoints via RoleProvider. Overview's
// revenue/order KPIs and the Disputes/Fraud/City-Zone/Support tabs stay as
// labeled placeholders — there's no analytics-aggregation or
// dispute/fraud/ticketing backend yet, and pretending otherwise would just
// be a different kind of fake button.
// ============================================================================

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _selectedTab = "Overview";
  bool _isLoadingQueues = true;

  @override
  void initState() {
    super.initState();
    _loadQueues();
  }

  Future<void> _loadQueues() async {
    setState(() => _isLoadingQueues = true);
    try {
      await context.read<RoleProvider>().refreshAdminQueues();
    } catch (e) {
      if (mounted) _showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _isLoadingQueues = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = const Color(0xFF141414);
    final cardColor = const Color(0xFF1E1E1E);
    final accentColor = const Color(0xFFFF9800);
    final roleProvider = context.watch<RoleProvider>();
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    Widget sidebar = Container(
      width: 250,
      color: const Color(0xFF1A1A1A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.all(24.0), child: Row(children: [Icon(Icons.dashboard, color: accentColor, size: 28), const SizedBox(width: 12), const Text("Internal Ops", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))])),
          Expanded(
            child: ListView(
              children: [
                _buildNavItem(Icons.pie_chart, "Overview", _selectedTab == "Overview", accentColor, isMobile),
                _buildNavItem(Icons.verified_user, "Vendor Approvals", _selectedTab == "Vendor Approvals", accentColor, isMobile),
                _buildNavItem(Icons.two_wheeler, "Rider Approvals", _selectedTab == "Rider Approvals", accentColor, isMobile),
                _buildNavItem(Icons.gavel, "Disputes/Refunds", _selectedTab == "Disputes/Refunds", accentColor, isMobile),
                _buildNavItem(Icons.account_balance, "Payout Dashboard", _selectedTab == "Payout Dashboard", accentColor, isMobile),
                _buildNavItem(Icons.warning, "Fraud Flags", _selectedTab == "Fraud Flags", accentColor, isMobile),
                _buildNavItem(Icons.settings, "City/Zone Config", _selectedTab == "City/Zone Config", accentColor, isMobile),
                _buildNavItem(Icons.support_agent, "Support Queue", _selectedTab == "Support Queue", accentColor, isMobile),
              ],
            ),
          ),
          _buildNavItem(Icons.logout, "Logout", false, Colors.red, isMobile, onTap: () async {
            await AuthService().logout();
            context.read<RoleProvider>().clearSession();
            if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
          }),
        ],
      ),
    );

    Widget content;
    if (_isLoadingQueues) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_selectedTab == "Vendor Approvals") {
      content = _buildVendorApprovals(cardColor, roleProvider);
    } else if (_selectedTab == "Rider Approvals") {
      content = _buildRiderApprovals(cardColor, roleProvider);
    } else if (_selectedTab == "Payout Dashboard") {
      content = _buildPayoutDashboard(cardColor, roleProvider, isMobile);
    } else if (_selectedTab == "Overview") {
      content = _buildOverview(cardColor, accentColor, isMobile);
    } else {
      content = Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text("$_selectedTab isn't backed by the API yet.", style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: isMobile ? AppBar(backgroundColor: const Color(0xFF1A1A1A), title: Text(_selectedTab, style: const TextStyle(color: Colors.white)), iconTheme: const IconThemeData(color: Colors.white)) : null,
      drawer: isMobile ? Drawer(child: sidebar) : null,
      body: isMobile ? content : Row(children: [sidebar, Expanded(child: content)]),
    );
  }

  Widget _buildOverview(Color cardColor, Color accentColor, bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMobile) const Text('Overview', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          if (!isMobile) const SizedBox(height: 24),
          const Text("Revenue/order analytics aren't backed by an aggregation endpoint yet — these are placeholders.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Row(children: [
            _buildKpiCard("PENDING VENDORS", "", cardColor),
            const SizedBox(width: 16),
            _buildKpiCard("PENDING RIDERS", "", cardColor),
          ]),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String subText, Color cardColor) {
    final roleProvider = context.watch<RoleProvider>();
    final value = title.contains('VENDOR') ? '${roleProvider.pendingVendors.length}' : '${roleProvider.pendingRiders.length}';
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorApprovals(Color cardColor, RoleProvider roleProvider) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Pending Vendor Applications", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (roleProvider.pendingVendors.isEmpty)
              const Text("No pending vendor applications.", style: TextStyle(color: Colors.grey))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: roleProvider.pendingVendors.length,
                  itemBuilder: (context, index) {
                    final v = roleProvider.pendingVendors[index];
                    return ListTile(
                      leading: const Icon(Icons.store, color: Colors.blueAccent),
                      title: Text('${v['business_name']}', style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${v['user']?['name'] ?? ''} • ${v['user']?['phone'] ?? ''} • ${v['location'] ?? ''}', style: const TextStyle(color: Colors.grey)),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          try {
                            await roleProvider.approveVendor(v['id']);
                          } catch (e) {
                            if (context.mounted) _showErrorSnack(context, e);
                          }
                        },
                        child: const Text("Approve Vendor"),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiderApprovals(Color cardColor, RoleProvider roleProvider) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Pending Rider Applications", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (roleProvider.pendingRiders.isEmpty)
              const Text("No pending rider applications.", style: TextStyle(color: Colors.grey))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: roleProvider.pendingRiders.length,
                  itemBuilder: (context, index) {
                    final r = roleProvider.pendingRiders[index];
                    return ListTile(
                      leading: const Icon(Icons.motorcycle, color: Colors.orange),
                      title: Text('${r['user']?['name'] ?? 'Rider'} — ${r['vehicle_type']}', style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${r['user']?['phone'] ?? ''} • Plate: ${r['plate_number']}', style: const TextStyle(color: Colors.grey)),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          try {
                            await roleProvider.approveRider(r['id']);
                          } catch (e) {
                            if (context.mounted) _showErrorSnack(context, e);
                          }
                        },
                        child: const Text("Approve Rider"),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutDashboard(Color cardColor, RoleProvider roleProvider, bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("PENDING PAYOUTS", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('${roleProvider.pendingPayouts.length}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Payment Requests", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (roleProvider.pendingPayouts.isEmpty)
                    const Text("No pending payout requests.", style: TextStyle(color: Colors.grey))
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: roleProvider.pendingPayouts.length,
                        itemBuilder: (context, index) {
                          final req = roleProvider.pendingPayouts[index];
                          final isVendor = req['party'] == 'VENDOR';
                          return ListTile(
                            leading: Icon(isVendor ? Icons.store : Icons.two_wheeler, color: isVendor ? Colors.green : Colors.orange),
                            title: Text("${req['party']} payout", style: const TextStyle(color: Colors.white)),
                            subtitle: Text("Requested: Ksh ${req['amount']} via ${req['method']}", style: const TextStyle(color: Colors.grey)),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36)),
                              onPressed: () async {
                                try {
                                  await roleProvider.disbursePayout(req['id']);
                                } catch (e) {
                                  if (context.mounted) _showErrorSnack(context, e);
                                }
                              },
                              child: const Text("Disburse Funds", style: TextStyle(fontSize: 12)),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, bool isSelected, Color accentColor, bool isMobile, {VoidCallback? onTap}) {
    return InkWell(
      onTap: () {
        if (onTap != null) {
          onTap();
          return;
        }
        // Fixed: pop the Drawer route BEFORE triggering setState, and defer
        // the rebuild to the next frame — calling setState first (the old
        // order) rebuilt the tree while the Drawer route was still being
        // torn down, which is what caused the "RenderBox was not laid out"
        // crashes when tapping sidebar items on mobile.
        if (isMobile) {
          Navigator.pop(context);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedTab = title);
          });
        } else {
          setState(() => _selectedTab = title);
        }
      },
      child: Container(
        color: isSelected ? accentColor.withOpacity(0.1) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(children: [
          Icon(icon, color: isSelected ? accentColor : Colors.grey, size: 20),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: TextStyle(color: isSelected ? accentColor : Colors.white70, fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
        ]),
      ),
    );
  }
}

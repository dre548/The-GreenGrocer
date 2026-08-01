import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  // 1. Ensure Flutter is ready before doing async work
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Load the .env file
  await dotenv.load(fileName: ".env");

  // 3. Safety check (optional but good practice)
  final mapsKey = dotenv.env['MAPS_SDK_KEY'] ?? '';
  if (mapsKey.isEmpty) {
    throw Exception('MAPS_SDK_KEY not set. Check your .env file.');
  }

  // 4. Run the app WITH the Providers intact
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppStateProvider()),
        ChangeNotifierProvider(create: (context) => CartProvider()),
        ChangeNotifierProvider(create: (context) => LocationProvider()),
      ],
      child: const TheGreengrocerApp(),
    ),
  );
}

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CartProvider()),
        ChangeNotifierProvider(create: (context) => LocationProvider()),
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
      home: const LoginScreen(),
    );
  }
}

// --- STATE MANAGEMENT ---
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

// --- SHARED UI HELPERS ---
Widget _buildStyledTextField(TextEditingController controller, String hint, bool isDark) {
  return Container(
    decoration: BoxDecoration(
      color: isDark ? Colors.grey[900] : Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
    ),
    child: TextField(
      controller: controller,
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
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
      ],
    ),
  );
}

// ============================================================================
// 1. PROFESSIONAL LOGIN SCREEN 
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

  void _attemptLogin() async {
    if (_phoneController.text.length < 9) return;
    FocusScope.of(context).unfocus(); 
    setState(() => isLoading = true);
    
    String fullPhone = '+254${_phoneController.text}';
    String? result = await _auth.login(fullPhone);
    
    setState(() => isLoading = false);

    if (result == 'CUSTOMER') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainNavigation(userPhone: fullPhone)));
    } else if (result == 'VENDOR') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const VendorDashboardScreen()));
    } else if (result == 'RIDER') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const RiderDashboardScreen()));
    } else if (result == 'ADMIN') { 
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result ?? 'Login failed. Check connection.'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
              )
            ],
          ),
        ),
      ),
    );
  }
}

class ProfessionalPhoneInput extends StatelessWidget {
  final TextEditingController phoneController;
  const ProfessionalPhoneInput({super.key, required this.phoneController});

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
              keyboardType: TextInputType.phone,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: '7XX XXX XXX',
                hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              inputFormatters: [
                LengthLimitingTextInputFormatter(9), 
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. MAIN BOTTOM NAVIGATION CONTROLLER (CUSTOMER)
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
            activeIcon: const Icon(Icons.shopping_cart), label: 'Baskets'
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. HOME SCREEN
// ============================================================================
class HomeScreen extends StatefulWidget {
  final String userPhone;
  const HomeScreen({super.key, required this.userPhone});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> products = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    try {
      final response = await http.get(Uri.parse('http://10.0.2.2:3000/products'));
      if (response.statusCode == 200) {
        setState(() { products = jsonDecode(response.body); isLoading = false; });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final locationData = Provider.of<LocationProvider>(context);

    return CustomScrollView(
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
              isLoading 
                ? const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()))
                : _buildDynamicProductList(isDark),
            ],
          ),
        ),
      ],
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
      child: Row(
        children: [
          Icon(icon, size: 18, color: fgColor),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(color: fgColor, fontWeight: FontWeight.w600)),
        ],
      ),
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
                      child: Center(child: Text(product["emoji"] ?? "🛒", style: const TextStyle(fontSize: 60))),
                    ),
                    Positioned(
                      bottom: 8, right: 8,
                      child: GestureDetector(
                        onTap: () {
                          cart.addItem(product["name"], product["price"], product["emoji"] ?? "🛒");
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${product["name"]} added!'), duration: const Duration(seconds: 1)));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                          child: const Icon(Icons.add, color: Colors.black, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(product["name"], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('Ksh ${product["price"]} ${product["unit"]}', style: TextStyle(color: isDark ? Colors.greenAccent : Colors.green[700], fontWeight: FontWeight.w600, fontSize: 14)),
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
                  if (time != null) {
                    setState(() => _selectedTime = "Scheduled: ${time.format(context)}");
                  }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(title: const Text("Delivery Details"), elevation: 1),
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? Colors.grey[900] : Colors.grey[50],
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Enter a new address",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          _buildAddressListTile(Icons.home, "Home", "Set your home address"),
          _buildAddressListTile(Icons.work, "Work", "Set your work address"),
          _buildAddressListTile(Icons.add_location_alt, "Add a label", "Add custom location"),
          const Divider(),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text("Nearby Addresses", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          _buildAddressListTile(Icons.place, "Shopping Centre", "Nearby"),
          const Divider(),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text("Previous Addresses", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          _buildAddressListTile(Icons.history, "Previous Location", "History"),
        ],
      ),
    );
  }

  Widget _buildAddressListTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: Colors.grey.withOpacity(0.2), child: Icon(icon, color: Colors.black)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      onTap: () {}, 
    );
  }
}

// ============================================================================
// 4. PICKUP MAP SCREEN
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
  double _deliveryFeeLimit = 5.0;
  double _minRating = 4.5;
  final Map<String, bool> _cuisines = {"American": false, "Asian": false, "Bakery": false, "BBQ": false};

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
    try {
      final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.latitude},${pos.longitude}&key=${dotenv.env['GEOCODING_API_KEY']}';
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
    if (!mounted) return;
    setState(() => _isLoadingPlaces = true);
    try {
      String url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${pos.latitude},${pos.longitude}&radius=3000&type=restaurant&key=${dotenv.env['PLACES_API_KEY']}';
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

  void _showFilterSheet(String title, Widget child) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.only(top: 16, bottom: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Divider(height: 1),
                child,
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _fetchRealGooglePlaces(_currentPosition);
                        },
                        child: const Text('Apply', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Reset', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600)),
                      )
                    ],
                  ),
                )
              ],
            ),
          );
        }
      ),
    );
  }

  void _showDeliveryModeFilter() {
    _showFilterSheet("Delivery", StatefulBuilder(
      builder: (context, setModalState) {
        return Column(
          children: [
            CheckboxListTile(
              title: const Text("Delivery", style: TextStyle(fontWeight: FontWeight.w500)),
              value: _isDeliveryMode,
              activeColor: Colors.black,
              onChanged: (val) {
                setModalState(() => _isDeliveryMode = true);
                setState(() => _isDeliveryMode = true);
              },
            ),
            CheckboxListTile(
              title: const Text("Pick-up", style: TextStyle(fontWeight: FontWeight.w500)),
              value: !_isDeliveryMode,
              activeColor: Colors.black,
              onChanged: (val) {
                setModalState(() => _isDeliveryMode = false);
                setState(() => _isDeliveryMode = false);
              },
            ),
          ],
        );
      },
    ));
  }

  void _showDeliveryFeeFilter() {
    _showFilterSheet("Delivery Fee", StatefulBuilder(
      builder: (context, setModalState) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Any amount", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: Colors.black, inactiveTrackColor: Colors.grey[300],
                  thumbColor: Colors.black, overlayColor: Colors.black12,
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _deliveryFeeLimit,
                  min: 3, max: 8, divisions: 5,
                  label: _deliveryFeeLimit > 7 ? "7+" : "${_deliveryFeeLimit.toInt()}",
                  onChanged: (val) {
                    setModalState(() => _deliveryFeeLimit = val);
                    setState(() => _deliveryFeeLimit = val);
                  },
                ),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text("3"), Text("5"), Text("7"), Text("7+")],
              )
            ],
          ),
        );
      },
    ));
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
                    ),
                    child: const Row(
                      children: [
                        SizedBox(width: 16), Icon(Icons.search, color: Colors.grey), SizedBox(width: 12),
                        Expanded(child: Text('Search delivery near you', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill(_isDeliveryMode ? Icons.home : Icons.directions_walk, _isDeliveryMode ? 'Delivery' : 'Pick-up', true, isDark, _showDeliveryModeFilter),
                        _buildFilterPill(null, 'Delivery Fee', false, isDark, _showDeliveryFeeFilter),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          Positioned(
            top: 145, right: 16,
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
                    if (index == 1) return Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(_isDeliveryMode ? 'Delivery near you' : 'Pick-up near you', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)));
                    if (_isLoadingPlaces) return const Center(child: CircularProgressIndicator());

                    final place = nearbyRestaurants[index - 2];
                    double distInMeters = Geolocator.distanceBetween(_currentPosition.latitude, _currentPosition.longitude, place['geometry']['location']['lat'], place['geometry']['location']['lng']);
                    String distStr = "${(distInMeters / 1000).toStringAsFixed(1)} km";
                    String photoUrl = place['photos'] != null && place['photos'].isNotEmpty
                        ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${place['photos'][0]['photo_reference']}&key=$placesApiKey'
                        : 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=600';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildStoreCard(place['name'] ?? 'Restaurant', '⭐ ${place['rating'] ?? 'New'} • $distStr • ${place['vicinity'] ?? ''}', photoUrl, isDark),
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

  Widget _buildFilterPill(IconData? icon, String? label, bool isSelected, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: isDark ? Colors.white : Colors.black), if (label != null) const SizedBox(width: 6)],
            if (label != null) Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white : Colors.black)),
            if (label != null) Icon(Icons.keyboard_arrow_down, size: 16, color: isDark ? Colors.white : Colors.black),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreCard(String title, String subtitle, String imageUrl, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 160, color: Colors.grey[300], child: const Icon(Icons.fastfood, size: 50))),
            ),
            Positioned(
              top: 12, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Icon(_isDeliveryMode ? Icons.delivery_dining : Icons.directions_walk, size: 14, color: Colors.black),
                    const SizedBox(width: 4),
                    Text(_isDeliveryMode ? 'Delivery' : 'Pick it up', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

// ============================================================================
// 5. SEARCH SCREEN & BASKETS
// ============================================================================

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
              child: const TextField(
                decoration: InputDecoration(hintText: 'Search The Greengrocer', prefixIcon: Icon(Icons.search), border: InputBorder.none),
              ),
            ),
            const SizedBox(height: 24),
            Text('Groceries you\'ll love', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 4,
                children: [
                  _dishCircle('Fruits', '🍎', isDark),
                  _dishCircle('Veggies', '🥦', isDark),
                  _dishCircle('Meat', '🥩', isDark),
                  _dishCircle('Dairy', '🥛', isDark),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _dishCircle(String title, String emoji, bool isDark) {
    return Column(
      children: [
        CircleAvatar(radius: 35, backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200], child: Text(emoji, style: const TextStyle(fontSize: 30))),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black, fontSize: 13)),
      ],
    );
  }
}

class BasketsScreen extends StatelessWidget {
  final String userPhone;
  const BasketsScreen({super.key, required this.userPhone});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cart = Provider.of<CartProvider>(context);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft, 
              child: Text('Your Basket', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))
            ),
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
                        const SizedBox(height: 8),
                        Text('Once you add items, your basket will appear here.', style: TextStyle(color: Colors.grey[600])),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:', style: TextStyle(fontSize: 18)),
                        Text('${cart.totalAmount}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _showFeatureDialog(context, "M-Pesa Checkout", "M-Pesa STK push initiated to $userPhone"),
                      child: const Text('Checkout with M-Pesa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
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
// 7. CUSTOMER PROFILE 
// ============================================================================

class ProfileScreen extends StatelessWidget {
  final String userPhone;
  const ProfileScreen({super.key, required this.userPhone});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

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
                _settingsTile('Account settings', Icons.settings_outlined, textColor, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountSettingsScreen()))),
                _settingsTile('Family', Icons.group_outlined, textColor, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FamilyScreen()))),
                _settingsTile('Promotions', Icons.local_offer_outlined, textColor, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PromotionsScreen()))),
                _settingsTile('Help', Icons.help_outline, textColor, () => _showFeatureDialog(context, "Support", "Support chat initiated.")),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500, fontSize: 16)),
                  onTap: () async {
                    await AuthService().logout();
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
          child: Column(
            children: [
              Icon(icon, size: 28, color: isDark ? Colors.white : Colors.black),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsTile(String title, IconData icon, Color textColor, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 16)),
      onTap: onTap,
    );
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
            const Text("No favorites yet", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Mark your best orders as favorite to reorder quickly.", style: TextStyle(color: Colors.grey)),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Cash Balance", style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 8),
                const Text("0.00", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.green[700]),
                  onPressed: () {}, 
                  child: const Text("Add Cash"),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text("Payment Methods", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ListTile(leading: const Icon(Icons.phone_android, color: Colors.green), title: const Text("Mobile Money"), trailing: const Icon(Icons.arrow_forward_ios, size: 16), onTap: (){}),
          ListTile(leading: const Icon(Icons.money, color: Colors.grey), title: const Text("Cash on Delivery"), trailing: const Icon(Icons.arrow_forward_ios, size: 16), onTap: (){}),
          const Divider(),
          const Text("Vouchers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ListTile(leading: const Icon(Icons.card_giftcard, color: Colors.orange), title: const Text("Received Vouchers"), trailing: const Icon(Icons.arrow_forward_ios, size: 16), onTap: (){}),
          ListTile(leading: const Icon(Icons.add_circle_outline), title: const Text("Add Voucher Code"), trailing: const Icon(Icons.arrow_forward_ios, size: 16), onTap: (){}),
        ],
      ),
    );
  }
}

class OrdersTabScreen extends StatelessWidget {
  final String userPhone;
  const OrdersTabScreen({super.key, required this.userPhone});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Your Orders"),
          bottom: const TabBar(
            indicatorColor: Colors.green,
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            tabs: [Tab(text: "Past Items"), Tab(text: "Past Orders")],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPastItems(context),
            _OrderHistoryListScreenStateful(userPhone: userPhone), 
          ],
        ),
      ),
    );
  }

  Widget _buildPastItems(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3, 
      itemBuilder: (context, index) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: Container(
            height: 60, width: 60,
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text("🛍️", style: TextStyle(fontSize: 30))),
          ),
          title: const Text("Item Name", style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text("Ordered previously"),
          trailing: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(minimumSize: const Size(80, 36), padding: const EdgeInsets.symmetric(horizontal: 16)),
            child: const Text("Reorder"),
          ),
        );
      },
    );
  }
}

class _OrderHistoryListScreenStateful extends StatefulWidget {
  final String userPhone;
  const _OrderHistoryListScreenStateful({required this.userPhone});
  @override
  _OrderHistoryListState createState() => _OrderHistoryListState();
}

class _OrderHistoryListState extends State<_OrderHistoryListScreenStateful> {
  List<dynamic> orders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.get(
        Uri.parse('http://10.0.2.2:3000/orders/history'),
        headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ${prefs.getString('token')}' },
      );
      if (response.statusCode == 200) {
        setState(() {
          orders = jsonDecode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (orders.isEmpty) return const Center(child: Text('You have no past orders.'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
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
                  _buildPremiumChip(order['status'], order['status'] != 'DELIVERED'),
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
            ],
          ),
        );
      },
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
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(radius: 50, backgroundColor: Colors.grey[300], child: const Icon(Icons.person, size: 50, color: Colors.white)),
                Positioned(
                  bottom: 0, right: 0,
                  child: CircleAvatar(backgroundColor: Colors.green, radius: 18, child: IconButton(icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white), onPressed: () {})),
                )
              ],
            ),
          ),
          const SizedBox(height: 32),
          const TextField(decoration: InputDecoration(labelText: "Full Name", border: OutlineInputBorder())),
          const SizedBox(height: 24),
          const Text("Saved Places", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ListTile(leading: const Icon(Icons.home), title: const Text("Home"), subtitle: const Text("Set address"), onTap: (){}),
          ListTile(leading: const Icon(Icons.work), title: const Text("Work"), subtitle: const Text("Set address"), onTap: (){}),
          const Divider(),
          ListTile(leading: const Icon(Icons.swap_horiz), title: const Text("Switch Account"), onTap: (){}),
          ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("Sign Out", style: TextStyle(color: Colors.red)), onTap: (){}),
        ],
      ),
    );
  }
}

class FamilyBannerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()..color = const Color(0xFFFDE8E1);
    canvas.drawRect(rect, bgPaint);

    final sunPaint = Paint()..color = const Color(0xFFFBD1C5);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), size.width * 0.45, sunPaint);

    final pYellow = Paint()..color = const Color(0xFFEDAA00);
    final pGreen = Paint()..color = const Color(0xFF1E6C3B);
    final pPurple = Paint()..color = const Color(0xFF865181);
    final pSkin = Paint()..color = const Color(0xFFD3835B);

    canvas.drawRect(Rect.fromLTWH(size.width * 0.05, size.height * 0.4, size.width * 0.22, size.height * 0.6), pYellow);
    canvas.drawCircle(Offset(size.width * 0.16, size.height * 0.28), 24, pSkin);

    canvas.drawRect(Rect.fromLTWH(size.width * 0.38, size.height * 0.35, size.width * 0.24, size.height * 0.65), pYellow);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.22), 26, pSkin);

    canvas.drawRect(Rect.fromLTWH(size.width * 0.60, size.height * 0.42, size.width * 0.20, size.height * 0.58), pPurple);
    canvas.drawCircle(Offset(size.width * 0.70, size.height * 0.26), 22, pSkin);

    canvas.drawRect(Rect.fromLTWH(size.width * 0.78, size.height * 0.38, size.width * 0.20, size.height * 0.62), pGreen);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.24), 22, pSkin);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ContactBannerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()..color = const Color(0xFFE8F1F5);
    canvas.drawRect(rect, bgPaint);

    final skyPaint = Paint()..color = const Color(0xFFD1E4EC);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.6), skyPaint);

    final buildingPaint = Paint()..color = const Color(0xFF4C6B7B);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.02, size.height * 0.2, size.width * 0.15, size.height * 0.4), buildingPaint);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.75, size.height * 0.15, size.width * 0.22, size.height * 0.45), buildingPaint);

    final carPaint = Paint()..color = const Color(0xFF1D3557);
    final carWindow = Paint()..color = const Color(0xFFA8DADC);
    
    RRect carBody = RRect.fromLTRBR(size.width * 0.1, size.height * 0.4, size.width * 0.65, size.height * 0.75, const Radius.circular(20));
    canvas.drawRRect(carBody, carPaint);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.2, size.height * 0.45, size.width * 0.3, size.height * 0.15), carWindow);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  void _navigateToContactScreen(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const ChooseContactScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select a member", style: TextStyle(fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                SizedBox(height: 200, width: double.infinity, child: CustomPaint(painter: FamilyBannerPainter())),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Take care of your family with the App", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor, height: 1.2)),
                      const SizedBox(height: 16),
                      Text("Want to pay for your loved ones? Invite a family member (ages 18+) to create a family profile. You can:", style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[300] : Colors.grey[800], height: 1.4)),
                      const SizedBox(height: 24),
                      _buildFeatureRow(Icons.favorite, "Pay for your family", "Use a shared payment method", isDark),
                      const Divider(height: 32),
                      _buildFeatureRow(Icons.notifications, "Get updates", "Receive notifications when a member uses the family profile", isDark),
                      const Divider(height: 32),
                      _buildFeatureRow(Icons.settings, "Manage family members", "Add up to 10 people that can use the Family profile", isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _navigateToContactScreen(context),
                child: const Text("Invite family", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 28, color: isDark ? Colors.white : Colors.black),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }
}

class ChooseContactScreen extends StatelessWidget {
  const ChooseContactScreen({super.key});

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Allow Contact Access?"),
        content: const Text("The App needs access to your contacts to invite family members."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Deny")),
          ElevatedButton(
            onPressed: () { 
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Contacts synced successfully.")));
            },
            child: const Text("Allow"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Choose a contact", style: TextStyle(fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                SizedBox(height: 200, width: double.infinity, child: CustomPaint(painter: ContactBannerPainter())),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Invite adults to your Family profile", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor, height: 1.2)),
                      const SizedBox(height: 16),
                      Text("Take care of your loved ones. You'll be able to:", style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[300] : Colors.grey[800], height: 1.4)),
                      const SizedBox(height: 24),
                      _buildFeatureRow(Icons.credit_card, "Pay for trips and orders", "Share a payment method.", isDark),
                      const Divider(height: 32),
                      _buildFeatureRow(Icons.tune, "Set spending limits", "Manage your family's monthly spending.", isDark),
                      const Divider(height: 32),
                      _buildFeatureRow(Icons.route, "Follow trips", "Track trips from start to finish.", isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showPermissionDialog(context),
                child: const Text("Choose a contact", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 28, color: isDark ? Colors.white : Colors.black),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }
}

class PromotionsScreen extends StatelessWidget {
  const PromotionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Promotions")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _promoCard("20% Off Groceries", "Valid until Friday. Code: FRESH20"),
          _promoCard("Free Delivery on purchases", "Applied automatically at checkout."),
        ],
      ),
    );
  }

  Widget _promoCard(String title, String desc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const Icon(Icons.local_offer, color: Colors.green, size: 40),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(desc),
        ),
        trailing: ElevatedButton(
          onPressed: () {}, 
          style: ElevatedButton.styleFrom(minimumSize: const Size(80, 36)),
          child: const Text("Claim"),
        ),
      ),
    );
  }
}

// ============================================================================
// 8. REGISTRATION & SIGNUPS 
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
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
        ),
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
                if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => MainNavigation(userPhone: fullPhone)), (route) => false);
              }
            },
            child: const Text("Register & Shop", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}

class VendorSignupScreen extends StatefulWidget {
  const VendorSignupScreen({super.key});
  @override
  _VendorSignupScreenState createState() => _VendorSignupScreenState();
}

class _VendorSignupScreenState extends State<VendorSignupScreen> {
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _shopName = TextEditingController();
  String _location = "Fetching GPS...";

  @override
  void initState() {
    super.initState();
    _getLocation();
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
          _buildStyledTextField(_name, 'Your Full Name', isDark),
          const SizedBox(height: 16),
          _buildStyledTextField(_shopName, 'Shop or Business Name', isDark),
          const SizedBox(height: 16),
          ProfessionalPhoneInput(phoneController: _phone),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blueGrey),
                const SizedBox(width: 12),
                Expanded(child: Text("Location: $_location", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.blueGrey, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () async {
              String fullPhone = '+254${_phone.text}';
              bool success = await AuthService().registerVendor(fullPhone, _name.text, _shopName.text, _location);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Application sent! Waiting for Admin approval.")));
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
            child: const Text("Submit Application", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}

class RiderSignupScreen extends StatefulWidget {
  const RiderSignupScreen({super.key});
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
  final picker = ImagePicker();

  Future pickImage(bool isFront) async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        if (isFront) _idFront = File(pickedFile.path);
        else _idBack = File(pickedFile.path);
      });
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
          _buildStyledTextField(_name, 'Full Name', isDark),
          const SizedBox(height: 16),
          ProfessionalPhoneInput(phoneController: _phone),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _vehicleType,
                isExpanded: true,
                dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.w500),
                items: ['BODABODA', 'CAR'].map((String val) {
                  return DropdownMenuItem<String>(value: val, child: Text(val));
                }).toList(),
                onChanged: (val) => setState(() => _vehicleType = val!),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildStyledTextField(_plate, 'License Plate Number', isDark),
          const SizedBox(height: 24),
          Text('ID Verification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildImageUploadBtn('Front of ID', _idFront != null, () => pickImage(true), isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildImageUploadBtn('Back of ID', _idBack != null, () => pickImage(false), isDark)),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () async {
              if (_idFront == null || _idBack == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload both sides of your ID.")));
                return;
              }
              String fullPhone = '+254${_phone.text}';
              bool success = await AuthService().registerRider(fullPhone, _name.text, _vehicleType, _plate.text, _idFront!.path, _idBack!.path);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Application sent! Waiting for Admin approval.")));
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
            child: const Text("Submit Application", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          )
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
// 9. VENDOR DASHBOARD (KITCHEN DISPLAY SYSTEM & MENU MAKER)
// ============================================================================

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});
  @override
  _VendorDashboardScreenState createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  int _currentIndex = 0;
  bool isStoreOpen = true; 
  List<dynamic> activeOrders = [];

  void _showAddProductDialog(bool isDark) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String _selectedCategory = "Specials";
    File? productImage;
    final picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) setState(() => productImage = File(pickedFile.path));
                    },
                    child: Container(
                      height: 120, width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        image: productImage != null ? DecorationImage(image: FileImage(productImage!), fit: BoxFit.cover) : null,
                      ),
                      child: productImage == null ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Icon(Icons.add_a_photo, size: 40, color: Colors.grey), SizedBox(height: 8), Text('Upload Photo', style: TextStyle(color: Colors.grey))],
                      ) : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStyledTextField(nameCtrl, 'Item Name', isDark),
                  const SizedBox(height: 12),
                  _buildStyledTextField(priceCtrl, 'Price', isDark),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(filled: true, fillColor: isDark ? Colors.grey[800] : Colors.grey[200], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    items: ["Specials", "Mains", "Drinks"].map((String category) {
                      return DropdownMenuItem(value: category, child: Text(category));
                    }).toList(),
                    onChanged: (newValue) => setState(() => _selectedCategory = newValue!),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                    onPressed: () => _showFeatureDialog(context, "Modifier Groups", "Add sizes, toppings, and customizations here."),
                    icon: const Icon(Icons.add_circle),
                    label: const Text("Add Modifier Group"),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Save Item'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Dashboard'),
        actions: [
          Row(
            children: [
              Text(isStoreOpen ? "Online" : "Offline", style: TextStyle(color: isStoreOpen ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)),
              Switch(
                value: isStoreOpen,
                activeColor: Colors.green,
                onChanged: (val) => setState(() => isStoreOpen = val), 
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
          ),
        ],
      ),
      body: _currentIndex == 0 ? _buildKitchenDisplay(isDark) : _currentIndex == 1 ? _buildMenuManager(isDark) : _buildReports(isDark),
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
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: () => _showFeatureDialog(context, "Busy Mode", "Added 15 mins to prep times."),
                    icon: const Icon(Icons.timer, size: 18), label: const Text("Busy Mode", style: TextStyle(fontSize: 13))
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size(0, 48)),
                    onPressed: () => _showFeatureDialog(context, "Pause Orders", "Incoming orders temporarily halted."),
                    icon: const Icon(Icons.pause, size: 18), label: const Text("Pause Orders", style: TextStyle(fontSize: 13))
                  ),
                ),
                IconButton(icon: const Icon(Icons.print), onPressed: () => _showFeatureDialog(context, "Receipt Printing", "Connecting to POS printer..."))
              ],
            ),
          ),
          const TabBar(
            labelColor: Colors.green, unselectedLabelColor: Colors.grey,
            tabs: [Tab(text: "New"), Tab(text: "Preparing"), Tab(text: "Ready")],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildOrderList(["Order #1092", "Order #1093"], isDark, "Accept Order"), 
                _buildOrderList(["Order #1091"], isDark, "Mark Ready"),
                _buildOrderList(["Order #1089"], isDark, "View Rider Info"), 
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<String> orders, bool isDark, String actionText) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return Card(
          color: isDark ? Colors.grey[900] : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(orders[index], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("Items listed here..."),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
                      onPressed: () => _showFeatureDialog(context, actionText, "Action completed."), 
                      child: Text(actionText)
                    ),
                    const SizedBox(width: 8),
                    TextButton(onPressed: () => _showFeatureDialog(context, "Manage Order", "Delay or cancel order due to stock shortages."), child: const Text("Manage"))
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuManager(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)), onPressed: () => _showAddProductDialog(isDark), icon: const Icon(Icons.add, size: 18), label: const Text("Add Item"))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)), onPressed: () => _showFeatureDialog(context, "Add Category", "New menu category created."), icon: const Icon(Icons.folder, size: 18), label: const Text("Add Category"))),
          ],
        ),
        const SizedBox(height: 16),
        ListTile(
          title: const Text("Auto-menu optimization"),
          subtitle: const Text("Automatically rearranges items to boost sales."),
          trailing: Switch(value: true, activeColor: Colors.green, onChanged: (v){}),
        ),
        const Divider(),
        SwitchListTile(title: const Text("Sample Item 1"), subtitle: const Text("In Stock"), value: true, onChanged: (v){}), 
        SwitchListTile(title: const Text("Sample Item 2"), subtitle: const Text("Out of Stock"), value: false, onChanged: (v){}),
      ],
    );
  }

  Widget _buildReports(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _statCard('Wallet Balance', '0.00', Icons.account_balance_wallet, isDark, Colors.green, action: () => _showFeatureDialog(context, "Instant Payout", "Transferring funds to your registered payment method.")),
        const SizedBox(height: 16),
        ListTile(leading: const Icon(Icons.error_outline), title: const Text("Order Errors (Menu Item)"), trailing: const Icon(Icons.arrow_forward_ios), onTap: (){}),
        ListTile(leading: const Icon(Icons.receipt_long), title: const Text("Order Errors (Transaction)"), trailing: const Icon(Icons.arrow_forward_ios), onTap: (){}),
        ListTile(leading: const Icon(Icons.timer_off), title: const Text("Downtime Report"), trailing: const Icon(Icons.arrow_forward_ios), onTap: (){}),
        ListTile(leading: const Icon(Icons.star_rate), title: const Text("Customer & Delivery Feedback"), trailing: const Icon(Icons.arrow_forward_ios), onTap: (){}),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, bool isDark, Color iconColor, {VoidCallback? action}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.grey[100], borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 40, color: iconColor),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
              onPressed: action, child: const Text("Request Payout")
            )
          ]
        ],
      ),
    );
  }
}

// ============================================================================
// 10. RIDER DASHBOARD 
// ============================================================================

class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key});
  @override
  _RiderDashboardScreenState createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  int _currentIndex = 0;
  bool isOnline = false;
  bool isDeliveryMode = true;

  void _showIncomingOrderAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("New Delivery Request!"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Pickup ➔ Dropoff"),
            SizedBox(height: 8),
            Text("Est. Payout: 0.00", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            SizedBox(height: 16),
            LinearProgressIndicator(value: 0.5), 
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Decline", style: TextStyle(color: Colors.red))), 
          ElevatedButton(
            onPressed: () { 
              Navigator.pop(context);
              _showActiveDeliveryModal();
            }, 
            child: const Text("Accept") 
          ),
        ],
      ),
    );
  }

  void _showActiveDeliveryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Active Delivery", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ElevatedButton.icon(onPressed: () => _showFeatureDialog(context, "Navigating", "Turn-by-turn navigation launched"), icon: const Icon(Icons.navigation), label: const Text("Navigate to pickup")),
            const SizedBox(height: 8),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey), onPressed: () => _showFeatureDialog(context, "Contact", "Calling vendor..."), icon: const Icon(Icons.phone), label: const Text("Call/message vendor")),
            const SizedBox(height: 8),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: () => _showFeatureDialog(context, "Arrived", "Notified vendor you are on-site"), icon: const Icon(Icons.store), label: const Text("Arrived at store")),
            const SizedBox(height: 8),
            ElevatedButton.icon(onPressed: () => _showFeatureDialog(context, "Checklist", "Confirmed order is complete"), icon: const Icon(Icons.check_box), label: const Text("Confirm pickup")),
            const Divider(height: 32),
            ElevatedButton.icon(onPressed: () => _showFeatureDialog(context, "Navigating", "Turn-by-turn navigation launched"), icon: const Icon(Icons.navigation), label: const Text("Navigate to customer")),
            const SizedBox(height: 8),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey), onPressed: () => _showFeatureDialog(context, "Contact", "Calling customer..."), icon: const Icon(Icons.phone), label: const Text("Call/message customer")),
            const SizedBox(height: 8),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.black), onPressed: () => _showFeatureDialog(context, "Delivery Complete", "Photo/Code confirmed. Order closed."), icon: const Icon(Icons.camera_alt), label: const Text("Confirm delivery (Photo/Code)")),
            const SizedBox(height: 8),
            TextButton.icon(onPressed: () => _showFeatureDialog(context, "Report", "Flagged issue to support"), icon: const Icon(Icons.warning, color: Colors.red), label: const Text("Report a problem", style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver App'),
        actions: [
          IconButton(icon: Icon(isDeliveryMode ? Icons.delivery_dining : Icons.local_taxi), onPressed: () {
            setState(() => isDeliveryMode = !isDeliveryMode);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isDeliveryMode ? "Delivery Mode Active" : "Rideshare Mode Active")));
          }),
          Row(
            children: [
              Text(isOnline ? "Online" : "Offline", style: TextStyle(color: isOnline ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)),
              Switch(
                value: isOnline,
                activeColor: Colors.green,
                onChanged: (val) {
                  setState(() => isOnline = val); 
                  if (val) Future.delayed(const Duration(seconds: 2), _showIncomingOrderAlert);
                },
              ),
            ],
          ),
        ],
      ),
      body: _currentIndex == 0 ? _buildActiveMap() : _currentIndex == 1 ? _buildEarningsView(isDark) : _currentIndex == 2 ? _buildInbox() : _buildProfile(),
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

  Widget _buildActiveMap() {
    return Stack(
      children: [
        const GoogleMap(
          initialCameraPosition: CameraPosition(target: LatLng(-1.286389, 36.817223), zoom: 14),
          myLocationEnabled: true,
        ),
        Positioned(
          bottom: 20, left: 20, right: 20,
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.explore, color: Colors.blue),
              title: const Text("Discover nearby opportunities"),
              subtitle: const Text("High demand in your area!"),
              onTap: () => _showFeatureDialog(context, "Discover", "Showing upcoming reservations and events."),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildEarningsView(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.green[700], borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Wallet Balance', style: TextStyle(fontSize: 16, color: Colors.white70)),
              const Text('0.00', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.green[700]),
                onPressed: () => _showFeatureDialog(context, "Instant Payout", "Transferring funds to your registered mobile wallet."), 
                child: const Text('Cash Out / Instant Pay')
              )
            ],
          ),
        ),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.bar_chart),
          title: const Text("Earnings Estimator"),
          subtitle: const Text("Plan your schedule around peak pay"),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _showFeatureDialog(context, "Estimator", "Showing busiest times to work."),
        )
      ],
    );
  }

  Widget _buildInbox() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton.icon(
          onPressed: () => _showFeatureDialog(context, "Support", "Opening chat with Ops Support..."),
          icon: const Icon(Icons.support_agent),
          label: const Text("Support Chat"),
        ),
        const SizedBox(height: 16),
        const ListTile(leading: Icon(Icons.message), title: Text("Document approved"), subtitle: Text("Your vehicle registration was approved.")),
        const ListTile(leading: Icon(Icons.message), title: Text("Welcome to the fleet"), subtitle: Text("Here are tips for your first delivery.")),
      ],
    );
  }

  Widget _buildProfile() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ListTile(leading: Icon(Icons.star, color: Colors.amber), title: Text("Pro Status: Bronze"), subtitle: Text("Unlocks premium rewards")),
        const ListTile(leading: Icon(Icons.person), title: Text("Personal Details"), subtitle: Text("Name, Photo, Vehicle")),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.upload_file), 
          title: const Text("Upload Documents"), 
          subtitle: const Text("ID, Licence, Insurance"), 
          onTap: () => _showFeatureDialog(context, "Upload", "Opening document picker...")
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500, fontSize: 16)),
          onTap: () async {
            await AuthService().logout();
            if (context.mounted) {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            }
          },
        ),
      ],
    );
  }
}

// ============================================================================
// 11. ADMIN DASHBOARD (RESPONSIVE MOBILE + DESKTOP UI)
// ============================================================================

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _selectedTab = "Overview";

  @override
  Widget build(BuildContext context) {
    final bgColor = const Color(0xFF141414);
    final cardColor = const Color(0xFF1E1E1E);
    final accentColor = const Color(0xFFFF9800); 

    // Detect if the user is on a mobile device (width less than 800px)
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    // The Sidebar Navigation (Used natively or inside a Drawer)
    Widget sidebar = Container(
      width: 250,
      color: const Color(0xFF1A1A1A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Icon(Icons.dashboard, color: accentColor, size: 28),
                const SizedBox(width: 12),
                const Text("Internal Ops", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
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
            if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
          }),
        ],
      ),
    );

    // The Main Content Area
    Widget content = Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMobile)
            Text(_selectedTab, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          if (!isMobile)
            const SizedBox(height: 24),
          
          if (_selectedTab == "Overview") ...[
            isMobile 
              ? Column(
                  children: [
                    Row(children: [_buildKpiCard("REVENUE MTD", "0.00", "↑ 0% vs last period", cardColor), const SizedBox(width: 16), _buildKpiCard("ORDERS MTD", "0", "↑ 0% vs last period", cardColor)]),
                    const SizedBox(height: 16),
                    Row(children: [_buildKpiCard("AVG ORDER VALUE", "0.00", "↓ 0% vs last period", cardColor), const SizedBox(width: 16), _buildKpiCard("ACTIVE CUSTOMERS", "0", "↑ 0% vs last period", cardColor)]),
                  ],
                )
              : Row(
                  children: [
                    _buildKpiCard("REVENUE MTD", "0.00", "↑ 0% vs last period", cardColor),
                    const SizedBox(width: 16),
                    _buildKpiCard("ORDERS MTD", "0", "↑ 0% vs last period", cardColor),
                    const SizedBox(width: 16),
                    _buildKpiCard("AVG ORDER VALUE", "0.00", "↓ 0% vs last period", cardColor),
                    const SizedBox(width: 16),
                    _buildKpiCard("ACTIVE CUSTOMERS", "0", "↑ 0% vs last period", cardColor),
                  ],
                ),
            const SizedBox(height: 24),
            Expanded(
              child: isMobile 
                ? ListView(
                    children: [
                      Container(
                        height: 300,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("REVENUE - LAST 30 DAYS", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Center(child: Icon(Icons.show_chart, size: 100, color: Colors.blue[400])),
                            const Spacer(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("TOP 5 PRODUCTS", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 24),
                            _buildHorizontalBar("Product 1", 0.9, accentColor),
                            _buildHorizontalBar("Product 2", 0.75, accentColor),
                            _buildHorizontalBar("Product 3", 0.6, accentColor),
                            _buildHorizontalBar("Product 4", 0.45, accentColor),
                            _buildHorizontalBar("Product 5", 0.3, accentColor),
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("REVENUE - LAST 30 DAYS", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Center(child: Icon(Icons.show_chart, size: 150, color: Colors.blue[400])),
                              const Spacer(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("TOP 5 PRODUCTS", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 24),
                              _buildHorizontalBar("Product 1", 0.9, accentColor),
                              _buildHorizontalBar("Product 2", 0.75, accentColor),
                              _buildHorizontalBar("Product 3", 0.6, accentColor),
                              _buildHorizontalBar("Product 4", 0.45, accentColor),
                              _buildHorizontalBar("Product 5", 0.3, accentColor),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
            ),
          ] 
          else if (_selectedTab == "Payout Dashboard") ...[
            isMobile 
              ? Column(
                  children: [
                    Row(children: [_buildKpiCard("PENDING PAYOUTS", "0.00", "Requires Action", cardColor), const SizedBox(width: 16), _buildKpiCard("TOTAL DISBURSED", "0.00", "All Time", cardColor)]),
                  ],
                )
              : Row(
                  children: [
                    _buildKpiCard("PENDING PAYOUTS", "0.00", "Requires Action", cardColor),
                    const SizedBox(width: 16),
                    _buildKpiCard("TOTAL DISBURSED", "0.00", "All Time", cardColor),
                  ],
                ),
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
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.store, color: Colors.green),
                      title: const Text("Vendor Request", style: TextStyle(color: Colors.white)),
                      subtitle: const Text("Requested: 0.00 via M-Pesa", style: TextStyle(color: Colors.grey)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36)),
                        onPressed: () => _showFeatureDialog(context, "Payout Approved", "Funds disbursed to Vendor wallet."), 
                        child: const Text("Approve Payout", style: TextStyle(fontSize: 12))
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.two_wheeler, color: Colors.orange),
                      title: const Text("Rider Request", style: TextStyle(color: Colors.white)),
                      subtitle: const Text("Requested: 0.00 via Bank", style: TextStyle(color: Colors.grey)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36)),
                        onPressed: () => _showFeatureDialog(context, "Payout Approved", "Funds disbursed to Rider wallet."), 
                        child: const Text("Approve Payout", style: TextStyle(fontSize: 12))
                      ),
                    )
                  ],
                ),
              ),
            ),
          ]
          else ...[
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                child: Center(
                  child: Text("Data module for $_selectedTab will render here.", style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                ),
              ),
            ),
          ]
        ],
      ),
    );

    return Scaffold(
      backgroundColor: bgColor,
      // If Mobile: Show an AppBar with a Hamburger Menu
      appBar: isMobile 
        ? AppBar(
            backgroundColor: const Color(0xFF1A1A1A),
            title: Text(_selectedTab, style: const TextStyle(color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white),
          ) 
        : null,
      // If Mobile: Put the sidebar inside the Drawer
      drawer: isMobile ? Drawer(child: sidebar) : null,
      // If Mobile: Show just the content. If Desktop: Show Sidebar + Content side-by-side
      body: isMobile 
        ? content 
        : Row(
            children: [
              sidebar,
              Expanded(child: content),
            ],
          ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, bool isSelected, Color accentColor, bool isMobile, {VoidCallback? onTap}) {
    return InkWell(
      onTap: () {
        if (onTap != null) {
          onTap();
        } else {
          setState(() => _selectedTab = title);
          if (isMobile) Navigator.pop(context); // Close drawer after tapping on mobile
        }
      },
      child: Container(
        color: isSelected ? accentColor.withOpacity(0.1) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? accentColor : Colors.grey, size: 20),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: TextStyle(color: isSelected ? accentColor : Colors.white70, fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, String subText, Color cardColor) {
    bool isPositive = subText.contains('↑');
    bool isAlert = subText.contains('Requires');
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subText, style: TextStyle(color: isAlert ? Colors.orange : (isPositive ? Colors.greenAccent : Colors.redAccent), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalBar(String label, double fillFraction, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12))),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  height: 24,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: constraints.maxWidth * fillFraction,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
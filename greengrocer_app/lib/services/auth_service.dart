import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Thin wrapper around every backend endpoint the app uses. Auth methods
/// persist session data (token, role, vendor/rider id) to SharedPreferences;
/// every other method reads the token back out and attaches it as a Bearer
/// header. All methods return the decoded JSON body (a Map, or a List for
/// list endpoints) and throw an [Exception] with the backend's own error
/// message on failure, so callers can show it directly to the user.
class AuthService {
  String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'https://unsorted-batboy-confront.ngrok-free.dev';

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  dynamic _decodeOrThrow(http.Response response) {
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    final message = (decoded is Map && decoded['message'] != null)
        ? decoded['message'].toString()
        : 'Request failed (${response.statusCode})';
    throw Exception(message);
  }

  Future<dynamic> _get(String path) async {
    final response = await http.get(Uri.parse('$baseUrl$path'), headers: await _authHeaders());
    return _decodeOrThrow(response);
  }

  Future<dynamic> _post(String path, [Map<String, dynamic>? body]) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _authHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _decodeOrThrow(response);
  }

  Future<dynamic> _patch(String path, [Map<String, dynamic>? body]) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: await _authHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _decodeOrThrow(response);
  }

  // ===========================================================================
  // AUTH
  // ===========================================================================

  Future login(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['access_token']);
        await prefs.setString('role', data['role']);
        await prefs.setString('user_id', data['user_id'] ?? '');
        await prefs.setString('name', data['name'] ?? '');
        await prefs.setString('vendor_id', data['vendor_id'] ?? '');
        await prefs.setString('vendor_status', data['vendor_status'] ?? '');
        await prefs.setString('rider_id', data['rider_id'] ?? '');
        await prefs.setString('rider_status', data['rider_status'] ?? '');
        await prefs.setString('phone', phone);
        return data['role'];
      } else {
        return jsonDecode(response.body)['message'];
      }
    } catch (e) {
      return 'Connection error';
    }
  }

  Future registerCustomer(String phone, String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register/customer'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'name': name}),
    );
    if (response.statusCode == 201 || response.statusCode == 200) return await login(phone);
    return null;
  }

  Future registerVendor(String phone, String name, String shopName, String location) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register/vendor'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'name': name, 'shopName': shopName, 'location': location}),
    );
    return response.statusCode == 201 || response.statusCode == 200;
  }

  Future registerRider(String phone, String name, String vehicleType, String plateNumber, String idFrontPath, String idBackPath) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/auth/register/rider'));
    request.fields['phone'] = phone;
    request.fields['name'] = name;
    request.fields['vehicleType'] = vehicleType;
    request.fields['plateNumber'] = plateNumber;
    request.files.add(await http.MultipartFile.fromPath('idFront', idFrontPath));
    request.files.add(await http.MultipartFile.fromPath('idBack', idBackPath));
    var response = await request.send();
    return response.statusCode == 201 || response.statusCode == 200;
  }

  Future logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<String?> getToken() async => (await SharedPreferences.getInstance()).getString('token');
  Future<String?> getRole() async => (await SharedPreferences.getInstance()).getString('role');
  Future<String?> getUserId() async => (await SharedPreferences.getInstance()).getString('user_id');
  Future<String?> getName() async => (await SharedPreferences.getInstance()).getString('name');
  Future<String?> getPhone() async => (await SharedPreferences.getInstance()).getString('phone');

  Future<String?> getVendorId() async {
    final id = (await SharedPreferences.getInstance()).getString('vendor_id');
    return (id == null || id.isEmpty) ? null : id;
  }

  Future<String?> getVendorStatus() async {
    final s = (await SharedPreferences.getInstance()).getString('vendor_status');
    return (s == null || s.isEmpty) ? null : s;
  }

  Future<String?> getRiderId() async {
    final id = (await SharedPreferences.getInstance()).getString('rider_id');
    return (id == null || id.isEmpty) ? null : id;
  }

  Future<String?> getRiderStatus() async {
    final s = (await SharedPreferences.getInstance()).getString('rider_status');
    return (s == null || s.isEmpty) ? null : s;
  }

  // ===========================================================================
  // VENDOR
  // ===========================================================================

  Future<double> getVendorWallet(String vendorId) async {
    final data = await _get('/vendors/$vendorId/wallet');
    return (data['balance'] as num).toDouble();
  }

  Future<void> requestVendorPayout(String vendorId, double amount, String method) async {
    await _post('/vendors/$vendorId/request-payout', {'amount': amount, 'method': method});
  }

  Future<void> setVendorOpenStatus(String vendorId, bool isOpen) async {
    await _patch('/vendors/$vendorId/status', {'is_open': isOpen});
  }

  Future<Map<String, dynamic>> getVendorRatings(String vendorId) async {
    return Map<String, dynamic>.from(await _get('/vendors/$vendorId/ratings'));
  }

  // ===========================================================================
  // RIDER
  // ===========================================================================

  Future<double> getRiderWallet(String riderId) async {
    final data = await _get('/riders/$riderId/wallet');
    return (data['balance'] as num).toDouble();
  }

  Future<void> requestRiderPayout(String riderId, double amount, String method) async {
    await _post('/riders/$riderId/request-payout', {'amount': amount, 'method': method});
  }

  Future<Map<String, dynamic>> getRiderRatings(String riderId) async {
    return Map<String, dynamic>.from(await _get('/riders/$riderId/ratings'));
  }

  // ===========================================================================
  // ADMIN
  // ===========================================================================

  Future<List<dynamic>> getPendingVendors() async => await _get('/admin/pending-vendors');
  Future<List<dynamic>> getPendingRiders() async => await _get('/admin/pending-riders');
  Future<void> approveVendor(String vendorId) async => await _post('/admin/approve-vendor/$vendorId');
  Future<void> approveRider(String riderId) async => await _post('/admin/approve-rider/$riderId');
  Future<List<dynamic>> getPendingPayouts() async => await _get('/admin/pending-payouts');
  Future<void> disbursePayout(String transactionId) async => await _post('/admin/disburse-payout/$transactionId');

  // ===========================================================================
  // ORDERS
  // ===========================================================================

  Future<Map<String, dynamic>> checkout({
    required List<Map<String, dynamic>> items,
    required int subtotal,
    required String idempotencyKey,
  }) async {
    final data = await _post('/orders/checkout', {
      'items': items,
      'subtotal': subtotal,
      'idempotencyKey': idempotencyKey,
    });
    return Map<String, dynamic>.from(data);
  }

  Future<List<dynamic>> getOrderHistory() async => await _get('/orders/history');
  Future<List<dynamic>> getVendorOrders() async => await _get('/orders/vendor-dashboard');

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _post('/orders/update-status', {'orderId': orderId, 'status': status});
  }

  Future<void> cancelOrder(String orderId, String reason) async {
    await _patch('/orders/$orderId/cancel', {'reason': reason});
  }

  Future<void> rateOrder(String orderId, String target, int score, {String? comment}) async {
    await _post('/orders/$orderId/rate', {'target': target, 'score': score, 'comment': comment});
  }

  Future<List<dynamic>> getAvailableDeliveries() async => await _get('/orders/available-deliveries');

  // ===========================================================================
  // DELIVERIES (rider job lifecycle)
  // ===========================================================================

  Future<List<dynamic>> getNearbyDeliveries(double lat, double lng) async {
    final data = await _get('/deliveries/nearby?lat=$lat&lng=$lng');
    return List<dynamic>.from(data['orders'] ?? []);
  }

  Future<Map<String, dynamic>> acceptDelivery(String orderId, double distanceKm) async {
    final data = await _post('/deliveries/accept', {'order_id': orderId, 'distance_km': distanceKm});
    return Map<String, dynamic>.from(data);
  }

  Future<void> markPickedUp(String orderId) async => await _patch('/deliveries/$orderId/picked-up');
  Future<Map<String, dynamic>> markDelivered(String orderId) async {
    final data = await _patch('/deliveries/$orderId/deliver');
    return Map<String, dynamic>.from(data);
  }

  // ===========================================================================
  // PRODUCTS
  // ===========================================================================

  Future<List<dynamic>> getProducts() async {
    final response = await http.get(Uri.parse('$baseUrl/products'));
    return _decodeOrThrow(response);
  }

  Future<void> addProduct(String name, int price, String emoji, String unit) async {
    await _post('/orders/add-product', {'name': name, 'price': price, 'emoji': emoji, 'unit': unit});
  }

  // ===========================================================================
  // MENU ITEMS (vendor's own menu, scoped by vendor_id — distinct from the
  // global /products catalog above)
  // ===========================================================================

  Future<List<dynamic>> getVendorMenuItems(String vendorId) async {
    final response = await http.get(Uri.parse('$baseUrl/menu-items/vendor/$vendorId'));
    return _decodeOrThrow(response);
  }

  Future<void> addMenuItem(String vendorId, String name, int price, String emoji, String unit) async {
    await _post('/menu-items', {'vendor_id': vendorId, 'name': name, 'price': price, 'emoji': emoji, 'unit': unit});
  }

  Future<void> setMenuItemStock(String menuItemId, bool inStock) async {
    await _patch('/menu-items/$menuItemId/stock', {'in_stock': inStock});
  }
}

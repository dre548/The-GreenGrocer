import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String baseUrl = 'https://unsorted-batboy-confront.ngrok-free.dev';

  // --- 1. LOGIN ---
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
        return data['role'];
      } else {
        // Returns the exact error (e.g., "Pending admin approval")
        return jsonDecode(response.body)['message']; 
      }
    } catch (e) {
      return 'Connection error';
    }
  }

  // --- 2. REGISTER CUSTOMER ---
  Future registerCustomer(String phone, String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register/customer'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'name': name}),
    );
    if (response.statusCode == 201 || response.statusCode == 200) return await login(phone); // Auto-login
    return null;
  }

  // --- 3. REGISTER VENDOR ---
  Future registerVendor(String phone, String name, String shopName, String location) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register/vendor'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'name': name, 'shopName': shopName, 'location': location}),
    );
    return response.statusCode == 201 || response.statusCode == 200;
  }

  // --- 4. REGISTER RIDER (WITH PHOTOS!) ---
  Future registerRider(String phone, String name, String vehicleType, String plateNumber, String idFrontPath, String idBackPath) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/auth/register/rider'));
    
    // Add text fields
    request.fields['phone'] = phone;
    request.fields['name'] = name;
    request.fields['vehicleType'] = vehicleType;
    request.fields['plateNumber'] = plateNumber;

    // Attach the physical photos
    request.files.add(await http.MultipartFile.fromPath('idFront', idFrontPath));
    request.files.add(await http.MultipartFile.fromPath('idBack', idBackPath));

    var response = await request.send();
    return response.statusCode == 201 || response.statusCode == 200;
  }

  Future logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
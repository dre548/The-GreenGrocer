import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../main.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String phone;
  final String deliveredTo;
  const OtpVerifyScreen({super.key, required this.phone, required this.deliveredTo});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _codeController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  void _verifyOtp() async {
    if (_codeController.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 4-digit code')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = await _authService.verifyOtp(widget.phone, _codeController.text);
      if (!mounted) return;

      // Fixed: this used to push a named route ('/home') that was never
      // registered anywhere in MaterialApp, which crashed on every
      // successful verification. Now it routes by role — same pattern
      // LoginScreen uses — and loads RoleProvider's session data first so
      // the destination dashboard actually has vendor_id/rider_id/wallet
      // ready immediately.
      await context.read<RoleProvider>().loadSession();
      if (!mounted) return;

      final roleProvider = context.read<RoleProvider>();
      final role = data['role'];

      Widget destination;
      if (role == 'VENDOR' && roleProvider.vendorId != null) {
        destination = VendorDashboardScreen(vendorId: roleProvider.vendorId!);
      } else if (role == 'RIDER' && roleProvider.riderId != null) {
        destination = RiderDashboardScreen(riderId: roleProvider.riderId!);
      } else if (role == 'ADMIN') {
        destination = const AdminDashboardScreen();
      } else {
        destination = MainNavigation(userPhone: widget.phone);
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => destination),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Phone')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Enter the code sent to ${widget.deliveredTo}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: '4-Digit Code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Verify & Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  bool _otpSent = false;
  bool _isLoading = false;

  void _handleSendOtp() async {
    setState(() => _isLoading = true);
    final success = await _authService.sendOtp(_phoneController.text);
    setState(() {
      _isLoading = false;
      _otpSent = success;
    });
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OTP sent! Check your backend terminal.')),
      );
    }
  }

  void _handleVerifyOtp() async {
    setState(() => _isLoading = true);
    final success = await _authService.verifyOtp(_phoneController.text, _otpController.text);
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login Successful! Token saved.')),
      );
      // Next step: Navigate to the Home Screen!
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid OTP. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('GreenGrocer Login')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. ADD YOUR LOGO HERE:
            Image.asset('assets/images/logo.png', height: 100),
            
            // 2. ADD A LITTLE SPACING BELOW IT:
            SizedBox(height: 30), 

            // Your existing text fields continue below...
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: '+254712345678',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              enabled: !_otpSent,
            ),
            SizedBox(height: 20),
            
            if (_otpSent) ...[
              TextField(
                controller: _otpController,
                decoration: InputDecoration(
                  labelText: 'Enter 4-Digit OTP',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),
            ],

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : (_otpSent ? _handleVerifyOtp : _handleSendOtp),
                child: _isLoading 
                    ? CircularProgressIndicator(color: Colors.white) 
                    : Text(_otpSent ? 'Verify OTP & Login' : 'Send OTP'),
              ),
            ),
          ],
        ),
      ),
    );
  }
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../home/screens/home_screen.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpVerifyScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final otpControllers = List.generate(6, (_) => TextEditingController());
  final otpFocusNodes = List.generate(6, (_) => FocusNode());

  static const bgColor = Color(0xFFFAF8FF);
  static const cardColor = Color(0xFFFEFBFF);
  static const primaryColor = Color(0xFF5663A0);

  Future<void> verifyOtp() async {
    final otp = otpControllers.map((e) => e.text).join();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter 6 digit OTP')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userRole', 'sales');
    await prefs.setString('lastLoggedInUser', widget.phoneNumber);

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    for (final controller in otpControllers) {
      controller.dispose();
    }
    for (final node in otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Widget otpBox(int index) {
    return SizedBox(
      width: 48,
      height: 48,
      child: TextField(
        controller: otpControllers[index],
        focusNode: otpFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: bgColor,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE0DDE8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            otpFocusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            otpFocusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 42),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 80, color: primaryColor),
                  const SizedBox(height: 28),

                  const Text(
                    'OTP Login',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2028),
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Enter phone number to continue',
                    style: TextStyle(fontSize: 18, color: Colors.black45),
                  ),

                  const SizedBox(height: 34),

                  TextField(
                    readOnly: true,
                    controller: TextEditingController(text: widget.phoneNumber),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.phone_outlined),
                      filled: true,
                      fillColor: bgColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 22),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFFE4E1EA)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, otpBox),
                  ),

                  const SizedBox(height: 52),

                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: ElevatedButton(
                      onPressed: verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cardColor,
                        foregroundColor: primaryColor,
                        elevation: 5,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Verify OTP',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  const Text(
                    'Resend in 26 s',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

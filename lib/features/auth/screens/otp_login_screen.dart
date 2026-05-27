import 'package:flutter/material.dart';
import 'otp_verify_screen.dart';

class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends State<OtpLoginScreen> {
  final phoneController = TextEditingController();

  static const bgColor = Color(0xFFFAF8FF);
  static const cardColor = Color(0xFFFEFBFF);
  static const primaryColor = Color(0xFF5663A0);

  Future<void> sendOtp() async {
    final phone = phoneController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter phone number')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _OtpSuccessDialog(),
    );

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    Navigator.pop(context);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpVerifyScreen(phoneNumber: phone),
      ),
    );
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
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

                  const SizedBox(height: 42),

                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'Phone Number',
                      hintStyle: const TextStyle(
                        fontSize: 20,
                        color: Colors.black45,
                      ),
                      prefixIcon: const Icon(Icons.phone_outlined),
                      filled: true,
                      fillColor: bgColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 22),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFFE4E1EA)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: primaryColor),
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),

                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: ElevatedButton(
                      onPressed: sendOtp,
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
                        'Send OTP',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

class _OtpSuccessDialog extends StatelessWidget {
  const _OtpSuccessDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Color(0xFF10C7A7), size: 48),
            SizedBox(height: 10),
            Text(
              'OTP sent successfully',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.black87,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
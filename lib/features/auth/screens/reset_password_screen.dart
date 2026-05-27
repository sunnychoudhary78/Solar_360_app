import 'package:flutter/material.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final newPasswordController = TextEditingController();
  final otpControllers = List.generate(6, (_) => TextEditingController());
  final otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool isPasswordHidden = true;

  static const bgColor = Color(0xFFFAF8FF);
  static const cardColor = Color(0xFFFEFBFF);
  static const primaryColor = Color(0xFF5663A0);

  void resetPassword() {
    final otp = otpControllers.map((e) => e.text).join();

    if (otp.length != 6 || newPasswordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter OTP and new password')),
      );
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String getPasswordStrength() {
    final password = newPasswordController.text.trim();

    if (password.isEmpty) return '';
    if (password.length < 6) return 'Weak';
    if (password.length < 10) return 'Medium';
    return 'Strong';
  }

  Color getStrengthColor() {
    final strength = getPasswordStrength();

    if (strength == 'Weak') return Colors.red;
    if (strength == 'Medium') return Colors.orange;
    if (strength == 'Strong') return Colors.green;
    return Colors.transparent;
  }

  @override
  void dispose() {
    newPasswordController.dispose();

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
      height: 58,
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
    final strength = getPasswordStrength();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, size: 30),
                  ),
                  const Expanded(
                    child: Text(
                      'Reset Password',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF202027),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const Spacer(),

            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield, size: 82, color: primaryColor),
                  const SizedBox(height: 28),

                  const Text(
                    'Enter verification code',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2028),
                    ),
                  ),

                  const SizedBox(height: 26),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, otpBox),
                  ),

                  const SizedBox(height: 26),

                  const Text(
                    'Resend OTP in 25 sec',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFF1F2028),
                    ),
                  ),

                  const SizedBox(height: 34),

                  TextField(
                    controller: newPasswordController,
                    obscureText: isPasswordHidden,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'New password',
                      hintStyle: const TextStyle(
                        fontSize: 20,
                        color: Colors.black45,
                      ),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isPasswordHidden
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            isPasswordHidden = !isPasswordHidden;
                          });
                        },
                      ),
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

                  const SizedBox(height: 12),

                  Container(
                    height: 5,
                    width: double.infinity,
                    color: const Color(0xFFE5E4FF),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    strength,
                    style: TextStyle(
                      color: getStrengthColor(),
                      fontSize: 18,
                    ),
                  ),

                  const SizedBox(height: 34),

                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: ElevatedButton(
                      onPressed: resetPassword,
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
                        'Reset Password',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
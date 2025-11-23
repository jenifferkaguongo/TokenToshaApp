// screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Keep this import for Firebase functions

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (mounted) _showMessage('Please enter email and password', isError: true);
      return;
    }

    if (mounted) setState(() => loading = true);

    try {
      // Sign in user
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      
      if (!mounted) return;

      // Check if email is verified
      if (userCredential.user != null && !userCredential.user!.emailVerified) {
        // Email not verified
        await FirebaseAuth.instance.signOut();
        
        if (mounted) {
          _showVerificationDialog(userCredential.user!);
        }
        return;
      }

      // Email is verified - proceed to dashboard (Assuming '/dashboard' route exists)
      if (userCredential.user != null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed. Please try again.';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email.';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email format.';
      } else if (e.code == 'user-disabled') {
        message = 'This account has been disabled.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many failed attempts. Try again later.';
      }
      if (mounted) _showMessage(message, isError: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showVerificationDialog(User user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Email Not Verified'),
        content: Text(
          'Please verify your email address (${user.email}) before logging in.\n\n'
          'Check your inbox for the verification link.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.green)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              try {
                User? currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null) {
                  await currentUser.sendEmailVerification();
                }                
                if (!mounted) return;
                
                Navigator.pop(context);
                _showMessage('Verification email sent! Check your inbox.');
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  _showMessage('Failed to send email: ${e.toString()}', isError: true);
                }
              }
            },
            child: const Text('Resend Email', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword() async {
    final email = emailController.text.trim();
    
    if (email.isEmpty) {
      if (mounted) _showMessage('Please enter your email address first', isError: true);
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) _showMessage('Password reset email sent! Check your inbox.');
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to send reset email';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email format.';
      }
      if (mounted) _showMessage(message, isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.electric_bolt, size: 80, color: Colors.green[700]),
                const SizedBox(height: 20),
                const Text(
                  'Welcome to TokenTosha',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Manage your electricity tokens',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),

                // Email Field (Now a standard TextField, no custom widget needed)
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email, color: Colors.green),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.green, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Password Field (Now a standard TextField, no custom widget needed)
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock, color: Colors.green),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey[700],
                      ),
                      onPressed: () {
                        setState(() => obscurePassword = !obscurePassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.green, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Forgot Password Link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _resetPassword,
                    child: const Text('Forgot Password?', style: TextStyle(color: Colors.green)),
                  ),
                ),
                const SizedBox(height: 16),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Login',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sign Up Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Don\'t have an account? '),
                    TextButton(
                      onPressed: () {
                         // This assumes you have a '/signup' route defined.
                         // If not, it will show an error, but the rest of the login works.
                         Navigator.pushNamed(context, '/signup');
                      },
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
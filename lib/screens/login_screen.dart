import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLoading = false;
  bool _isLogin = true;
  bool _isDoctor = false;

  Future<void> _authenticate() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    // Validation
    if (email.isEmpty || password.isEmpty || (!_isLogin && name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill in all fields")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      if (_isLogin) {
        // 🔐 LOGIN FLOW
        await supabase.auth
            .signInWithPassword(email: email, password: password);
      } else {
        // 📝 SIGN UP FLOW
        final response =
            await supabase.auth.signUp(email: email, password: password, data: {
          'full_name': name,
          'role': _isDoctor
              ? 'doctor'
              : 'patient' // 🚀 CRITICAL: Save Role Instantly
        });

        // If user marked themselves as a Doctor, create the DB entry
        if (_isDoctor && response.user != null) {
          try {
            await supabase.from('doctors').insert({
              'id': response.user!.id,
              'specialty': 'General',
              'clinic_name': 'My Clinic',
            });
          } catch (e) {
            print("Doctor Insert Error: $e");
            // We log this but don't stop the flow because AuthGate handles it now
          }
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal,
      body: SafeArea(
        child: Column(
          children: [
            // 🏥 HEADER
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.medical_services_outlined,
                        size: 80, color: Colors.white),
                    const SizedBox(height: 10),
                    Text(
                      "MediSlot",
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const Text("Book Appointments Instantly",
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),

            // 📋 FORM SECTION
            Expanded(
              flex: 6,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isLogin ? "Welcome Back" : "Create Account",
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),

                      // Name Field (Sign Up Only)
                      if (!_isLogin) ...[
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.person_outline),
                              labelText: "Full Name"),
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.email_outlined),
                            labelText: "Email"),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.lock_outline),
                            labelText: "Password"),
                      ),

                      // Doctor Toggle
                      if (!_isLogin) ...[
                        const SizedBox(height: 20),
                        SwitchListTile(
                          title: const Text("I am a Doctor",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text("Create a doctor account"),
                          value: _isDoctor,
                          activeColor: Colors.teal,
                          onChanged: (val) => setState(() => _isDoctor = val),
                        ),
                      ],

                      const SizedBox(height: 30),

                      ElevatedButton(
                        onPressed: _isLoading ? null : _authenticate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : Text(_isLogin ? "LOGIN" : "SIGN UP",
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                      ),

                      const SizedBox(height: 20),

                      TextButton(
                        onPressed: () => setState(() => _isLogin = !_isLogin),
                        child: Text(
                          _isLogin
                              ? "New here? Create Account"
                              : "Already have an account? Login",
                          style: const TextStyle(color: Colors.teal),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

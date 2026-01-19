import 'package:flutter/material.dart';
import 'package:medislots/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLogin = true; // Toggle between Login and Signup
  bool _isLoading = false;
  String _selectedRole = 'patient'; // Default role

  Future<void> _authenticate() async {
    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    try {
      if (_isLogin) {
        // --- LOGIN FLOW ---
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        // --- SIGNUP FLOW (Updated) ---

        // 1. Create the Auth User
        final AuthResponse res = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );

        final user = res.user;
        if (user == null) {
          throw "Signup failed. Please try again.";
        }

        // 2. Manually Create the Profile in the Database
        // This is better because if it fails, we get a specific error message.
        await Supabase.instance.client.from('profiles').insert({
          'id': user.id, // Link to the auth user
          'full_name': name,
          'role': _selectedRole, // Ensure this is 'patient' or 'doctor'
        });
      }

      if (mounted) {
        // Success! Go to Home.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (_) =>
                  const MyApp()), // Reload app to trigger AuthWrapper
        );
      }
    } on AuthException catch (e) {
      // Handle Supabase Auth specific errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Auth Error: ${e.message}"),
              backgroundColor: Colors.red),
        );
      }
    } on PostgrestException catch (e) {
      // Handle Database specific errors (e.g., invalid role name)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Database Error: ${e.message}"),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? "Login" : "Create Account")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isLogin)
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Full Name"),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),

            // ROLE SELECTION DROPDOWN (Only show during Signup)
            if (!_isLogin)
              DropdownButtonFormField<String>(
                value: _selectedRole,
                items: const [
                  DropdownMenuItem(value: 'patient', child: Text("Patient")),
                  DropdownMenuItem(value: 'doctor', child: Text("Doctor")),
                ],
                onChanged: (val) => setState(() => _selectedRole = val!),
                decoration: const InputDecoration(labelText: "I am a..."),
              ),

            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _authenticate,
                child: Text(_isLogin ? "Login" : "Sign Up"),
              ),

            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(_isLogin
                  ? "New user? Create account"
                  : "Have an account? Login"),
            ),
          ],
        ),
      ),
    );
  }
}

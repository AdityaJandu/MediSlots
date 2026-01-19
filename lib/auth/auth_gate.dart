import 'package:flutter/material.dart';
import 'package:medislots/screens/doctor_dashboard.dart';
import 'package:medislots/screens/home_screen.dart';
import 'package:medislots/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // 🔄 LOADING
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.teal,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        final session = snapshot.data?.session;

        // 🔒 NOT LOGGED IN
        if (session == null) {
          return const LoginScreen();
        }

        // 🔓 LOGGED IN - Check Metadata Instantly!
        // We safely access the 'role' we saved during sign-up
        final userRole = session.user.userMetadata?['role'] ?? 'patient';

        if (userRole == 'doctor') {
          return const DoctorDashboard();
        } else {
          return const HomeScreen();
        }
      },
    );
  }
}

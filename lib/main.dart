import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import the screens we created
import 'login_screen.dart';
import 'home_screen.dart';
import 'doctor_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

// Global accessor for Supabase client
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediSlot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white70,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// This widget listens to Auth state changes (Login/Logout)
/// and decides which page to show.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      // Listen to auth state changes in real-time
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // 1. If loading auth state, show spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // 2. If no user session, show Login
        final session = snapshot.data?.session;
        if (session == null) {
          return const LoginScreen();
        }

        // 3. If user is logged in, check their ROLE
        return const RoleRouter();
      },
    );
  }
}

/// This widget fetches the user's role from the Database
/// and routes them to the correct Dashboard.
class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  bool _isLoading = true;
  String? _role;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    try {
      final userId = supabase.auth.currentUser!.id;

      // Fetch role from 'profiles' table
      final data = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _role = data['role']; // 'patient' or 'doctor'
          _isLoading = false;
        });
      }
    } catch (e) {
      // Handle errors (e.g., if profile creation failed)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching role: $e")),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Setting up your dashboard..."),
            ],
          ),
        ),
      );
    }

    // 4. Route based on role
    if (_role == 'doctor') {
      return const DoctorDashboard();
    } else {
      // Default to HomeScreen for patients (or unknown roles)
      return const HomeScreen();
    }
  }
}
/*

 url: 'https://nnopulmscfgcrndkabvu.supabase.co',
    anonKey: 'sb_publishable_MBIzdMb0HJW82Fvl6mk6lw_JjIGc0vh',

*/
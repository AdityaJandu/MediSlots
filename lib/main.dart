import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medislots/auth/auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        useMaterial3: true,
        // 🏥 MEDICAL COLOR PALETTE
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF009688), // Medical Teal
          primary: const Color(0xFF009688),
          secondary: const Color(0xFFFF7043), // Soft Orange for accents
          surface: const Color(0xFFF8F9FA), // Clean off-white background
        ),

        // 🔤 TYPOGRAPHY
        textTheme: GoogleFonts.latoTextTheme(
          Theme.of(context).textTheme,
        ),

        // 🔘 BUTTON STYLING
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF009688),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 2,
          ),
        ),

        // 🃏 CARD STYLING
        cardTheme: CardTheme(
          elevation: 0, // Flat modern look
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE0E0E0)), // Subtle border
          ),
          color: Colors.white,
        ),

        // 🧱 INPUT FIELDS
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
      home: const AuthGate(), // Your existing starting point
    );
  }
}

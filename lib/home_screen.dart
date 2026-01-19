import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb; // Critical for Web detection
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'booking_screen.dart';
import 'login_screen.dart'; // Needed for Logout if you don't use AuthWrapper

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _doctors = [];
  bool _isLoading = true;
  String? _error;

  // 📍 DEFAULT LOCATION (New Delhi) - Fallback if GPS fails
  final double _defaultLat = 28.6139;
  final double _defaultLong = 77.2090;

  @override
  void initState() {
    super.initState();
    _fetchNearbyDoctors();
  }

  Future<void> _fetchNearbyDoctors() async {
    double userLat = _defaultLat;
    double userLong = _defaultLong;
    bool usedFallback = false;

    try {
      // 1. Check & Request Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw "Permission denied";
      }

      // 2. Configure Settings based on Platform
      LocationSettings locationSettings;

      if (kIsWeb) {
        // ✅ WEB FIX: Browsers often fail with 'high' accuracy because they lack GPS chips.
        // We use 'low' (City level) or 'balanced' which relies on Wi-Fi IP.
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 100,
        );
      } else {
        // 📱 MOBILE: High accuracy is fine, but we add a timeout to prevent hanging.
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
          timeLimit: Duration(seconds: 5),
        );
      }

      // 3. Get Position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      userLat = position.latitude;
      userLong = position.longitude;
    } catch (e) {
      // 4. Fallback Handling
      // If GPS fails (common on Web or Emulators), we catch the error
      // but CONTINUING using the default coordinates so the app doesn't break.
      print("GPS Error: $e. Using default location.");
      usedFallback = true;
    }

    // 5. Call Supabase RPC
    try {
      final List<dynamic> data = await _supabase.rpc(
        'get_nearby_doctors',
        params: {
          'user_lat': userLat,
          'user_long': userLong,
          'filter_specialty': null
        },
      );

      if (mounted) {
        setState(() {
          _doctors = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
          _error = null;
        });

        if (usedFallback) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "GPS unavailable. Showing doctors near default location."),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Database Error: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openMap(double lat, double long) async {
    // Web-compatible Google Maps URL
    final googleUrl =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$long');
    if (await canLaunchUrl(googleUrl)) {
      await launchUrl(googleUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final userEmail = user?.email ?? "Guest";

    return Scaffold(
      appBar: AppBar(title: const Text("Find Doctors")),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("Welcome"),
              accountEmail: Text(userEmail),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(userEmail[0].toUpperCase(),
                    style: const TextStyle(fontSize: 24, color: Colors.teal)),
              ),
              decoration: const BoxDecoration(color: Colors.teal),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Log Out', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context); // Close drawer
                await _supabase.auth.signOut();
                // If using AuthWrapper in main.dart, it will auto-redirect.
                // If not, you might need: Navigator.pushReplacement(...)
              },
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _doctors.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_hospital_outlined,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text("No doctors found nearby."),
                          const SizedBox(height: 8),
                          TextButton(
                              onPressed: _fetchNearbyDoctors,
                              child: const Text("Refresh")),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchNearbyDoctors,
                      child: ListView.builder(
                        itemCount: _doctors.length,
                        itemBuilder: (context, index) {
                          final doctor = _doctors[index];
                          final distMeters = doctor['dist_meters'] as num;
                          final distKm = (distMeters / 1000).toStringAsFixed(1);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal.shade100,
                                child: Text(doctor['full_name'][0],
                                    style: const TextStyle(color: Colors.teal)),
                              ),
                              title: Text(doctor['full_name'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(doctor['specialty'],
                                      style: const TextStyle(
                                          color: Colors.black87)),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on,
                                          size: 14, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          "${doctor['clinic_name']} • $distKm km",
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.directions,
                                    color: Colors.blue),
                                onPressed: () =>
                                    _openMap(doctor['lat'], doctor['long']),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BookingScreen(
                                      doctorId: doctor['id'],
                                      doctorName: doctor['full_name'],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

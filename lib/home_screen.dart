import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'booking_screen.dart';
import 'patient_appointments_screen.dart';

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

  // 📍 Fallback Location (New Delhi)
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
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw "Permission denied";
      }

      LocationSettings locationSettings;
      if (kIsWeb) {
        locationSettings = const LocationSettings(
            accuracy: LocationAccuracy.low, distanceFilter: 100);
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
          timeLimit: Duration(seconds: 5),
        );
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: locationSettings.accuracy,
      );
      userLat = position.latitude;
      userLong = position.longitude;
    } catch (e) {
      print("GPS Error: $e. Using default location.");
      usedFallback = true;
    }

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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  "GPS unavailable. Showing doctors near default location."),
              backgroundColor: Colors.orange));
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
    final googleUrl =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$long');
    if (await canLaunchUrl(googleUrl)) await launchUrl(googleUrl);
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
                      style:
                          const TextStyle(fontSize: 24, color: Colors.teal))),
              decoration: const BoxDecoration(color: Colors.teal),
            ),

            ListTile(
              leading: const Icon(Icons.calendar_month, color: Colors.blue),
              title: const Text('My Appointments'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PatientAppointmentsScreen()));
              },
            ),

            // ✅ NEW: Doctor Messages (Coming Soon)
            ListTile(
              leading:
                  const Icon(Icons.chat_bubble_outline, color: Colors.purple),
              title: const Text('Doctor Messages'),
              subtitle: const Text("Coming Soon",
                  style: TextStyle(fontSize: 10, color: Colors.grey)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Doctor Chat feature is coming soon!"),
                  backgroundColor: Colors.purple,
                ));
              },
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Log Out', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await _supabase.auth.signOut();
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
                  ? const Center(child: Text("No doctors found nearby."))
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
                                  child: Text(doctor['full_name'][0])),
                              title: Text(doctor['full_name'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  "${doctor['specialty']} • ${doctor['clinic_name']} • $distKm km"),
                              trailing: IconButton(
                                  icon: const Icon(Icons.directions,
                                      color: Colors.blue),
                                  onPressed: () =>
                                      _openMap(doctor['lat'], doctor['long'])),
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => BookingScreen(
                                            doctorId: doctor['id'],
                                            doctorName: doctor['full_name'])));
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

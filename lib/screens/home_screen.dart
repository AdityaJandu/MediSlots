import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'booking_screen.dart';
import 'patient_appointments_screen.dart';
import 'conversations_screen.dart'; // Ensure this import exists

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

  // 🔔 REALTIME CHANNEL VARIABLE
  late RealtimeChannel _appointmentsChannel;

  // 📍 Fallback Location (New Delhi)
  final double _defaultLat = 28.6139;
  final double _defaultLong = 77.2090;

  @override
  void initState() {
    super.initState();
    _fetchNearbyDoctors();
    _setupRealtimeListeners(); // 🎧 Start Listening for Status Updates
  }

  @override
  void dispose() {
    _supabase.removeChannel(_appointmentsChannel); // 🧹 Cleanup
    super.dispose();
  }

  // 🎧 NEW: LISTEN FOR BOOKING CONFIRMATIONS
  void _setupRealtimeListeners() {
    final myUserId = _supabase.auth.currentUser!.id;

    _appointmentsChannel = _supabase
        .channel('public:appointments')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'appointments',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'patient_id',
              value: myUserId),
          callback: (payload) {
            final newStatus = payload.newRecord['status'];
            final oldStatus = payload.oldRecord['status'];

            // Notify only if status changed
            if (newStatus != oldStatus) {
              if (newStatus == 'confirmed') {
                _showSnackBar(
                    "Your appointment has been CONFIRMED!", Colors.green);
              } else if (newStatus == 'rejected') {
                _showSnackBar("Your appointment was REJECTED.", Colors.red);
              }
            }
          },
        )
        .subscribe();
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
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
    // 🛠️ Fixed Google Maps URL to actually point to the doctor's location
    final googleUrl =
        Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$long");
    if (await canLaunchUrl(googleUrl)) {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar("Could not open maps", Colors.red);
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
                  child: Text(
                      userEmail.isNotEmpty ? userEmail[0].toUpperCase() : "?",
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
            ListTile(
              leading:
                  const Icon(Icons.chat_bubble_outline, color: Colors.purple),
              title: const Text('Doctor Messages'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ConversationsScreen()));
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

                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.08),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                              border: Border.all(color: Colors.grey.shade100),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => BookingScreen(
                                              doctorId: doctor['id'],
                                              doctorName:
                                                  doctor['full_name'])));
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 1. Doctor Avatar
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.teal.shade50,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            doctor['full_name'].isNotEmpty
                                                ? doctor['full_name'][0]
                                                : "?",
                                            style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.teal.shade700),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // 2. Doctor Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              doctor['full_name'],
                                              style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              doctor['specialty'] ?? 'General',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.teal.shade600,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.location_on,
                                                    size: 14,
                                                    color: Colors.grey[500]),
                                                const SizedBox(width: 2),
                                                Expanded(
                                                  child: Text(
                                                    doctor['clinic_name'] ??
                                                        'Clinic',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color:
                                                            Colors.grey[600]),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // 3. Distance & Action
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              "$distKm km",
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue.shade700),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          CircleAvatar(
                                            backgroundColor:
                                                Colors.teal.shade50,
                                            radius: 18,
                                            child: IconButton(
                                              icon: const Icon(Icons.directions,
                                                  size: 18, color: Colors.teal),
                                              padding: EdgeInsets.zero,
                                              onPressed: () => _openMap(
                                                  doctor['lat'],
                                                  doctor['long']),
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

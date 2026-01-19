import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'booking_screen.dart';
import 'patient_appointments_screen.dart';
import 'conversations_screen.dart';

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

  // 🔍 FILTER STATE
  final List<String> _specialties = [
    "All",
    "General",
    "Dentist",
    "Cardiologist",
    "Dermatologist",
    "Neurologist"
  ];
  String _selectedSpecialty = "All"; // Default

  late RealtimeChannel _appointmentsChannel;

  // 📍 Fallback Location
  final double _defaultLat = 28.6139;
  final double _defaultLong = 77.2090;

  @override
  void initState() {
    super.initState();
    _fetchNearbyDoctors();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    _supabase.removeChannel(_appointmentsChannel);
    super.dispose();
  }

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
      ),
    );
  }

  // 🔄 FETCH DOCTORS (Now handles filtering!)
  Future<void> _fetchNearbyDoctors() async {
    setState(() => _isLoading = true); // Show loader when switching filters

    double userLat = _defaultLat;
    double userLong = _defaultLong;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low);
        userLat = position.latitude;
        userLong = position.longitude;
      }
    } catch (e) {
      debugPrint("GPS Error: $e");
    }

    try {
      // 🔍 FILTER LOGIC: Send 'null' if "All" is selected
      final String? filterParam =
          _selectedSpecialty == "All" ? null : _selectedSpecialty;

      final List<dynamic> data = await _supabase.rpc(
        'get_nearby_doctors',
        params: {
          'user_lat': userLat,
          'user_long': userLong,
          'filter_specialty': filterParam
        },
      );

      if (mounted) {
        setState(() {
          _doctors = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Error: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openMap(double lat, double long) async {
    final googleUrl =
        Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$long");
    if (await canLaunchUrl(googleUrl)) {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
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
      body: Column(
        children: [
          // 🏷️ 1. SPECIALTY FILTER BAR
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _specialties.length,
              itemBuilder: (context, index) {
                final spec = _specialties[index];
                final isSelected = _selectedSpecialty == spec;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(spec),
                    selected: isSelected,
                    selectedColor: Colors.teal.shade100,
                    checkmarkColor: Colors.teal,
                    labelStyle: TextStyle(
                        color:
                            isSelected ? Colors.teal.shade900 : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal),
                    onSelected: (bool selected) {
                      setState(() {
                        _selectedSpecialty = spec;
                      });
                      _fetchNearbyDoctors(); // 🚀 Reload List on Click
                    },
                  ),
                );
              },
            ),
          ),

          // 📋 2. DOCTOR LIST
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _doctors.isEmpty
                        ? Center(
                            child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off,
                                  size: 60, color: Colors.grey),
                              const SizedBox(height: 10),
                              Text(
                                  "No ${_selectedSpecialty == 'All' ? '' : _selectedSpecialty} doctors nearby."),
                            ],
                          ))
                        : RefreshIndicator(
                            onRefresh: _fetchNearbyDoctors,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(top: 8),
                              itemCount: _doctors.length,
                              itemBuilder: (context, index) {
                                final doctor = _doctors[index];
                                final distMeters = doctor['dist_meters'] as num;
                                final distKm =
                                    (distMeters / 1000).toStringAsFixed(1);

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
                                    border:
                                        Border.all(color: Colors.grey.shade100),
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
                                          children: [
                                            // Avatar
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors.teal.shade700),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),

                                            // Details
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(doctor['full_name'],
                                                      style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                      doctor['specialty'] ??
                                                          'General',
                                                      style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors
                                                              .teal.shade600,
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                      doctor['clinic_name'] ??
                                                          'Clinic',
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          color:
                                                              Colors.grey[600]),
                                                      maxLines: 1),
                                                ],
                                              ),
                                            ),

                                            // Distance
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                      color:
                                                          Colors.blue.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8)),
                                                  child: Text("$distKm km",
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors
                                                              .blue.shade700)),
                                                ),
                                                const SizedBox(height: 12),
                                                InkWell(
                                                  onTap: () => _openMap(
                                                      doctor['lat'],
                                                      doctor['long']),
                                                  child: CircleAvatar(
                                                    backgroundColor:
                                                        Colors.teal.shade50,
                                                    radius: 18,
                                                    child: const Icon(
                                                        Icons.directions,
                                                        size: 18,
                                                        color: Colors.teal),
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
          ),
        ],
      ),
    );
  }
}

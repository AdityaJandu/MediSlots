import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:medislots/chat_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final _supabase = Supabase.instance.client;
  bool _isProfileComplete = false;
  bool _isLoading = true;
  bool _isEditingProfile = false; // 🆕 Track if we are editing

  List<Map<String, dynamic>> _appointments = [];
  late RealtimeChannel _appointmentsChannel;

  // Controllers
  final _specialtyController = TextEditingController();
  final _clinicNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  @override
  void initState() {
    super.initState();
    _checkDoctorProfile();
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    _appointmentsChannel = _supabase
        .channel('public:appointments')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'appointments',
          callback: (payload) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("New appointment update!"),
                  duration: Duration(seconds: 1)));
              _fetchAppointments();
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _supabase.removeChannel(_appointmentsChannel);
    super.dispose();
  }

  Future<void> _updateStatus(String appointmentId, String newStatus) async {
    try {
      await _supabase
          .from('appointments')
          .update({'status': newStatus}).eq('id', appointmentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Status updated to $newStatus"),
            backgroundColor:
                newStatus == 'confirmed' ? Colors.green : Colors.red));
      }
      _fetchAppointments(); // Refresh UI immediately
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _fetchAppointments() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('appointments')
        .select('*, profiles(full_name)')
        .eq('doctor_id', userId)
        .order('appointment_date', ascending: true);

    if (mounted) {
      setState(() {
        _appointments = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    }
  }

  // 🆕 Load data into controllers so we can edit it
  void _loadProfileData(Map<String, dynamic> data) {
    _clinicNameController.text = data['clinic_name'] ?? '';
    _specialtyController.text = data['specialty'] ?? '';
    _addressController.text = data['clinic_address'] ?? '';

    // Parse Location (POINT(long lat))
    if (data['location'] != null) {
      final loc = data['location']
          .toString()
          .replaceAll('POINT(', '')
          .replaceAll(')', '');
      final parts = loc.split(' ');
      if (parts.length == 2) {
        _lngController.text = parts[0];
        _latController.text = parts[1];
      }
    }

    // Parse Times
    if (data['work_start_time'] != null) {
      final t = data['work_start_time'].toString().split(':');
      _startTime = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
    }
    if (data['work_end_time'] != null) {
      final t = data['work_end_time'].toString().split(':');
      _endTime = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
    }
  }

  Future<void> _checkDoctorProfile() async {
    final userId = _supabase.auth.currentUser!.id;
    final data =
        await _supabase.from('doctors').select().eq('id', userId).maybeSingle();

    if (mounted) {
      setState(() {
        if (data != null) {
          _isProfileComplete = true;
          _loadProfileData(
              data); // 🆕 Pre-fill form in case they want to edit later
          _fetchAppointments();
        } else {
          _isProfileComplete = false;
          _isLoading = false;
        }
      });
    }
  }

  Future<void> _fillCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      LocationSettings locationSettings;
      if (kIsWeb) {
        locationSettings =
            const LocationSettings(accuracy: LocationAccuracy.low);
      } else {
        locationSettings = const LocationSettings(
            accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10));
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: locationSettings.accuracy);
      setState(() {
        _latController.text = position.latitude.toString();
        _lngController.text = position.longitude.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Coordinates Auto-filled!")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _saveProfile() async {
    if (_latController.text.isEmpty) return;
    setState(() => _isLoading = true);
    final userId = _supabase.auth.currentUser!.id;

    final updateData = {
      'specialty': _specialtyController.text,
      'clinic_name': _clinicNameController.text,
      'clinic_address': _addressController.text,
      'work_start_time': "${_startTime.hour}:00:00",
      'work_end_time': "${_endTime.hour}:00:00",
      'location': 'POINT(${_lngController.text} ${_latController.text})',
    };

    if (_isEditingProfile) {
      // Update existing
      await _supabase.from('doctors').update(updateData).eq('id', userId);
    } else {
      // Insert new
      await _supabase.from('doctors').insert({'id': userId, ...updateData});
    }

    setState(() {
      _isProfileComplete = true;
      _isEditingProfile = false;
      _isLoading = false;
    });
    _fetchAppointments();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
        context: context, initialTime: isStart ? _startTime : _endTime);
    if (picked != null) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 🆕 Show Form if Profile is incomplete OR if we are explicitly editing
    if (!_isProfileComplete || _isEditingProfile) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditingProfile ? "Edit Profile" : "Complete Profile"),
          leading: _isEditingProfile
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _isEditingProfile = false))
              : null,
        ),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TextField(
                  controller: _clinicNameController,
                  decoration: const InputDecoration(labelText: "Clinic Name")),
              TextField(
                  controller: _specialtyController,
                  decoration: const InputDecoration(labelText: "Specialty")),
              TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: "Address")),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: _latController,
                        decoration:
                            const InputDecoration(labelText: "Latitude"))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: _lngController,
                        decoration:
                            const InputDecoration(labelText: "Longitude"))),
              ]),
              TextButton.icon(
                  onPressed: _fillCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text("Get Location")),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: TextButton(
                        onPressed: () => _pickTime(true),
                        child: Text("Start: ${_startTime.format(context)}"))),
                Expanded(
                    child: TextButton(
                        onPressed: () => _pickTime(false),
                        child: Text("End: ${_endTime.format(context)}"))),
              ]),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _saveProfile, child: const Text("SAVE PROFILE")),
            ])),
      );
    }

    // --- MAIN DASHBOARD (Appointments) ---
    return Scaffold(
      appBar: AppBar(title: const Text("Doctor Dashboard")),
      // 🆕 NEW DRAWER
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("Doctor Portal"),
              accountEmail: Text(_supabase.auth.currentUser?.email ?? ""),
              currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.medical_services, color: Colors.teal)),
              decoration: const BoxDecoration(color: Colors.teal),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text("Appointments"),
              onTap: () => Navigator.pop(context), // Already here
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("Edit Profile"),
              onTap: () {
                Navigator.pop(context);
                setState(
                    () => _isEditingProfile = true); // Triggers the form view
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text("Patient Messages"),
              subtitle: const Text("Coming Soon",
                  style: TextStyle(fontSize: 10, color: Colors.grey)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Chat feature coming next!")));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout", style: TextStyle(color: Colors.red)),
              onTap: () => _supabase.auth.signOut(),
            ),
          ],
        ),
      ),
      body: _appointments.isEmpty
          ? const Center(child: Text("No appointments yet."))
          : ListView.builder(
              itemCount: _appointments.length,
              itemBuilder: (context, index) {
                final appt = _appointments[index];
                final patientName = appt['profiles']['full_name'] ?? "Unknown";
                final status = appt['status'] ?? 'pending';
                final time = appt['start_time'].toString().substring(0, 5);

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("📅 ${appt['appointment_date']} at $time"),

                              // 💬 CHAT BUTTON
                              IconButton(
                                icon:
                                    const Icon(Icons.chat, color: Colors.blue),
                                onPressed: () {
                                  // Doctor talks to Patient
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                          otherUserId: appt['patient_id'],
                                          otherUserName: patientName),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          Text("📅 ${appt['appointment_date']} at $time"),
                          if (status == 'pending') ...[
                            const SizedBox(height: 10),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                      onPressed: () =>
                                          _updateStatus(appt['id'], 'rejected'),
                                      child: const Text("Reject",
                                          style: TextStyle(color: Colors.red))),
                                  ElevatedButton(
                                      onPressed: () => _updateStatus(
                                          appt['id'], 'confirmed'),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green),
                                      child: const Text("Accept")),
                                ])
                          ]
                        ]),
                  ),
                );
              },
            ),
    );
  }
}

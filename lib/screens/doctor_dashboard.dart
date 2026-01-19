import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:medislots/widgets/appointment_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'conversations_screen.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final _supabase = Supabase.instance.client;
  bool _isProfileComplete = false;
  bool _isLoading = true;
  bool _isEditingProfile = false;

  List<Map<String, dynamic>> _appointments = [];
  late RealtimeChannel _appointmentsChannel;

  // Controllers
  final _specialtyController = TextEditingController();
  final _clinicNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  // Time Variables (formatted strings for display)
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  final _startController = TextEditingController(text: "09:00 AM");
  final _endController = TextEditingController(text: "05:00 PM");

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
      _fetchAppointments();
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

  void _loadProfileData(Map<String, dynamic> data) {
    _clinicNameController.text = data['clinic_name'] ?? '';
    _specialtyController.text = data['specialty'] ?? '';
    _addressController.text = data['clinic_address'] ?? '';

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

    if (data['work_start_time'] != null) {
      final t = data['work_start_time'].toString().split(':');
      _startTime = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
      _startController.text = _startTime.format(context);
    }
    if (data['work_end_time'] != null) {
      final t = data['work_end_time'].toString().split(':');
      _endTime = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
      _endController.text = _endTime.format(context);
    }
  }

  Future<void> _checkDoctorProfile() async {
    final userId = _supabase.auth.currentUser!.id;
    final data =
        await _supabase.from('doctors').select().eq('id', userId).maybeSingle();

    if (mounted) {
      setState(() {
        if (data != null && data['location'] != null) {
          _isProfileComplete = true;
          _loadProfileData(data);
          _fetchAppointments();
        } else {
          // If partial data exists (like from sign up), load it
          if (data != null) _loadProfileData(data);
          _isProfileComplete = false;
          _isLoading = false;
        }
      });
    }
  }

  Future<void> _fillCurrentLocation() async {
    setState(() => _isLoading = true);
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
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Location Detected Successfully!"),
          backgroundColor: Colors.green));
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Location Error: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _saveProfile() async {
    if (_latController.text.isEmpty || _clinicNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please fill all fields and get location.")));
      return;
    }
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

    // Upsert works for both insert and update
    await _supabase.from('doctors').upsert({'id': userId, ...updateData});

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
      setState(() {
        if (isStart) {
          _startTime = picked;
          _startController.text = picked.format(context);
        } else {
          _endTime = picked;
          _endController.text = picked.format(context);
        }
      });
    }
  }

  // 🏥 UI: Profile Setup Form
  Widget _buildSetupForm() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditingProfile ? "Edit Clinic Profile" : "Clinic Setup"),
        leading: _isEditingProfile
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _isEditingProfile = false))
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Text("Tell us about your practice",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal)),
            const Text("Patients need this info to find you.",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            // Card 1: Basic Info
            _buildSectionHeader("Clinic Details"),
            const SizedBox(height: 10),
            TextField(
                controller: _clinicNameController,
                decoration: const InputDecoration(
                    labelText: "Clinic Name",
                    prefixIcon: Icon(Icons.local_hospital))),
            const SizedBox(height: 16),
            TextField(
                controller: _specialtyController,
                decoration: const InputDecoration(
                    labelText: "Specialty (e.g. Dentist)",
                    prefixIcon: Icon(Icons.badge))),
            const SizedBox(height: 24),

            // Card 2: Location
            _buildSectionHeader("Address & Location"),
            const SizedBox(height: 10),
            TextField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: "Full Address", prefixIcon: Icon(Icons.map))),
            const SizedBox(height: 16),

            // Location Detector Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100)),
              child: Row(
                children: [
                  const Icon(Icons.my_location, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("GPS Coordinates",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue)),
                        Text(
                          _latController.text.isEmpty
                              ? "Not detected yet"
                              : "${_latController.text}, ${_lngController.text}",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                      onPressed: _fillCurrentLocation,
                      child: const Text("DETECT"))
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Card 3: Timings
            _buildSectionHeader("Work Hours"),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startController,
                    readOnly: true,
                    onTap: () => _pickTime(true),
                    decoration: const InputDecoration(
                        labelText: "Start Time",
                        prefixIcon: Icon(Icons.wb_sunny_outlined)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _endController,
                    readOnly: true,
                    onTap: () => _pickTime(false),
                    decoration: const InputDecoration(
                        labelText: "End Time",
                        prefixIcon: Icon(Icons.nightlight_round)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text("SAVE PROFILE",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 🆕 SHOW SETUP FORM IF PROFILE INCOMPLETE OR EDITING
    if (!_isProfileComplete || _isEditingProfile) {
      return _buildSetupForm();
    }

    // --- MAIN DASHBOARD ---
    return Scaffold(
      appBar: AppBar(title: const Text("Doctor Dashboard")),
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
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("Edit Clinic Profile"),
              onTap: () {
                Navigator.pop(context);
                setState(() => _isEditingProfile = true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text("Patient Messages"),
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
              title: const Text("Logout", style: TextStyle(color: Colors.red)),
              onTap: () => _supabase.auth.signOut(),
            ),
          ],
        ),
      ),
      body: _appointments.isEmpty
          ? const Center(child: Text("No appointments yet."))
          : ListView.builder(
              padding: const EdgeInsets.only(top: 10),
              itemCount: _appointments.length,
              itemBuilder: (context, index) {
                final appt = _appointments[index];
                // ✅ Using the reusable card we built earlier
                return AppointmentCard(
                  appointment: appt,
                  isDoctor: true,
                  onAccept: () => _updateStatus(appt['id'], 'confirmed'),
                  onReject: () => _updateStatus(appt['id'], 'rejected'),
                );
              },
            ),
    );
  }
}

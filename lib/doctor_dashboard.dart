import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb; // Critical for Web detection
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final _supabase = Supabase.instance.client;
  bool _isProfileComplete = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];

  final _specialtyController = TextEditingController();
  final _clinicNameController = TextEditingController();
  final _addressController = TextEditingController();

  // Manual Coordinate Controllers
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  @override
  void initState() {
    super.initState();
    _checkDoctorProfile();
  }

  Future<void> _checkDoctorProfile() async {
    final userId = _supabase.auth.currentUser!.id;
    final data =
        await _supabase.from('doctors').select().eq('id', userId).maybeSingle();

    if (data != null) {
      if (mounted) {
        setState(() {
          _isProfileComplete = true;
        });
      }
      _fetchAppointments();
    } else {
      if (mounted) {
        setState(() {
          _isProfileComplete = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAppointments() async {
    try {
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
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ UPDATED LOCATION FUNCTION (Web-Safe)
  Future<void> _fillCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Location services are disabled.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied)
          throw 'Location permissions are denied';
      }

      LocationSettings locationSettings;
      if (kIsWeb) {
        // Web: Use lower accuracy to ensure success
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.low,
        );
      } else {
        // Mobile: High accuracy with timeout
        locationSettings = const LocationSettings(
            accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10));
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latController.text = position.latitude.toString();
        _lngController.text = position.longitude.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Coordinates Auto-filled!"),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("GPS Error: $e")));
    }
  }

  Future<void> _saveProfile() async {
    if (_latController.text.isEmpty || _lngController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please enter coordinates or click 'Get Location'")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      final start =
          "${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00";
      final end =
          "${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00";

      await _supabase.from('doctors').insert({
        'id': userId,
        'specialty': _specialtyController.text,
        'clinic_name': _clinicNameController.text,
        'clinic_address': _addressController.text,
        'work_start_time': start,
        'work_end_time': end,
        'location': 'POINT(${_lngController.text} ${_latController.text})',
      });

      _checkDoctorProfile();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart)
          _startTime = picked;
        else
          _endTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (!_isProfileComplete) {
      return Scaffold(
        appBar: AppBar(title: const Text("Complete Doctor Profile")),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Clinic Details",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(
                  controller: _clinicNameController,
                  decoration: const InputDecoration(labelText: "Clinic Name")),
              const SizedBox(height: 10),
              TextField(
                  controller: _specialtyController,
                  decoration: const InputDecoration(
                      labelText: "Specialty (e.g. Dentist)")),
              const SizedBox(height: 10),
              TextField(
                  controller: _addressController,
                  decoration:
                      const InputDecoration(labelText: "Clinic Address")),
              const SizedBox(height: 20),
              const Text("Location Coordinates",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Text("Click 'Get Location' or enter manually.",
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Latitude"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _lngController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Longitude"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.my_location),
                label: const Text("Get Current Location"),
                onPressed: _fillCurrentLocation,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[50],
                    foregroundColor: Colors.blue),
              ),
              const SizedBox(height: 20),
              const Text("Working Hours",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                      child: TextButton(
                          onPressed: () => _pickTime(true),
                          child: Text("Start: ${_startTime.format(context)}"))),
                  Expanded(
                      child: TextButton(
                          onPressed: () => _pickTime(false),
                          child: Text("End: ${_endTime.format(context)}"))),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  child: const Text("SAVE PROFILE"),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Doctor Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _supabase.auth.signOut();
            },
          )
        ],
      ),
      body: _appointments.isEmpty
          ? const Center(child: Text("No upcoming appointments"))
          : ListView.builder(
              itemCount: _appointments.length,
              itemBuilder: (context, index) {
                final appt = _appointments[index];
                final patientName = appt['profiles']['full_name'] ?? "Unknown";
                final time = appt['start_time'].toString().substring(0, 5);

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(patientName),
                    subtitle: Text("${appt['appointment_date']} at $time"),
                    trailing: const Chip(
                        label: Text("Confirmed"),
                        backgroundColor: Colors.greenAccent),
                  ),
                );
              },
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:medislots/widgets/appointment_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientAppointmentsScreen extends StatefulWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  State<PatientAppointmentsScreen> createState() =>
      _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState extends State<PatientAppointmentsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _myAppointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyAppointments();
  }

  Future<void> _fetchMyAppointments() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('appointments')
        .select(
            '*, doctors(id, clinic_name, specialty, profiles(full_name))') // Fetch doctor details
        .eq('patient_id', userId)
        .order('appointment_date', ascending: false);

    if (mounted) {
      setState(() {
        _myAppointments = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Appointments")),
      backgroundColor: Colors.grey[50], // Light background for contrast
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myAppointments.isEmpty
              ? const Center(
                  child: Text("No bookings yet.",
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 10),
                  itemCount: _myAppointments.length,
                  itemBuilder: (context, index) {
                    final appt = _myAppointments[index];

                    // ✅ Use the Clean Reusable Card
                    return AppointmentCard(
                      appointment: appt,
                      isDoctor:
                          false, // 👈 Important: Tells card to show Doctor Name
                      // No accept/reject callbacks needed for patients
                    );
                  },
                ),
    );
  }
}

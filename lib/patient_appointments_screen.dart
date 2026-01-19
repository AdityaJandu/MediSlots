import 'package:flutter/material.dart';
import 'package:medislots/chat_screen.dart';
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
        .select('*, doctors(clinic_name, specialty, profiles(full_name))')
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myAppointments.isEmpty
              ? const Center(child: Text("No bookings yet."))
              : ListView.builder(
                  itemCount: _myAppointments.length,
                  itemBuilder: (context, index) {
                    final appt = _myAppointments[index];
                    final doctorProfile = appt['doctors']['profiles'] ?? {};
                    final doctorName =
                        doctorProfile['full_name'] ?? 'Unknown Doctor';
                    final clinic = appt['doctors']['clinic_name'] ?? 'Clinic';
                    final status = appt['status'] ?? 'pending';

                    Color statusColor = Colors.orange;
                    if (status == 'confirmed') statusColor = Colors.green;
                    if (status == 'rejected') statusColor = Colors.red;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade50,
                            child: const Icon(Icons.local_hospital,
                                color: Colors.blue)),
                        title: Text(doctorName),
                        subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(clinic),
                              Text(
                                  "${appt['appointment_date']} • ${appt['start_time'].toString().substring(0, 5)}"),
                            ]),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Status Icon
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                    status == 'confirmed'
                                        ? Icons.check_circle
                                        : Icons.hourglass_empty,
                                    color: statusColor),
                                Text(status,
                                    style: TextStyle(
                                        fontSize: 10, color: statusColor))
                              ],
                            ),
                            const SizedBox(width: 10),

                            // 💬 CHAT BUTTON
                            IconButton(
                              icon: const Icon(Icons.chat, color: Colors.blue),
                              onPressed: () {
                                // Patient talks to Doctor
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => ChatScreen(
                                            otherUserId: appt['doctor_id'],
                                            otherUserName: doctorName)));
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

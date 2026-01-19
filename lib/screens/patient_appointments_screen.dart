import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PatientAppointmentsScreen extends StatefulWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  State<PatientAppointmentsScreen> createState() =>
      _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState extends State<PatientAppointmentsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // 📂 Data Stores
  List<Map<String, dynamic>> _todayAppointments = [];
  List<Map<String, dynamic>> _futureAppointments = [];
  List<Map<String, dynamic>> _pastAppointments = [];

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    final userId = _supabase.auth.currentUser!.id;

    try {
      final response = await _supabase
          .from('appointments')
          .select(
              '*, doctors(clinic_name, clinic_address, profiles(full_name))')
          .eq('patient_id', userId)
          .order('appointment_date', ascending: false);

      final List<Map<String, dynamic>> data =
          List<Map<String, dynamic>>.from(response);
      _categorizeAppointments(data);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _categorizeAppointments(List<Map<String, dynamic>> allAppointments) {
    _todayAppointments.clear();
    _futureAppointments.clear();
    _pastAppointments.clear();

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    for (var appt in allAppointments) {
      final dateStr = appt['appointment_date'];
      final timeStr = appt['start_time'];
      final dateTime = DateTime.parse("$dateStr $timeStr");

      if (dateTime.isBefore(now)) {
        _pastAppointments.add(appt);
      } else {
        if (dateStr == todayStr) {
          _todayAppointments.add(appt);
        } else {
          _futureAppointments.add(appt);
        }
      }
    }

    // 🔢 Sorting Logic
    // Today & Future: Closest time first
    _todayAppointments
        .sort((a, b) => a['start_time'].compareTo(b['start_time']));
    _futureAppointments.sort((a, b) {
      int dateComp = a['appointment_date'].compareTo(b['appointment_date']);
      return (dateComp == 0)
          ? a['start_time'].compareTo(b['start_time'])
          : dateComp;
    });
    // History: Newest first
    _pastAppointments.sort((a, b) {
      int dateComp = b['appointment_date'].compareTo(a['appointment_date']);
      return (dateComp == 0)
          ? b['start_time'].compareTo(a['start_time'])
          : dateComp;
    });
  }

  // 🎨 Status Colors
  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green.shade100;
      case 'rejected':
        return Colors.red.shade100;
      default:
        return Colors.orange.shade100;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green.shade800;
      case 'rejected':
        return Colors.red.shade800;
      default:
        return Colors.orange.shade800;
    }
  }

  // 🏗️ List Builder
  Widget _buildAppointmentList(List<Map<String, dynamic>> appointments,
      String emptyMsg, IconData emptyIcon) {
    if (appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(emptyMsg,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appt = appointments[index];
        final doctor = appt['doctors'];
        final doctorName =
            doctor?['profiles']?['full_name'] ?? 'Unknown Doctor';
        final status = appt['status'];
        final timeDisplay =
            "${appt['start_time'].toString().substring(0, 5)} - ${appt['end_time'].toString().substring(0, 5)}";
        final dateDisplay = DateFormat('MMM d, y')
            .format(DateTime.parse(appt['appointment_date']));

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(doctorName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getStatusTextColor(status)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 16, color: Colors.teal.shade300),
                    const SizedBox(width: 8),
                    Text(dateDisplay,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(width: 16),
                    Icon(Icons.access_time,
                        size: 16, color: Colors.teal.shade300),
                    const SizedBox(width: 8),
                    Text(timeDisplay,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 16, color: Colors.grey.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        doctor?['clinic_name'] ?? 'Clinic',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Number of Tabs
      child: Scaffold(
        appBar: AppBar(
          title: const Text("My Appointments"),
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.teal,
            indicatorWeight: 3,
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: "Today"),
              Tab(text: "Upcoming"),
              Tab(text: "History"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Tab 1: Today
                  _buildAppointmentList(_todayAppointments,
                      "No appointments today", Icons.event_available),

                  // Tab 2: Upcoming
                  _buildAppointmentList(_futureAppointments,
                      "No upcoming appointments", Icons.event_note),

                  // Tab 3: History
                  _buildAppointmentList(
                      _pastAppointments, "No past appointments", Icons.history),
                ],
              ),
      ),
    );
  }
}

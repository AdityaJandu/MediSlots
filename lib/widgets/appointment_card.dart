import 'package:flutter/material.dart';
import '../screens/chat_screen.dart'; // Import your chat screen

class AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final bool isDoctor; // True if Doctor is viewing, False if Patient
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.isDoctor,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    // Extract Data safely
    final status = appointment['status'] ?? 'pending';
    final date = appointment['appointment_date'];

    // Time formatting (remove seconds if present)
    String time = appointment['start_time'].toString();
    if (time.length > 5) time = time.substring(0, 5);

    // Dynamic Names based on who is viewing
    final otherName = isDoctor
        ? (appointment['profiles']?['full_name'] ?? "Unknown Patient")
        : (appointment['doctors']?['profiles']?['full_name'] ??
            "Unknown Doctor");

    final otherId =
        isDoctor ? appointment['patient_id'] : appointment['doctor_id'];

    // Status Colors
    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.hourglass_empty;
    if (status == 'confirmed') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (status == 'rejected') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1️⃣ TOP ROW: Icon + Name + Chat
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Icon(Icons.person, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        otherName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        isDoctor ? "Patient" : "Doctor",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ChatScreen(
                                  otherUserId: otherId,
                                  otherUserName: otherName,
                                )));
                  },
                  icon: const Icon(Icons.chat_bubble_outline,
                      color: Colors.blueGrey),
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade50),
                )
              ],
            ),
            const Divider(height: 24),

            // 2️⃣ MIDDLE ROW: Date & Time Info
            Row(
              children: [
                _infoBadge(Icons.calendar_today, date),
                const SizedBox(width: 12),
                _infoBadge(Icons.access_time, time),
                const Spacer(),

                // Status Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 3️⃣ BOTTOM ROW: Actions (Only for Doctor + Pending)
            if (isDoctor && status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text("Reject"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009688),
                      ),
                      child: const Text("Accept"),
                    ),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

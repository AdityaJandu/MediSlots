import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class BookingScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const BookingScreen(
      {super.key, required this.doctorId, required this.doctorName});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedSlot;
  bool _isLoading = false;

  // 🕒 Time Slot Generator (30-minute intervals)
  List<String> _generateTimeSlots() {
    List<String> slots = [];
    final now = DateTime.now();

    // Define working hours (e.g., 9:00 AM to 5:00 PM)
    // We use a temporary DateTime object to manipulate the time easily
    DateTime startTime = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day, 9, 0);
    DateTime endTime = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day, 17, 0);

    // Loop until we reach the end time
    while (startTime.isBefore(endTime)) {
      DateTime slotEnd = startTime.add(const Duration(minutes: 30));

      // 🛡️ Logic: If date is TODAY, skip slots that have already passed
      if (_selectedDate.year == now.year &&
          _selectedDate.month == now.month &&
          _selectedDate.day == now.day) {
        // If the START of the slot is in the past, skip it
        if (startTime.isBefore(now)) {
          startTime = slotEnd; // Move to next slot
          continue;
        }
      }

      // Format: "09:00 - 09:30"
      String startStr = DateFormat('HH:mm').format(startTime);
      String endStr = DateFormat('HH:mm').format(slotEnd);

      slots.add("$startStr - $endStr");

      // Increment loop by 30 minutes for the next slot
      startTime = slotEnd;
    }
    return slots;
  }

  Future<void> _bookAppointment() async {
    if (_selectedSlot == null) return;
    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // Split string "09:00 - 09:30"
      final timeParts = _selectedSlot!.split(' - ');
      final startTime = timeParts[0]; // "09:00"
      final endTime = timeParts[1]; // "09:30"

      await Supabase.instance.client.from('appointments').insert({
        'doctor_id': widget.doctorId,
        'patient_id': userId,
        'appointment_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'start_time': "$startTime:00", // Add seconds for Time format
        'end_time': "$endTime:00",
        'status': 'pending'
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Booking Request Sent!"),
            backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = _generateTimeSlots();

    return Scaffold(
      appBar: AppBar(title: Text("Book with ${widget.doctorName}")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select Date",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null)
                  setState(() {
                    _selectedDate = picked;
                    _selectedSlot = null;
                  });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 10),
                    Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Available Slots (30 mins)",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            slots.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("No slots available.",
                        style: TextStyle(color: Colors.red)))
                : Wrap(
                    spacing: 10,
                    runSpacing: 10, // Adds vertical space between rows
                    children: slots.map((slot) {
                      return ChoiceChip(
                        label: Text(slot,
                            style: const TextStyle(
                                fontSize: 12)), // Smaller text to fit
                        selected: _selectedSlot == slot,
                        onSelected: (selected) => setState(
                            () => _selectedSlot = selected ? slot : null),
                      );
                    }).toList(),
                  ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_selectedSlot == null || _isLoading)
                    ? null
                    : _bookAppointment,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text("CONFIRM BOOKING"),
              ),
            ),
            const SizedBox(
              height: 50,
            ),
          ],
        ),
      ),
    );
  }
}

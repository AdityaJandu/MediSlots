import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class BookingScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final int slotDuration; // e.g., 30 minutes
  final String startTime; // e.g., "09:00:00"
  final String endTime; // e.g., "17:00:00"

  const BookingScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
    this.slotDuration = 30,
    this.startTime = "09:00:00",
    this.endTime = "17:00:00",
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _selectedDate = DateTime.now();
  List<String> _bookedTimes = []; // Times that are already taken
  String? _selectedTimeSlot;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchBookedSlots();
  }

  // 1. Fetch existing appointments for the selected date
  Future<void> _fetchBookedSlots() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final response = await Supabase.instance.client
        .from('appointments')
        .select('start_time')
        .eq('doctor_id', widget.doctorId)
        .eq('appointment_date', dateStr);

    setState(() {
      _bookedTimes = (response as List)
          .map((e) => e['start_time']
              .toString()
              .substring(0, 5)) // Format "09:30:00" -> "09:30"
          .toList();
      _selectedTimeSlot = null; // Reset selection on date change
    });
  }

  // 2. Generate list of time slots (e.g., 09:00, 09:30...)
  List<String> _generateTimeSlots() {
    List<String> slots = [];

    // Parse start/end times
    DateTime current = DateFormat("HH:mm:ss").parse(widget.startTime);
    DateTime end = DateFormat("HH:mm:ss").parse(widget.endTime);

    // Loop to add slots
    while (current.isBefore(end)) {
      String formattedTime = DateFormat("HH:mm").format(current);
      slots.add(formattedTime);
      current = current.add(Duration(minutes: widget.slotDuration));
    }
    return slots;
  }

  // 3. Confirm Booking
  Future<void> _confirmBooking() async {
    if (_selectedTimeSlot == null) return;

    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;

    try {
      // Calculate End Time (Start + Duration)
      DateTime start = DateFormat("HH:mm").parse(_selectedTimeSlot!);
      DateTime end = start.add(Duration(minutes: widget.slotDuration));
      String endTimeStr = DateFormat("HH:mm:ss").format(end);
      String startTimeStr = "$_selectedTimeSlot:00";

      // Attempt Insert
      await Supabase.instance.client.from('appointments').insert({
        'doctor_id': widget.doctorId,
        'patient_id': user!.id,
        'appointment_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'start_time': startTimeStr,
        'end_time': endTimeStr,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Booking Confirmed!"),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back to Home
      }
    } on PostgrestException catch (e) {
      // 4. Handle Conflicts (The Unique Constraint we added in SQL)
      if (e.code == '23505') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("This slot was just taken! Please pick another."),
              backgroundColor: Colors.orange),
        );
        _fetchBookedSlots(); // Refresh UI to show the new taken slot
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: ${e.message}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = _generateTimeSlots();

    return Scaffold(
      appBar: AppBar(title: Text("Book ${widget.doctorName}")),
      body: Column(
        children: [
          // Date Picker
          CalendarDatePicker(
            initialDate: _selectedDate,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 30)),
            onDateChanged: (newDate) {
              setState(() => _selectedDate = newDate);
              _fetchBookedSlots();
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Available Slots",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),

          // Time Slots Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10),
              itemCount: slots.length,
              itemBuilder: (context, index) {
                final time = slots[index];
                final isBooked = _bookedTimes.contains(time);
                final isSelected = _selectedTimeSlot == time;

                return GestureDetector(
                  onTap: isBooked
                      ? null
                      : () => setState(() => _selectedTimeSlot = time),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isBooked
                          ? Colors.grey[300]
                          : (isSelected ? Colors.blue : Colors.white),
                      border: Border.all(
                          color: isBooked ? Colors.grey : Colors.blue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      time,
                      style: TextStyle(
                        color: isBooked
                            ? Colors.grey
                            : (isSelected ? Colors.white : Colors.black),
                        decoration:
                            isBooked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Confirm Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedTimeSlot == null || _isLoading
                    ? null
                    : _confirmBooking,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text("Confirm Appointment"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

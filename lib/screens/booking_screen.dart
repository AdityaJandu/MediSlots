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
  bool _isFetchingSlots = true; // Start true to show loading initially

  // 🕒 Dynamic Working Hours (Default to 9-5 just in case)
  TimeOfDay _openTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 17, minute: 0);

  List<String> _bookedTimes = [];

  @override
  void initState() {
    super.initState();
    _fetchDoctorDetails(); // 1. Get Doctor's actual hours first
  }

  // 🆕 Fetch Doctor's Open/Close times
  Future<void> _fetchDoctorDetails() async {
    try {
      final data = await Supabase.instance.client
          .from('doctors')
          .select('work_start_time, work_end_time')
          .eq('id', widget.doctorId)
          .single();

      if (mounted) {
        setState(() {
          if (data['work_start_time'] != null) {
            final t = data['work_start_time'].toString().split(':');
            _openTime =
                TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
          }
          if (data['work_end_time'] != null) {
            final t = data['work_end_time'].toString().split(':');
            _closeTime =
                TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
          }
        });
        // After getting hours, fetch booked slots
        _fetchBookedSlots();
      }
    } catch (e) {
      debugPrint("Error fetching doctor details: $e");
      _fetchBookedSlots(); // Proceed even if details fail (uses default 9-5)
    }
  }

  Future<void> _fetchBookedSlots() async {
    setState(() => _isFetchingSlots = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final response = await Supabase.instance.client
        .from('appointments')
        .select('start_time')
        .eq('doctor_id', widget.doctorId)
        .eq('appointment_date', dateStr)
        .neq('status', 'rejected');

    final List<String> loadedTimes = [];
    for (var record in response) {
      String time = record['start_time'].toString();
      // Format "09:00:00" -> "09:00"
      if (time.length > 5) time = time.substring(0, 5);
      loadedTimes.add(time);
    }

    if (mounted) {
      setState(() {
        _bookedTimes = loadedTimes;
        _isFetchingSlots = false;
        _selectedSlot = null;
      });
    }
  }

  List<String> _generateTimeSlots() {
    List<String> slots = [];
    final now = DateTime.now();

    // 🆕 Use the Doctor's specific Open/Close times
    DateTime startTime = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _openTime.hour, _openTime.minute);

    DateTime endTime = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _closeTime.hour, _closeTime.minute);

    while (startTime.isBefore(endTime)) {
      DateTime slotEnd = startTime.add(const Duration(minutes: 30));

      // Don't go past the closing time
      if (slotEnd.isAfter(endTime)) break;

      // Check past time (if today)
      if (_selectedDate.year == now.year &&
          _selectedDate.month == now.month &&
          _selectedDate.day == now.day) {
        if (startTime.isBefore(now)) {
          startTime = slotEnd;
          continue;
        }
      }

      String startStr = DateFormat('HH:mm').format(startTime);
      String endStr = DateFormat('HH:mm').format(slotEnd);

      slots.add("$startStr - $endStr");
      startTime = slotEnd;
    }
    return slots;
  }

  Future<void> _bookAppointment() async {
    if (_selectedSlot == null) return;
    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final timeParts = _selectedSlot!.split(' - ');

      await Supabase.instance.client.from('appointments').insert({
        'doctor_id': widget.doctorId,
        'patient_id': userId,
        'appointment_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'start_time': "${timeParts[0]}:00",
        'end_time': "${timeParts[1]}:00",
        'status': 'pending'
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Booking Request Sent!"),
            backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = _generateTimeSlots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Book Appointment"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.teal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Booking with",
                    style: TextStyle(color: Colors.white70)),
                Text(widget.doctorName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                // 🆕 Show Working Hours
                Text(
                    "Hours: ${_openTime.format(context)} - ${_closeTime.format(context)}",
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _fetchBookedSlots();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, color: Colors.teal),
                          const SizedBox(width: 10),
                          Text(
                              DateFormat('EEEE, d MMMM yyyy')
                                  .format(_selectedDate),
                              style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text("Available Slots",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),

                  _isFetchingSlots
                      ? const Center(child: CircularProgressIndicator())
                      : slots.isEmpty
                          ? const Text("No slots available for this date.",
                              style: TextStyle(color: Colors.red))
                          : GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 2.5,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: slots.length,
                              itemBuilder: (context, index) {
                                final slot = slots[index];
                                final start = slot.split(' - ')[0];
                                final isBooked = _bookedTimes.contains(start);
                                final isSelected = _selectedSlot == slot;

                                return InkWell(
                                  onTap: isBooked
                                      ? null
                                      : () =>
                                          setState(() => _selectedSlot = slot),
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isBooked
                                          ? Colors.grey[200]
                                          : (isSelected
                                              ? Colors.teal
                                              : Colors.white),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: isBooked
                                              ? Colors.grey[300]!
                                              : (isSelected
                                                  ? Colors.teal
                                                  : Colors.grey.shade300)),
                                    ),
                                    child: Text(
                                      isBooked ? "Booked" : slot,
                                      style: TextStyle(
                                        color: isBooked
                                            ? Colors.grey
                                            : (isSelected
                                                ? Colors.white
                                                : Colors.black87),
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 12,
                                        decoration: isBooked
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: (_selectedSlot == null || _isLoading)
                    ? null
                    : _bookAppointment,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("CONFIRM BOOKING"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

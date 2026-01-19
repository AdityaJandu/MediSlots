import 'package:flutter/material.dart';
import 'package:medislots/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

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
  bool _isFetchingSlots = true;

  // Doctor Hours (Defaults)
  TimeOfDay _openTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 17, minute: 0);

  List<String> _bookedTimes = [];

  @override
  void initState() {
    super.initState();
    NotificationService().requestPermissions();
    _fetchDoctorDetails();
  }

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
        _fetchBookedSlots();
      }
    } catch (e) {
      debugPrint("Error fetching doctor details: $e");
      _fetchBookedSlots();
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

    DateTime currentSlot = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _openTime.hour, _openTime.minute);

    DateTime closingTime = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _closeTime.hour, _closeTime.minute);

    while (currentSlot.isBefore(closingTime)) {
      DateTime slotEnd = currentSlot.add(const Duration(minutes: 30));

      if (slotEnd.isAfter(closingTime)) break;

      if (_selectedDate.year == now.year &&
          _selectedDate.month == now.month &&
          _selectedDate.day == now.day) {
        if (currentSlot.isBefore(now)) {
          currentSlot = slotEnd;
          continue;
        }
      }

      String startStr = DateFormat('HH:mm').format(currentSlot);
      String endStr = DateFormat('HH:mm').format(slotEnd);
      slots.add("$startStr - $endStr");
      currentSlot = slotEnd;
    }
    return slots;
  }

  Future<void> _bookAppointment() async {
    if (_selectedSlot == null) return;
    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final timeParts = _selectedSlot!.split(' - ');
      final startStr = "${timeParts[0]}:00";

      final response = await Supabase.instance.client
          .from('appointments')
          .insert({
            'doctor_id': widget.doctorId,
            'patient_id': userId,
            'appointment_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
            'start_time': startStr,
            'end_time': "${timeParts[1]}:00",
            'status': 'pending'
          })
          .select()
          .single();

      try {
        final t = timeParts[0].split(':');
        final appointmentDateTime = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            int.parse(t[0]),
            int.parse(t[1]));

        await NotificationService().scheduleReminder(
            response['id'].hashCode, widget.doctorName, appointmentDateTime);
      } catch (e) {
        debugPrint("Notification Error: $e");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Booking Request Sent!"),
            backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 💬 Navigate to Chat
  void _openChat() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChatScreen(
                otherUserId: widget.doctorId,
                otherUserName: widget.doctorName)));
  }

  @override
  Widget build(BuildContext context) {
    final slots = _generateTimeSlots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Book Appointment"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // 💬 CHAT BUTTON (Direct Access)
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: "Message Doctor",
            onPressed: _openChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // Doctor Info Header
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                        "${_openTime.format(context)} - ${_closeTime.format(context)}",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                  ],
                )
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
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Slots Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Available Slots",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      // 💡 Small tip for emergency
                      if (slots.isEmpty && !_isFetchingSlots)
                        TextButton.icon(
                          onPressed: _openChat,
                          icon: const Icon(Icons.warning_amber_rounded,
                              size: 16, color: Colors.orange),
                          label: const Text("Emergency? Chat",
                              style: TextStyle(
                                  color: Colors.orange, fontSize: 12)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        )
                    ],
                  ),

                  const SizedBox(height: 12),

                  _isFetchingSlots
                      ? const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : slots.isEmpty
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                children: [
                                  Icon(Icons.event_busy,
                                      size: 40, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  Text("No slots available.",
                                      style: TextStyle(
                                          color: Colors.grey.shade600)),
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: _openChat,
                                    icon: const Icon(Icons.chat),
                                    label: const Text("Request Slot via Chat"),
                                  )
                                ],
                              ),
                            )
                          : GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 2.2,
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
                                          ? Colors.grey[100]
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text("CONFIRM BOOKING",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

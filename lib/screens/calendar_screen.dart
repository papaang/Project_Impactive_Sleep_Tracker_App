import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models.dart';
import '../log_service.dart';
import 'event_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final LogService _logService = LogService();
  Map<DateTime, DailyLog> _logsByDate = {};
  DateTime _focusedDay = DateTime.now();
  late DateTime _selectedDay;
  Map<String, Category> _dayTypes = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime.utc(now.year, now.month, now.day);
    _loadAllLogs();
    _loadDayTypes();
  }

  Future<void> _loadAllLogs() async {
    final logs = await _logService.getAllLogs();
    setState(() {
      _logsByDate = logs;
    });
  }

  Future<void> _loadDayTypes() async {
    final types = await CategoryManager().getCategories('day_types');
    setState(() {
      _dayTypes = {for (var t in types) t.id: t};
    });
  }

  List<Object> _getEventsForDay(DateTime day) {
    final utcDay = DateTime.utc(day.year, day.month, day.day);
    final log = _logsByDate[utcDay];
    if (log != null && log.dayTypeId != null && _dayTypes.containsKey(log.dayTypeId)) {
      return [_dayTypes[log.dayTypeId]!];
    }
    return [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final utcSelectedDay = DateTime.utc(selectedDay.year, selectedDay.month, selectedDay.day);
    if (!isSameDay(_selectedDay, utcSelectedDay)) {
      setState(() {
        _selectedDay = utcSelectedDay;
        _focusedDay = focusedDay;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventScreen(date: utcSelectedDay),
        ),
      ).then((_) => _loadAllLogs());
    }
  }

  // --- NEW: Custom Month/Year Picker Dialog ---
  Future<void> _showMonthPicker(BuildContext context, DateTime currentFocusedDay) async {
    int selectedYear = currentFocusedDay.year;
    
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setStateDialog(() {
                        if (selectedYear > 2020) selectedYear--;
                      });
                    },
                  ),
                  Text(
                    selectedYear.toString(), 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setStateDialog(() {
                        if (selectedYear < DateTime.now().year + 5) selectedYear++;
                      });
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: 300,
                height: 300,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final monthIndex = index + 1;
                    final isSelected = selectedYear == currentFocusedDay.year && monthIndex == currentFocusedDay.month;
                    
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context, DateTime(selectedYear, monthIndex));
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.indigo : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected ? null : Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          DateFormat.MMM().format(DateTime(selectedYear, monthIndex)),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() {
        _focusedDay = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        centerTitle: true,
      ),
      body: Card(
        margin: const EdgeInsets.all(12.0),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // Custom Header for clearer interaction
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                        });
                      },
                    ),
                    InkWell(
                      onTap: () => _showMonthPicker(context, _focusedDay),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          // Add a subtle background color on tap/hover logic is handled by InkWell splash, 
                          // but we can add a default subtle border to hint interactivity
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('MMMM yyyy').format(_focusedDay),
                              style: const TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo, // Use primary color to hint link/action
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, color: Colors.indigo),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                        });
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(
                      DateTime.now().year + 5, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.month,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: _onDaySelected,
                  eventLoader: _getEventsForDay,
                  
                  rowHeight: 65.0, 
                  

           
           headerVisible: false,

            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isNotEmpty) {
                  final category = events[0] as Category;
                  return Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: category.color,
                      shape: BoxShape.circle,
                      border: Border.all( //add border for better visibility
                         color: Colors.white, 
                           width: 1.0,
                    ),
                    ),
                  );
                }
                return null;
              },
            ),
            calendarStyle: CalendarStyle(
              // Slightly reduced margin to ensure the visible target is larger within the increased row height
              outsideDaysVisible: false,// Hide days from other months
              cellMargin: const EdgeInsets.all(6.0),
              todayDecoration: BoxDecoration(
                color: Colors.deepOrange[300],
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.indigo[600],
                shape: BoxShape.circle,
              ),
              // Increased font size for date numbers
              defaultTextStyle: const TextStyle(fontSize: 20.0),
              weekendTextStyle: const TextStyle(fontSize: 20.0, color: Colors.redAccent),
              selectedTextStyle: const TextStyle(fontSize: 20.0, color: Colors.white),
              todayTextStyle: const TextStyle(fontSize: 20.0, color: Colors.white),
              outsideTextStyle: const TextStyle(fontSize: 2.0, color: Colors.grey),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              headerPadding: EdgeInsets.symmetric(vertical: 16.0), // More breathing room in header
              titleTextStyle: TextStyle(
                fontSize: 20.0, // Slightly larger title
                fontWeight: FontWeight.w600,
              ),
            ),
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
          },
                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
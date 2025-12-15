import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calendar'),
        centerTitle: true,
      ),
      body: Card(
        margin: const EdgeInsets.all(12.0),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(
                DateTime.now().year, DateTime.now().month, DateTime.now().day),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: _onDaySelected,
            eventLoader: _getEventsForDay,
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isNotEmpty) {
                  final category = events[0] as Category;
                  return Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: category.color,
                      shape: BoxShape.circle,
                    ),
                  );
                }
                return null;
              },
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.deepOrange[300],
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.indigo[600],
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
        ),
      ),
    );
  }
}

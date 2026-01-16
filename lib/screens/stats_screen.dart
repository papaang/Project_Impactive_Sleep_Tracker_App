import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../log_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final LogService _logService = LogService();

  // Data: Date -> Hours of ACTUAL sleep (split correctly across days)
  Map<DateTime, double> _weeklySleepData = {};
  bool _isLoading = true;

  // Date range
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isCustom = false;

  // Statistics data
  List<double> _dailySleepHours = [];
  List<double> _sessionSleepHours = [];
  List<DateTime> _bedTimes = [];
  List<DateTime> _riseTimes = [];

  @override
  void initState() {
    super.initState();
    // Set default to past 7 days
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _startDate = today.subtract(const Duration(days: 6));
    _endDate = today;
    _processSleepData();
  }

  String _formatHoursToHHhMM(double hours) {
    if (hours < 0) hours = 0;
    int h = hours.floor();
    int m = ((hours - h) * 60).round();
    return '${h.toString().padLeft(2, '0')}h${m.toString().padLeft(2, '0')}';
  }

  String _formatTimeFromHours(double hours) {
    if (hours < 0) hours = 0;
    int h = hours.floor();
    int m = ((hours - h) * 60).round();
    DateTime dt = DateTime(2023, 1, 1, h, m);
    return DateFormat('h:mm a').format(dt);
  }

  double _calculateMean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _calculateMedian(List<double> values) {
    if (values.isEmpty) return 0.0;
    List<double> sorted = List.from(values)..sort();
    int n = sorted.length;
    if (n % 2 == 0) {
      return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
    } else {
      return sorted[n ~/ 2];
    }
  }

  double _calculateStdDev(List<double> values) {
    if (values.length < 2) return 0.0;
    double mean = _calculateMean(values);
    double variance = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / (values.length - 1);
    return sqrt(variance);
  }

  double _calculateTimeMean(List<DateTime> times) {
    if (times.isEmpty) return 0.0;
    List<double> minutesSinceMidnight = times.map((t) => t.hour * 60.0 + t.minute).toList();
    return _calculateMean(minutesSinceMidnight) / 60.0; // Convert to hours
  }

  Future<void> _selectDateRange() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: isDark
              ? Theme.of(context).copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: Colors.indigo.shade600,
                    onPrimary: Colors.white,
                    secondary: Colors.indigo.shade400,
                    surface: Colors.grey[800]!,
                    onSurface: Colors.white,
                  ),
                )
              : Theme.of(context),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final days = picked.end.difference(picked.start).inDays + 1;
      if (days > 32) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date range under 1 month.')),
        );
      } else {
        setState(() {
          _startDate = picked.start;
          _endDate = picked.end;
          _isCustom = true;
        });
        _processSleepData();
      }
    }
  }

  Future<void> _processSleepData() async {
    setState(() => _isLoading = true);

    // Use the selected date range
    final rangeStart = _startDate;
    final rangeEnd = _endDate;
    final days = rangeEnd.difference(rangeStart).inDays + 1; // inclusive

    // We need to load logs starting from one day BEFORE the range,
    // because a sleep session starting yesterday might spill into today (the range start).
    // Also load one day AFTER the range, because a sleep session starting on the last day might spill into the next day.
    final loadStart = rangeStart.subtract(const Duration(days: 1));

    // Helper map to aggregate hours per calendar date
    Map<DateTime, double> sleepBuckets = {};

    // Initialize buckets for the display range (0.0 hours default)
    for (int i = 0; i < days; i++) {
      final d = rangeStart.add(Duration(days: i));
      sleepBuckets[d] = 0.0;
    }

    // Lists for statistics
    List<double> dailySleepHours = [];
    List<double> sessionSleepHours = [];
    List<DateTime> bedTimes = [];
    List<DateTime> riseTimes = [];

    // Load logs for the extended range (days + 2 total: before, during, after)
    for (int i = 0; i < days + 2; i++) {
      final date = loadStart.add(Duration(days: i));
      final log = await _logService.getDailyLog(date);

      for (var entry in log.sleepLog) {
        DateTime start = entry.fellAsleepTime;
        DateTime end = entry.wakeTime;

        // Safety check
        if (end.isBefore(start)) continue;

        // Calculate total raw duration in minutes
        int totalMinutes = end.difference(start).inMinutes;
        if (totalMinutes == 0) continue;

        // Check if sleep spans across midnight (dates are different)
        DateTime startDate = DateTime(start.year, start.month, start.day);
        DateTime endDate = DateTime(end.year, end.month, end.day);

        if (startDate.isAtSameMomentAs(endDate)) {
          // SIMPLE CASE: Same day
          // Total sleep = Duration - AwakeTime
          double hours = (totalMinutes - entry.awakeDurationMinutes) / 60.0;
          if (hours < 0) hours = 0;

          if (sleepBuckets.containsKey(startDate)) {
            sleepBuckets[startDate] = (sleepBuckets[startDate] ?? 0) + hours;
          }

          // Collect session data only if session starts in the displayed range
          if (startDate.isAfter(rangeStart.subtract(const Duration(days: 1))) &&
              startDate.isBefore(rangeEnd.add(const Duration(days: 1)))) {
            sessionSleepHours.add(hours);
            bedTimes.add(entry.bedTime);
            riseTimes.add(entry.wakeTime);
          }
        } else {
          // COMPLEX CASE: Spans midnight (e.g. Sat 22:00 to Sun 11:30)

          // 1. Calculate duration on Day 1 (Start -> Midnight)
          // Midnight of the next day is endDate's 00:00 if strictly next day,
          // but let's be precise: Midnight relative to start.
          DateTime midnight = DateTime(startDate.year, startDate.month, startDate.day).add(const Duration(days: 1));

          int minsDay1 = midnight.difference(start).inMinutes;
          // 2. Calculate duration on Day 2 (Midnight -> End)
          // Note: If spans multiple days (rare), this simple split puts rest in day 2.
          int minsDay2 = end.difference(midnight).inMinutes;

          // 3. Proportional Awake Time Subtraction
          // If I was awake 30 mins total, subtract proportionally from Day 1 and Day 2 based on length
          double ratioDay1 = minsDay1 / totalMinutes;
          double ratioDay2 = minsDay2 / totalMinutes;

          double awakeDay1 = entry.awakeDurationMinutes * ratioDay1;
          double awakeDay2 = entry.awakeDurationMinutes * ratioDay2;

          double hoursDay1 = (minsDay1 - awakeDay1) / 60.0;
          double hoursDay2 = (minsDay2 - awakeDay2) / 60.0;

          if (hoursDay1 < 0) hoursDay1 = 0;
          if (hoursDay2 < 0) hoursDay2 = 0;

          // Add to buckets
          if (sleepBuckets.containsKey(startDate)) {
            sleepBuckets[startDate] = (sleepBuckets[startDate] ?? 0) + hoursDay1;
          }
          // endDate typically matches next day, but using midnight date ensures continuity
          DateTime nextDayDate = DateTime(midnight.year, midnight.month, midnight.day);
          if (sleepBuckets.containsKey(nextDayDate)) {
            sleepBuckets[nextDayDate] = (sleepBuckets[nextDayDate] ?? 0) + hoursDay2;
          }

          // Collect session data only if session starts in the displayed range
          if (startDate.isAfter(rangeStart.subtract(const Duration(days: 1))) &&
              startDate.isBefore(rangeEnd.add(const Duration(days: 1)))) {
            sessionSleepHours.add(hoursDay1 + hoursDay2);
            bedTimes.add(entry.bedTime);
            riseTimes.add(entry.wakeTime);
          }
        }
      }
    }

    // Collect daily sleep hours for the range
    for (int i = 0; i < days; i++) {
      final d = rangeStart.add(Duration(days: i));
      dailySleepHours.add(sleepBuckets[d] ?? 0.0);
    }

    if (mounted) {
      setState(() {
        // Sort keys to ensure display order
        _weeklySleepData = Map.fromEntries(
          sleepBuckets.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
        );
        _dailySleepHours = dailySleepHours;
        _sessionSleepHours = sessionSleepHours;
        _bedTimes = bedTimes;
        _riseTimes = riseTimes;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = Colors.indigoAccent;
    final bgBarColor = isDark ? Colors.white10 : Colors.grey[200];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Text(
                        'Sleep Duration',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      if (_isCustom)
                        Text(
                          '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d').format(_endDate)}',
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        )
                      else
                        const Text(
                          '(Past 7 Days)',
                          style: TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Split across midnight (e.g. 23:00-01:00 counts as 1h today, 1h tomorrow)",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 265, // Reduced height to make space for stats
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 14, // Cap Y axis visually
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 2,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: isDark ? Colors.white10 : Colors.grey[400],
                            strokeWidth: 1,
                          ),
                        ),
                        // Moved barTouchData here (correct location)
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => Colors.blueGrey,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                _formatHoursToHHhMM(rod.toY),
                                const TextStyle(color: Colors.white),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < _weeklySleepData.length) {
                                  // Show labels for every 3 days if more than 20 days, every other day if more than 11 days
                                  if (_weeklySleepData.length > 20) {
                                    if (index % 3 != 0) {
                                      return const SizedBox();
                                    }
                                  } else if (_weeklySleepData.length > 11 && index % 2 != 0) {
                                    return const SizedBox();
                                  }
                                  final date = _weeklySleepData.keys.elementAt(index);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          DateFormat('E').format(date),
                                          style: TextStyle(
                                            color: isDark ? Colors.white70 : Colors.grey[600],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('d').format(date),
                                          style: TextStyle(
                                            color: isDark ? Colors.white38 : Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                              reservedSize: 50,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 2,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                return Text(
                                  '${value.toInt()}h',
                                  style: TextStyle(
                                    color: isDark ? Colors.white38 : Colors.grey,
                                    fontSize: 14,
                                  ),
                                );
                              },
                              reservedSize: 28,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: _weeklySleepData.values.toList().asMap().entries.map((entry) {
                          final index = entry.key;
                          final hours = entry.value;

                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: hours,
                                color: barColor,
                                width: _weeklySleepData.length > 20 ? 8 : 16,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(4),
                                ),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: 14, // Background height
                                  color: bgBarColor,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Hours of actual sleep per day',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 18),
                  // Descriptive Statistics
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isCustom
                              ? 'Descriptive Statistics (${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d').format(_endDate)})'
                              : 'Descriptive Statistics (Last 7 Days)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sleep Duration\n(Per Day)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Mean: ${_formatHoursToHHhMM(_calculateMean(_dailySleepHours))}',
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  Text(
                                    'Median: ${_formatHoursToHHhMM(_calculateMedian(_dailySleepHours))}',
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  Text(
                                    'Std Dev: ${_formatHoursToHHhMM(_calculateStdDev(_dailySleepHours))}',
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sleep Duration\n(Per Session)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Mean: ${_formatHoursToHHhMM(_calculateMean(_sessionSleepHours))}',
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  Text(
                                    'Median: ${_formatHoursToHHhMM(_calculateMedian(_sessionSleepHours))}',
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  Text(
                                    'Std Dev: ${_formatHoursToHHhMM(_calculateStdDev(_sessionSleepHours))}',
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bed Time\n(Per Session)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Mean: ${_formatTimeFromHours(_calculateTimeMean(_bedTimes))}',
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rise Time\n(Per Session)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Mean: ${_formatTimeFromHours(_calculateTimeMean(_riseTimes))}',
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
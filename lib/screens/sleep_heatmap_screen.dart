import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../log_service.dart';

class SleepHeatmapScreen extends StatefulWidget {
  const SleepHeatmapScreen({super.key});

  @override
  State<SleepHeatmapScreen> createState() => _SleepHeatmapScreenState();
}

class _SleepHeatmapScreenState extends State<SleepHeatmapScreen> {
  final LogService _logService = LogService();

  // Map Date -> Hours Slept
  Map<DateTime, double> _sleepData = {};

  // Range (Initialize with safe defaults to prevent LateInitializationError)
  DateTime _endDate = DateTime.now();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));

  bool _isLoading = true;

  late ScrollController _scrollController;
  int _currentYear = DateTime.now().year;
  int _totalWeeks = 0;

  void _onScroll() {
    double scrollOffset = _scrollController.offset;
    const double rowHeight = 32.0 + 6.0; // cellSize + gap
    int topRow = (scrollOffset / rowHeight).floor();
    int weekIndex = _totalWeeks - 1 - topRow;
    if (weekIndex >= 0 && weekIndex < _totalWeeks) {
      DateTime topWeekStart = _startDate.add(Duration(days: weekIndex * 7));
      setState(() {
        _currentYear = topWeekStart.year;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    // Default range: 1 Year relative to when screen opens
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 365));
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final allLogs = await _logService.getAllLogs();
    
    // Normalize and populate map
    Map<DateTime, double> parsed = {};
    if (allLogs.isNotEmpty) {
      final sortedKeys = allLogs.keys.toList()..sort();
      // Adjust start date to actual data start if older than 1 year (or restrict to 1 year)
      // Ensure we don't go into the future if local time is ahead of logs
      if (sortedKeys.first.isBefore(_startDate)) {
         _startDate = sortedKeys.first;
      }
      
      allLogs.forEach((date, log) {
        final d = DateTime(date.year, date.month, date.day);
        parsed[d] = log.totalSleepHours;
      });
    }

    // Align start date to Monday for proper grid alignment
    while (_startDate.weekday != DateTime.monday) {
      _startDate = _startDate.subtract(const Duration(days: 1));
    }
    
    // Align end date to Sunday
    while (_endDate.weekday != DateTime.sunday) {
      _endDate = _endDate.add(const Duration(days: 1));
    }

    if (mounted) {
      setState(() {
        _sleepData = parsed;
        _isLoading = false;
        _currentYear = _endDate.year;
      });
    }
  }

  String _formatDuration(double hours) {
    int h = hours.floor();
    int m = ((hours - h) * 60).round();
    return "${h}h ${m}m";
  }

  void _onCellTap(DateTime date, double hours) {
    if (hours == 0) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${DateFormat('EEE, MMM d').format(date)}: ${_formatDuration(hours)} sleep"),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getWeekday(int index) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[index];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate Grid Size only when data is ready
    int totalDays = _endDate.difference(_startDate).inDays + 1;
    int totalWeeks = (totalDays / 7).ceil();
    _totalWeeks = totalWeeks;

    // Constants
    const double cellSize = 32.0;
    const double gap = 6.0;
    const double labelWidth = 50.0;
    final double gridHeight = totalWeeks * (cellSize + gap);
    final double gridWidth = 7 * (cellSize + gap) + labelWidth;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Consistency'),
        centerTitle: true,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Builder(
            builder: (context) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Yearly Overview",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Long-term sleep duration trends.\nThis heatmap shows the sleep duration per day over the past year. Tap a block for details.",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // --- LEGEND ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Year: $_currentYear",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Row(
                          children: [
                            const Text("0h", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(width: 8),
                            Container(
                              width: 100, height: 12,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.lightBlueAccent, Colors.greenAccent, Colors.orangeAccent, Colors.redAccent]
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text("10h+", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // --- HEATMAP CONTAINER ---
                    Expanded(
                      child: Column(
                        children: [
                          // X-AXIS LABELS (Weekdays)
                          Row(
                            children: [
                              SizedBox(width: labelWidth + gap * 2.5),
                              for (int d = 0; d < 7; d++) _WeekdayLabel(_getWeekday(d)),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // SCROLLABLE GRID
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              scrollDirection: Axis.vertical,
                              reverse: false, // Start at the top (recent weeks)
                              child: SizedBox(
                                width: gridWidth,
                                height: gridHeight,
                                child: GestureDetector(
                                  onTapUp: (details) {
                                    // Hit Test
                                    double x = details.localPosition.dx - labelWidth - (gap / 2);
                                    double y = details.localPosition.dy;

                                    if (x < 0) return; // Label area tap

                                    int col = (x / (cellSize + gap)).floor();
                                    int row = (y / (cellSize + gap)).floor();

                                    if (col >= 0 && col < 7 && row >= 0 && row < totalWeeks) {
                                      // Since we paint from recent to past, row 0 is most recent
                                      int weekIndex = totalWeeks - 1 - row;
                                      DateTime day = _startDate.add(Duration(days: weekIndex * 7 + col));
                                      double hours = _sleepData[DateTime(day.year, day.month, day.day)] ?? 0;
                                      _onCellTap(day, hours);
                                    }
                                  },
                                  child: CustomPaint(
                                    painter: CalendarHeatmapPainter(
                                      startDate: _startDate,
                                      totalWeeks: totalWeeks,
                                      data: _sleepData,
                                      isDark: isDark,
                                      cellSize: cellSize,
                                      gap: gap,
                                      labelWidth: labelWidth
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              );
            },
          ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String text;
  const _WeekdayLabel(this.text);
  @override
  Widget build(BuildContext context) {
    // Width must match (cellSize + gap)
    // 32 + 6 = 38
    // Height must match cellSize
    return SizedBox(
      width: 38,
      height: 32,
      child: Center(child: Text(text, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
    );
  }
}

class CalendarHeatmapPainter extends CustomPainter {
  final DateTime startDate;
  final int totalWeeks;
  final Map<DateTime, double> data;
  final bool isDark;
  final double cellSize;
  final double gap;
  final double labelWidth;

  CalendarHeatmapPainter({
    required this.startDate,
    required this.totalWeeks,
    required this.data,
    required this.isDark,
    required this.cellSize,
    required this.gap,
    required this.labelWidth,
  });

  // Helper to map 0..1 intensity to Thermal Gradient
  Color getColor(double intensity) {
    if (intensity <= 0) return isDark ? Colors.white10 : Colors.grey[200]!;
    
    // Scale:
    // 0.0 - 0.3: Blue/Cyan (Short Sleep)
    // 0.3 - 0.6: Green/Yellow (Medium Sleep)
    // 0.6 - 1.0: Orange/Red (Long Sleep)
    
    if (intensity < 0.3) {
      return Color.lerp(Colors.lightBlue[100], Colors.cyan, intensity / 0.3)!;
    } else if (intensity < 0.6) {
      return Color.lerp(Colors.cyan, Colors.yellow, (intensity - 0.3) / 0.3)!;
    } else {
      return Color.lerp(Colors.orange, Colors.red, (intensity - 0.6) / 0.4)!;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    final TextPainter textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    // Year Labels Logic
    DateTime? lastYear;

    // Month Labels Logic
    DateTime? lastMonth;

    for (int w = 0; w < totalWeeks; w++) {
      // Paint from recent to past: w=0 is most recent, w=totalWeeks-1 is oldest
      int weekIndex = totalWeeks - 1 - w;
      DateTime weekStart = startDate.add(Duration(days: weekIndex * 7));

      // Draw Year Label on the left
      if (lastYear == null || weekStart.year != lastYear.year) {
        lastYear = weekStart;

        textPainter.text = TextSpan(
          text: DateFormat.y().format(weekStart),
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.bold
          ),
        );
        textPainter.layout();
        // Draw year label above the first month of the year
        textPainter.paint(canvas, Offset(0, w * (cellSize + gap) - 20));
      }

      // Draw Month Label on the left
      if (lastMonth == null || weekStart.month != lastMonth.month) {
        lastMonth = weekStart;

        textPainter.text = TextSpan(
          text: DateFormat.MMM().format(weekStart),
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[700],
            fontSize: 12,
            fontWeight: FontWeight.bold
          ),
        );
        textPainter.layout();
        // Draw to the left of the grid
        textPainter.paint(canvas, Offset(0, w * (cellSize + gap)));
      }

      // Draw 7 Days
      for (int d = 0; d < 7; d++) {
        DateTime dayDate = weekStart.add(Duration(days: d));
        // Normalize lookup key
        final key = DateTime(dayDate.year, dayDate.month, dayDate.day);
        double hours = data[key] ?? 0;

        // Intensity: Normalize 0-10 hours range
        // Clamp at 10 hours = 1.0 (Red)
        double intensity = (hours / 10.0).clamp(0.0, 1.0);

        paint.color = getColor(intensity);

        double x = labelWidth + d * (cellSize + gap);
        double y = w * (cellSize + gap);

        // Don't draw future days
        if (dayDate.isAfter(DateTime.now())) {
            continue;
        }

        RRect rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          const Radius.circular(4),
        );
        canvas.drawRRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

extension CanvasText on Canvas {
  void drawText(TextPainter tp, Offset offset) {
    tp.paint(this, offset);
  }
}
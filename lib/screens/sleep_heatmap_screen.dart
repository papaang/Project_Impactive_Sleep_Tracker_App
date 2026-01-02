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

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Calculate Grid Size only when data is ready
    int totalDays = _endDate.difference(_startDate).inDays + 1;
    int totalWeeks = (totalDays / 7).ceil();
    
    // Constants
    const double cellSize = 24.0;
    const double gap = 4.0;
    const double headerHeight = 30.0;
    final double gridHeight = 7 * (cellSize + gap);
    final double gridWidth = totalWeeks * (cellSize + gap);

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
                      "Long-term sleep duration trends. Tap a block for details.",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    
                    // --- HEATMAP CONTAINER ---
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Y-AXIS LABELS (Fixed)
                          Padding(
                            padding: const EdgeInsets.only(top: headerHeight), // Align with grid rows
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: const [
                                _DayLabel("Mon"),
                                _DayLabel(""),
                                _DayLabel("Wed"),
                                _DayLabel(""),
                                _DayLabel("Fri"),
                                _DayLabel(""),
                                _DayLabel("Sun"),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          
                          // SCROLLABLE GRID
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              reverse: true, // Start at the end (Today)
                              child: SizedBox(
                                width: gridWidth,
                                height: gridHeight + headerHeight,
                                child: GestureDetector(
                                  onTapUp: (details) {
                                    // Hit Test
                                    
                                    double y = details.localPosition.dy - headerHeight;
                                    double x = details.localPosition.dx;
                                    
                                    if (y < 0) return; // Header tap

                                    int col = (x / (cellSize + gap)).floor();
                                    int row = (y / (cellSize + gap)).floor();
                                    
                                    if (col >= 0 && col < totalWeeks && row >= 0 && row < 7) {
                                      DateTime day = _startDate.add(Duration(days: col * 7 + row));
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
                                      headerHeight: headerHeight
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // --- LEGEND ---
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text("Less", style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                        const Text("More", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 280),
                  ],
                ),
              );
            },
          ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  final String text;
  const _DayLabel(this.text);
  @override
  Widget build(BuildContext context) {
    // Height must match (cellSize + gap)
    // 24 + 4 = 28
    return SizedBox(
      height: 28, 
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
  final double headerHeight;

  CalendarHeatmapPainter({
    required this.startDate, 
    required this.totalWeeks, 
    required this.data,
    required this.isDark,
    required this.cellSize,
    required this.gap,
    required this.headerHeight,
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

    // Month Labels Logic
    DateTime? lastMonth;

    for (int w = 0; w < totalWeeks; w++) {
      DateTime weekStart = startDate.add(Duration(days: w * 7));
      
      // Draw Month Label
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
        // Draw above grid
        textPainter.paint(canvas, Offset(w * (cellSize + gap), 0));
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

        double x = w * (cellSize + gap);
        double y = headerHeight + d * (cellSize + gap);

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
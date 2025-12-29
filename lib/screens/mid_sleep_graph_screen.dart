import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../log_service.dart';

class MidSleepGraphScreen extends StatefulWidget {
  const MidSleepGraphScreen({super.key});

  @override
  State<MidSleepGraphScreen> createState() => _MidSleepGraphScreenState();
}

class _MidSleepGraphScreenState extends State<MidSleepGraphScreen> {
  final LogService _logService = LogService();
  Map<DateTime, double> _dataPoints = {};
  
  bool _isLoading = true;
  final int _daysToLoad = 30; // Increased to 30

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final allLogs = await _logService.getAllLogs();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    Map<DateTime, double> points = {};
    
    final sortedKeys = allLogs.keys.where((d) => !d.isAfter(today)).toList()
      ..sort((a, b) => b.compareTo(a)); // Newest first
    
    final range = sortedKeys.take(_daysToLoad).toList();

    for (var date in range) {
      final log = allLogs[date]!;
      SleepEntry? mainSleep;
      double maxDuration = -1;
      
      for (var entry in log.sleepLog) {
        if (entry.durationHours > maxDuration) {
          maxDuration = entry.durationHours;
          mainSleep = entry;
        }
      }

      if (mainSleep != null) {
        Duration sleepDur = mainSleep.wakeTime.difference(mainSleep.fellAsleepTime);
        DateTime midTime = mainSleep.fellAsleepTime.add(sleepDur ~/ 2);
        double h = midTime.hour + midTime.minute / 60.0;
        points[date] = h;
      }
    }

    setState(() {
      _dataPoints = points;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sortedDates = _dataPoints.keys.toList()..sort();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Circadian Drift'),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _dataPoints.isEmpty 
          ? const Center(child: Text("Not enough sleep data yet."))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Mid-Sleep Point Trend",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Trending UP means sleep is shifting later.",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withAlpha(13) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.withAlpha(51))
                      ),
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Dynamic Width Logic for Scrolling
                          double minWidth = constraints.maxWidth;
                          double requiredWidth = sortedDates.length * 50.0; // 50px per data point
                          double finalWidth = max(minWidth, requiredWidth);

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            reverse: true, // Start at newest data
                            child: SizedBox(
                              width: finalWidth,
                              height: constraints.maxHeight,
                              child: CustomPaint(
                                painter: DriftGraphPainter(
                                  dates: sortedDates,
                                  data: _dataPoints,
                                  isDark: isDark
                                ),
                              ),
                            ),
                          );
                        }
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildStatsBox(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsBox(bool isDark) {
    if (_dataPoints.isEmpty) return const SizedBox();
    
    double sum = 0;
    int count = 0;
    _dataPoints.forEach((_, val) {
      sum += val;
      count++;
    });
    
    if (count == 0) return const SizedBox();
    
    double avg = sum / count;
    int h = avg.floor();
    int m = ((avg - h) * 60).round();
    String timeStr = "${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              const Text("Average Mid-Sleep", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(timeStr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigoAccent)),
            ],
          ),
        ],
      ),
    );
  }
}

class DriftGraphPainter extends CustomPainter {
  final List<DateTime> dates;
  final Map<DateTime, double> data;
  final bool isDark;

  DriftGraphPainter({required this.dates, required this.data, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 40.0; // Left padding for Y-labels
    final graphW = size.width - padding;
    final graphH = size.height - 30.0; // Bottom padding for X-labels

    // Calculate Y Range (Time)
    double minH = 24;
    double maxH = 0;
    
    data.forEach((k, v) {
      if (v < minH) minH = v;
      if (v > maxH) maxH = v;
    });

    minH = (minH - 1).clamp(0, 24);
    maxH = (maxH + 1).clamp(0, 24);
    if (minH >= maxH) { minH = 0; maxH = 12; }

    final paintLine = Paint()
      ..color = Colors.indigoAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintDot = Paint()
      ..color = isDark ? Colors.white : Colors.indigo
      ..style = PaintingStyle.fill;
    
    final paintGrid = Paint()
      ..color = Colors.grey.withAlpha(51)
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    // 1. Draw Y-Axis Labels & Grid (Fixed on left of the scrollable area?)
    // Actually, in a scrollable graph, typically Y-Axis is fixed and Graph scrolls.
    // Here, simply drawing them on the canvas means they will scroll AWAY.
    // For a simple implementation, we draw them on the canvas. 
    // Ideally, this Painter should only draw the data, and Y-Axis should be a separate widget outside the ScrollView.
    // However, sticking to the single-painter pattern for simplicity as requested, noting labels will scroll.
    
    int ySteps = (maxH - minH).ceil();
    if (ySteps > 6) ySteps = 6; 
    
    for (int i = 0; i <= ySteps; i++) {
      double val = minH + (i * (maxH - minH) / ySteps);
      double y = graphH - ((val - minH) / (maxH - minH)) * graphH;

      canvas.drawLine(Offset(padding, y), Offset(size.width, y), paintGrid);

      int h = val.floor();
      int m = ((val - h) * 60).round();
      String label = "${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}";
      
      textPainter.text = TextSpan(
        text: label, 
        style: TextStyle(color: Colors.grey, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(padding - textPainter.width - 5, y - textPainter.height / 2));
    }

    // 2. Draw Data Line
    Path path = Path();
    List<Offset> points = [];

    // Spacing is now based on dynamic width
    double stepX = graphW / (dates.length > 1 ? dates.length - 1 : 1);
    
    for (int i = 0; i < dates.length; i++) {
      double val = data[dates[i]]!;
      // X position is simply index * step
      double x = padding + i * stepX;
      double y = graphH - ((val - minH) / (maxH - minH)) * graphH;
      
      points.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      
      // Draw Date Labels
      textPainter.text = TextSpan(
        text: DateFormat('d/M').format(dates[i]),
        style: TextStyle(color: Colors.grey, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, graphH + 8));
    }

    canvas.drawPath(path, paintLine);

    for (var p in points) {
      canvas.drawCircle(p, 4, paintDot);
      canvas.drawCircle(p, 2, Paint()..color = isDark ? Colors.black : Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
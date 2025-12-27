import 'dart:ui' as ui; // Added to resolve TextDirection
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../log_service.dart';

class SleepGraphScreen extends StatefulWidget {
  const SleepGraphScreen({super.key});

  @override
  State<SleepGraphScreen> createState() => _SleepGraphScreenState();
}

class _SleepGraphScreenState extends State<SleepGraphScreen> {
  final LogService _logService = LogService();
  Map<DateTime, DailyLog> _logs = {};
  Map<String, Category> _dayTypes = {};
  bool _isLoading = true;
  
  // Settings
  final int _daysToLoad = 30; 
  final double _rowHeight = 80.0; // Increased height for better stacking
  final double _dateColWidth = 50.0;
  final double _typeColWidth = 40.0;
  final double _hourWidth = 60.0; // Increased width for better spacing
  late final double _graphWidth; 

  @override
  void initState() {
    super.initState();
    _graphWidth = _hourWidth * 25; // 24 hours + 1 buffer
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Load Day Types for lookup
    final dayTypeList = await CategoryManager().getCategories('day_types');
    _dayTypes = {for (var t in dayTypeList) t.id: t};

    Map<DateTime, DailyLog> loaded = {};
    
    // Load last N days + 1 (to ensure we have the "next day" for the most recent row)
    // Also load "tomorrow" (i = -1) just in case
    for (int i = -1; i < _daysToLoad + 1; i++) {
      final date = today.subtract(Duration(days: i));
      final keyDate = DateTime(date.year, date.month, date.day);
      final log = await _logService.getDailyLog(keyDate);
      loaded[keyDate] = log;
    }

    setState(() {
      _logs = loaded;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sort dates: Newest at Top (index 0).
    // Filtering to strictly show the requested range (excluding the buffer 'tomorrow' or 'yesterday+1' from list view)
    final sortedKeys = _logs.keys.toList()..sort((a, b) => b.compareTo(a)); 
    
    // We want to show _daysToLoad starting from today (or latest available)
    // Filter to exclude future dates beyond "today" if desired, or just take the top N.
    // For safety, let's just use the loaded keys that are <= today.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final displayDates = sortedKeys.where((d) => !d.isAfter(today)).take(_daysToLoad).toList();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Progress Graph'),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Row(
            children: [
              // --- LEFT COLUMNS (FIXED) ---
              SizedBox(
                width: _dateColWidth + _typeColWidth,
                child: Column(
                  children: [
                    // Header
                    Container(
                      height: 40,
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Row(
                        children: [
                          SizedBox(width: _dateColWidth, child: Center(child: Text("Date", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
                          SizedBox(width: _typeColWidth, child: Center(child: Text("Type", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    // Rows
                    Expanded(
                      child: ListView.builder(
                        physics: const ClampingScrollPhysics(), // Sync scroll manually if needed
                        itemCount: displayDates.length,
                        itemBuilder: (context, index) {
                          final date = displayDates[index];
                          final log = _logs[date];
                          final dayType = log != null && log.dayTypeId != null ? _dayTypes[log.dayTypeId] : null;

                          return Container(
                            height: _rowHeight,
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
                            ),
                            child: Row(
                              children: [
                                // Date
                                SizedBox(
                                  width: _dateColWidth,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(DateFormat('dd/MM').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      Text(DateFormat('EEE').format(date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                // Type Icon
                                SizedBox(
                                  width: _typeColWidth,
                                  child: Center(
                                    child: dayType != null 
                                      ? Icon(dayType.icon, size: 20, color: dayType.color)
                                      : Text("-", style: TextStyle(color: Colors.grey)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              const VerticalDivider(width: 1, thickness: 1),

              // --- RIGHT GRAPH (SCROLLABLE) ---
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _graphWidth,
                    child: Column(
                      children: [
                        // Header (Time Labels)
                        Container(
                          height: 40,
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: CustomPaint(
                            size: Size(_graphWidth, 40),
                            painter: GraphHeaderPainter(hourWidth: _hourWidth, isDark: isDark),
                          ),
                        ),
                        const Divider(height: 1, thickness: 1),
                        // Rows
                        Expanded(
                          child: ListView.builder(
                            physics: const ClampingScrollPhysics(),
                            itemCount: displayDates.length,
                            itemBuilder: (context, index) {
                              final date = displayDates[index];
                              
                              // FETCH PREVIOUS, CURRENT AND NEXT DAY LOGS
                              // This ensures we catch sleep sessions that span across midnight 
                              // regardless of whether they are logged in the start-date or end-date file.
                              List<DailyLog> rowLogs = [];
                              
                              final prevDate = date.subtract(const Duration(days: 1));
                              if (_logs[prevDate] != null) rowLogs.add(_logs[prevDate]!);
                              
                              if (_logs[date] != null) rowLogs.add(_logs[date]!);
                              
                              final nextDate = date.add(const Duration(days: 1));
                              if (_logs[nextDate] != null) rowLogs.add(_logs[nextDate]!);

                              return Container(
                                height: _rowHeight,
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
                                ),
                                child: CustomPaint(
                                  painter: GraphRowPainter(
                                    logs: rowLogs, 
                                    rowDate: date,
                                    hourWidth: _hourWidth,
                                    isDark: isDark
                                  ),
                                  size: Size(_graphWidth, _rowHeight),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// --- PAINTERS ---
// ---------------------------------------------------------------------------

class GraphHeaderPainter extends CustomPainter {
  final double hourWidth;
  final bool isDark;

  GraphHeaderPainter({required this.hourWidth, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr, textAlign: TextAlign.center);
    final linePaint = Paint()..color = Colors.grey.withOpacity(0.3)..strokeWidth = 1;

    // Grid runs 00:00 to 24:00 (Midnight to Midnight)
    for (int i = 0; i <= 24; i++) {
      double x = i * hourWidth;
      
      // Draw Hour Label every 3 hours for clarity, or every hour if space permits
      // Let's do every 3 hours: 00, 03, ... 21, 24
      if (i % 3 == 0) {
        // Special case for last label 24 -> 24 is clear for end of day.
        String label = "${i.toString().padLeft(2, '0')}";
        if (i == 24) label = "24"; 
        
        textPainter.text = TextSpan(
          text: label,
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 10, fontWeight: FontWeight.bold),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x + (hourWidth - textPainter.width) / 2, size.height / 2 - textPainter.height / 2));
      }
      
      // Vertical Grid Line (Header)
      if (i > 0) canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GraphSymbol {
  final String text;
  final DateTime time;
  final Color color;
  _GraphSymbol(this.text, this.time, this.color);
}

class GraphRowPainter extends CustomPainter {
  final List<DailyLog> logs; 
  final DateTime rowDate;
  final double hourWidth;
  final bool isDark;

  GraphRowPainter({required this.logs, required this.rowDate, required this.hourWidth, required this.isDark});

  // Convert time to X position (relative to Midnight 00:00 on rowDate)
  double getX(DateTime time) {
    final midnight = DateTime(rowDate.year, rowDate.month, rowDate.day, 0, 0);
    // Calculate difference in minutes from Midnight
    int diff = time.difference(midnight).inMinutes;
    return (diff / 60.0) * hourWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = isDark ? Colors.white10 : Colors.black12..strokeWidth = 1;
    final boxPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = isDark ? Colors.white24 : Colors.black26;

    // 1. Draw Hour Boxes (0 to 24)
    for (int i = 0; i < 24; i++) {
      double x = i * hourWidth;
      canvas.drawRect(Rect.fromLTWH(x, 0, hourWidth, size.height), boxPaint);
    }

    // 2. Draw Events from ALL logs
    final sleepFillPaint = Paint()..style = PaintingStyle.fill..color = isDark ? Colors.indigoAccent.withOpacity(0.5) : Colors.indigo.withOpacity(0.3);
    final bedLinePaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = isDark ? Colors.tealAccent : Colors.teal[700]!;
    
    // List to collect all symbols before drawing
    List<_GraphSymbol> symbols = [];

    for (var log in logs) {
      // Draw Sleep Bars & Bed Time Lines
      for (var entry in log.sleepLog) {
        double startX = getX(entry.fellAsleepTime);
        double endX = getX(entry.wakeTime);
        double bedX = getX(entry.bedTime);
        
        double minX = 0;
        double maxX = 24 * hourWidth;

        // Draw Bed Time Line (|)
        if (bedX >= minX && bedX <= maxX) {
          canvas.drawLine(Offset(bedX, 5), Offset(bedX, size.height - 5), bedLinePaint);
        }

        // Shade Asleep Time
        if (endX > startX) {
          double l = startX.clamp(minX, maxX);
          double r = endX.clamp(minX, maxX);
          
          if (r > l && (startX < maxX && endX > minX)) {
             canvas.drawRect(Rect.fromLTRB(l, 5, r, size.height - 5), sleepFillPaint);
          }
        }
      }

      // Collect Symbols
      // Caffeine (C/A) - UPDATED LOGIC HERE
      for (var s in log.substanceLog) {
        String code = "C"; 
        
        // Check for 'alcohol' ID or legacy names
        if (s.substanceTypeId == 'alcohol' || 
            s.substanceTypeId.toLowerCase().contains('wine') || 
            s.substanceTypeId.toLowerCase().contains('beer')) {
             code = "A";
        }
        else if (s.substanceTypeId.toLowerCase().contains('cola')) {
             code = "C"; // cola is caffeine
        }
        
        Color c = code == "A" ? Colors.red : Colors.brown;
        symbols.add(_GraphSymbol(code, s.time, c));
      }

      // Medication (M)
      for (var m in log.medicationLog) {
        symbols.add(_GraphSymbol("M", m.time, Colors.green));
      }

      // Exercise (E)
      for (var e in log.exerciseLog) {
        symbols.add(_GraphSymbol("E", e.startTime, Colors.orange));
      }
    }

    // 3. Draw Symbols with Collision Detection
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    List<Rect> drawnRects = []; // To track bounding boxes of drawn text

    for (var sym in symbols) {
      double x = getX(sym.time);
      // Only check bounds for X (0-24h)
      if (x < 0 || x > 24 * hourWidth) continue;

      textPainter.text = TextSpan(
        text: sym.text,
        style: TextStyle(color: sym.color, fontWeight: FontWeight.bold, fontSize: 14),
      );
      textPainter.layout();

      double w = textPainter.width;
      double h = textPainter.height;

      bool placed = false;
      
      // Try vertical positions first (Center, Up, Down, Far Up, Far Down)
      // Expanded offsets due to increased row height (80.0)
      List<double> yOffsets = [0, -18, 18, -36, 36]; 
      // Try horizontal shift as fallback (Center, Right, Left)
      List<double> xOffsets = [0, 12, -12];

      for (var dx in xOffsets) {
        for (var dy in yOffsets) {
          double y = size.height / 2 - h / 2 + dy;
          Rect candidate = Rect.fromLTWH(x - w / 2 + dx, y, w, h); 

          // Simple overlap check with padding
          bool overlaps = false;
          for (var r in drawnRects) {
            if (candidate.inflate(2).overlaps(r)) {
               overlaps = true;
               break;
            }
          }

          if (!overlaps) {
             canvas.drawText(textPainter, candidate.topLeft);
             drawnRects.add(candidate);
             placed = true;
             break;
          }
        }
        if (placed) break;
      }
      
      // If we couldn't place it, draw it anyway at bottom slot
      if (!placed) {
         double y = size.height / 2 - h / 2 + 36; 
         canvas.drawText(textPainter, Offset(x - w / 2, y));
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
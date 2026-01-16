import 'dart:ui' as ui; // Added to resolve TextDirection
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../log_service.dart';
import 'event_screen.dart';

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
  
  final double _baseRowHeight = 80.0;
  final double _baseHourWidth = 60.0;

  final double _dateColWidth = 70.0;
  final double _typeColWidth = 40.0;
  double _scale = 1.0;
  double _baseScale = 1.0;
  double get _hourWidth => _baseHourWidth * _scale;
  double get _rowHeight => _baseRowHeight * _scale;
  double get _graphWidth => _hourWidth * 24; 


  final ScrollController _dateController = ScrollController();
  final ScrollController _graphController = ScrollController();

 @override
  void initState() {
    super.initState();
    _loadData();


    _dateController.addListener(() {
      if (_dateController.hasClients && _graphController.hasClients) {
        if (_dateController.offset != _graphController.offset) {
          _graphController.jumpTo(_dateController.offset);
        }
      }
    });

    _graphController.addListener(() {
      if (_dateController.hasClients && _graphController.hasClients) {
        if (_graphController.offset != _dateController.offset) {
          _dateController.jumpTo(_graphController.offset);
        }
      }
    });
  }

  @override
  void dispose() {
    _dateController.dispose();
    _graphController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Load Day Types for lookup
    final dayTypeList = await CategoryManager().getCategories('day_types');
    _dayTypes = {for (var t in dayTypeList) t.id: t};

    final allSavedLogs = await _logService.getAllLogs();
    DateTime earliestDate = today.subtract(const Duration(days: 30)); 
    if (allSavedLogs.isNotEmpty) {
      final sortedSaved = allSavedLogs.keys.toList()..sort();
      if (sortedSaved.first.isBefore(earliestDate)) {
        final first = sortedSaved.first;
        earliestDate = DateTime(first.year, first.month, first.day);
      }
    }
    
    Map<DateTime, DailyLog> continuousLogs = {};
    int daysDiff = today.difference(earliestDate).inDays;
    
    for (int i = -1; i <= daysDiff; i++) {
       final date = today.subtract(Duration(days: i));
       final keyDate = DateTime(date.year, date.month, date.day);

       DailyLog? foundLog;
       
       // 1. Try direct lookup first (fastest)
       if (allSavedLogs.containsKey(keyDate)) {
         foundLog = allSavedLogs[keyDate];
       } else {
         // 2. Fallback: Search for a key with the same Y/M/D
         for (var k in allSavedLogs.keys) {
           if (k.year == keyDate.year && k.month == keyDate.month && k.day == keyDate.day) {
             foundLog = allSavedLogs[k];
             break;
           }
         }
       }
       // --- FIX ENDS HERE ---

       if (foundLog != null) {
         continuousLogs[keyDate] = foundLog;
       } else {
         continuousLogs[keyDate] = DailyLog(); // Empty log for gap
       }
    }


    setState(() {
      _logs = continuousLogs;
      _isLoading = false;
    });
  }


  void _zoomIn() {
    setState(() {
      _scale = (_scale + 0.25).clamp(0.5, 3.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _scale = (_scale - 0.25).clamp(0.5, 3.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sort dates: Newest at Top (index 0).
    // Filtering to strictly show the requested range (excluding the buffer 'tomorrow' or 'yesterday+1' from list view)
    final sortedKeys = _logs.keys.toList()..sort((a, b) => b.compareTo(a));

    // We want to show _daysToLoad starting from today (or latest available)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final displayDates = sortedKeys.where((d) => !d.isAfter(today.add(const Duration(days: 1)))).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Adjust sizes for smallest scale
    double dateColWidth = _dateColWidth;
    double typeColWidth = _typeColWidth;
    double dateFontSize = 15.0;
    double dayFontSize = 16.0;
    if (_scale == 0.5) {
      dateColWidth = 35.0;
      typeColWidth = 25.0;
      dateFontSize = 11.0;
      dayFontSize = 12.0;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Progress Graph'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: _zoomOut,
            tooltip: "Zoom Out",
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: _zoomIn,
            tooltip: "Zoom In",
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Row(
            children: [
              // --- LEFT COLUMNS (FIXED) ---
              SizedBox(
                width: dateColWidth + typeColWidth,
                child: Column(
                  children: [
                    // Header
                    Container(
                      height: 40,
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Row(
                        children: [
                          SizedBox(width: dateColWidth, child: Center(child: Text("Date", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
                          SizedBox(width: typeColWidth, child: Center(child: Text("Type", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    // Rows
                    Expanded(
                      child: ListView.builder(
                        controller: _dateController, // Attached Controller
                        physics: const ClampingScrollPhysics(),
                        itemCount: displayDates.length,
                        itemBuilder: (context, index) {
                          final date = displayDates[index];
                          final log = _logs[date];
                          final dayType = log != null && log.dayTypeId != null ? _dayTypes[log.dayTypeId] : null;

                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => EventScreen(date: date)),
                              );
                            },
                            child: Container(
                              height: _rowHeight,
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.grey.withAlpha(51))),
                              ),
                              child: Row(
                                children: [
                                  // Date
                                  SizedBox(
                                    width: dateColWidth,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(DateFormat('dd/MM').format(date), style: TextStyle(fontWeight: FontWeight.bold, fontSize: dateFontSize)),
                                        Text(DateFormat('EEE').format(date), style: TextStyle(fontSize: dayFontSize, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  // Type Icon
                                  SizedBox(
                                    width: typeColWidth,
                                    child: Center(
                                      child: dayType != null
                                        ? Icon(dayType.icon, size: 20, color: dayType.color)
                                        : Text("-", style: TextStyle(color: Colors.grey)),
                                    ),
                                  ),
                                ],
                              ),
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
                child: GestureDetector(
                  onScaleStart: (details) {
                    _baseScale = _scale;
                  },
                  onScaleUpdate: (details) {
                    setState(() {
                      _scale = (_baseScale * details.scale).clamp(0.5, 3.0);
                    });
                  },
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
                            controller: _graphController, 
                            physics: const ClampingScrollPhysics(),
                            itemCount: displayDates.length,
                            itemBuilder: (context, index) {
                              final date = displayDates[index];
                              
                              // FETCH PREVIOUS, CURRENT AND NEXT DAY LOGS
                              List<DailyLog> rowLogs = [];
                              

                              final prevDate = date.subtract(const Duration(days: 1));
                              if (_logs[prevDate] != null) rowLogs.add(_logs[prevDate]!);
                              
                              if (_logs[date] != null) rowLogs.add(_logs[date]!);
                              
                              final nextDate = date.add(const Duration(days: 1));
                              if (_logs[nextDate] != null) rowLogs.add(_logs[nextDate]!);

                              return Container(
                                height: _rowHeight,
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Colors.grey.withAlpha(51))),
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
    final linePaint = Paint()..color = Colors.grey.withAlpha(77)..strokeWidth = 1;

    // Grid runs 00:00 to 24:00 (Midnight to Midnight)
    for (int i = 0; i < 24; i++) {
      double x = i * hourWidth;
      
      // Draw Hour Label every 3 hours for clarity, or every hour if space permits
      if (i % 3 == 0) {
        String label = i.toString().padLeft(2, '0');
        
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
    final boxPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = isDark ? Colors.white24 : Colors.black26;

    // 1. Draw Hour Boxes (0 to 24)
    for (int i = 0; i < 24; i++) {
      double x = i * hourWidth;
      canvas.drawRect(Rect.fromLTWH(x, 0, hourWidth, size.height), boxPaint);
    }

    // 2. Draw Events from ALL logs
    final sleepFillPaint = Paint()..style = PaintingStyle.fill..color = isDark ? Colors.indigoAccent.withAlpha(128) : Colors.indigo.withAlpha(77);
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
      if (x < 0 || x > 24 * hourWidth) continue;

      textPainter.text = TextSpan(
        text: sym.text,
        style: TextStyle(color: sym.color, fontWeight: FontWeight.bold, fontSize: 20),
      );
      textPainter.layout();

      double w = textPainter.width;
      double h = textPainter.height;

      bool placed = false;
      
      // Try vertical positions first (Center, Up, Down, Far Up, Far Down)
      List<double> yOffsets = [0, -24, 24, -48, 48]; 
      // Try horizontal shift as fallback (Center, Right, Left)
      List<double> xOffsets = [0, 16, -16];

      for (var dx in xOffsets) {
        for (var dy in yOffsets) {
          double y = size.height / 2 - h / 2 + dy;
          Rect candidate = Rect.fromLTWH(x - w / 2 + dx, y, w, h); 

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
      
      if (!placed) {
         double y = size.height / 2 - h / 2 + 36; 
         canvas.drawText(textPainter, Offset(x - w / 2, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

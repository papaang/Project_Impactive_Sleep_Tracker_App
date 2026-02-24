import 'dart:ui' as ui; // Added to resolve TextDirection
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart'; // NEW to V2.2.0
import 'package:pdf/widgets.dart' as pw; // NEW to V2.2.0
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
  Map<String, Category> _medicationTypes = {};
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

    // Load Medication Types for lookup
    final medicationTypeList = await CategoryManager().getCategories('medication_types');
    _medicationTypes = {for (var t in medicationTypeList) t.id: t};

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

  void _showSymbolDetails(BuildContext context, GraphSymbol symbol) {
    String title = symbol.name ?? 'Event';
    String details = '';
    String timeText = 'Time: ${DateFormat('HH:mm').format(symbol.time)}';

    if (symbol.icon != null) {
      // Medication
      if (symbol.dosage != null && symbol.dosage!.isNotEmpty) {
        details = 'Dosage: ${symbol.dosage} mg';
      }
    } else {
      if (symbol.text == 'C') {
        // Caffeine
        String dosageText = symbol.dosage != null && symbol.dosage!.isNotEmpty ? symbol.dosage! : '';
        details = '$dosageText cup${int.tryParse(dosageText) != null ? (int.tryParse(dosageText)! > 1 ? 's' : '') : '(s)'}';
      } else if (symbol.text == 'A') {
        // Alcohol
        String dosageText = symbol.dosage != null && symbol.dosage!.isNotEmpty ? symbol.dosage! : '';
        details = '$dosageText drink${int.tryParse(dosageText) != null ? (int.tryParse(dosageText)! > 1 ? 's' : '') : '(s)'}';
      } else if (symbol.text == 'E') {
        // Exercise
        String intensity = symbol.dosage ?? '';
        details = intensity;
        // For duration (start to end), we'd need to access the exercise entry, but for now, just show start time
      }
    }

    final snackBar = SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (details.isNotEmpty)
            Text(details, style: const TextStyle(fontSize: 14)),
          Text(
            timeText,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
      duration: const Duration(seconds: 3),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

Future<void> _exportGraph() async {
    if (_logs.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating PDF Report...'), duration: Duration(seconds: 2)),
    );

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final sortedKeys = _logs.keys.toList()..sort((a, b) => b.compareTo(a));
      final displayDates = sortedKeys.where((d) => !d.isAfter(today.add(const Duration(days: 1)))).toList();

      if (displayDates.isEmpty) return;

      // 1. Group dates by Month and Year
      final Map<String, List<DateTime>> months = {};
      for (var date in displayDates) {
        String monthKey = DateFormat('MMMM yyyy').format(date); // e.g., "January 2026"
        if (!months.containsKey(monthKey)) months[monthKey] = [];
        months[monthKey]!.add(date);
      }

      // 2. Initialize the PDF Document
      final pdf = pw.Document();

      // 3. Process each month as a separate page
      for (var monthEntry in months.entries) {
        final monthName = monthEntry.key;
        final monthDates = monthEntry.value;

        // Calculate dimensions for this specific month's page
        final double headerHeight = 40.0;
        final double titleHeight = 60.0; // Space for the month title
        final double totalWidth = _dateColWidth + _typeColWidth + _graphWidth;
        final double totalHeight = titleHeight + headerHeight + (monthDates.length * _rowHeight);

        // Setup the invisible canvas
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, totalWidth, totalHeight));
        
        // FORCE LIGHT MODE for PDFs (looks much better when printed)
        final bool isDark = false; 
        canvas.drawRect(Rect.fromLTWH(0, 0, totalWidth, totalHeight), Paint()..color = Colors.white);

        final textPainter = TextPainter(textDirection: ui.TextDirection.ltr, textAlign: TextAlign.center);

        // Draw Month Title at the top
        textPainter.text = TextSpan(
          text: monthName, 
          style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold)
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset((totalWidth - textPainter.width) / 2, (titleHeight - textPainter.height) / 2));

        // Draw Header (Date | Type | 00:00 ...)
        double currentY = titleHeight;
        textPainter.text = const TextSpan(text: "Date", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold));
        textPainter.layout(maxWidth: _dateColWidth);
        textPainter.paint(canvas, Offset((_dateColWidth - textPainter.width) / 2, currentY + (headerHeight - textPainter.height) / 2));

        textPainter.text = const TextSpan(text: "Type", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold));
        textPainter.layout(maxWidth: _typeColWidth);
        textPainter.paint(canvas, Offset(_dateColWidth + (_typeColWidth - textPainter.width) / 2, currentY + (headerHeight - textPainter.height) / 2));

        canvas.save();
        canvas.translate(_dateColWidth + _typeColWidth, currentY);
        GraphHeaderPainter(hourWidth: _hourWidth, isDark: isDark).paint(canvas, Size(_graphWidth, headerHeight));
        canvas.restore();

        currentY += headerHeight;
        canvas.drawLine(Offset(0, currentY), Offset(totalWidth, currentY), Paint()..color = Colors.black..strokeWidth = 1.5);

        // Draw Rows for this month
        final dividerPaint = Paint()..color = Colors.grey.withAlpha(80)..strokeWidth = 1;

        for (var date in monthDates) {
          final log = _logs[date];
          final dayType = log != null && log.dayTypeId != null ? _dayTypes[log.dayTypeId] : null;

          // Draw Date
          textPainter.text = TextSpan(text: DateFormat('dd/MM').format(date), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15.0));
          textPainter.layout(maxWidth: _dateColWidth);
          textPainter.paint(canvas, Offset((_dateColWidth - textPainter.width) / 2, currentY + _rowHeight / 2 - textPainter.height));

          textPainter.text = TextSpan(text: DateFormat('EEE').format(date), style: TextStyle(color: Colors.grey[800], fontSize: 16.0));
          textPainter.layout(maxWidth: _dateColWidth);
          textPainter.paint(canvas, Offset((_dateColWidth - textPainter.width) / 2, currentY + _rowHeight / 2));

          // Draw Day Type Icon
          if (dayType != null) {
            textPainter.text = TextSpan(
              text: String.fromCharCode(dayType.icon.codePoint),
              style: TextStyle(fontSize: 20.0, fontFamily: dayType.icon.fontFamily, package: dayType.icon.fontPackage, color: dayType.color),
            );
            textPainter.layout();
            textPainter.paint(canvas, Offset(_dateColWidth + (_typeColWidth - textPainter.width) / 2, currentY + (_rowHeight - textPainter.height) / 2));
          }

          // Draw the Graph Data
          canvas.save();
          canvas.translate(_dateColWidth + _typeColWidth, currentY);

          List<DailyLog> rowLogs = [];
          if (_logs[date.subtract(const Duration(days: 1))] != null) rowLogs.add(_logs[date.subtract(const Duration(days: 1))]!);
          if (_logs[date] != null) rowLogs.add(_logs[date]!);
          if (_logs[date.add(const Duration(days: 1))] != null) rowLogs.add(_logs[date.add(const Duration(days: 1))]!);

          GraphBackgroundPainter(logs: rowLogs, rowDate: date, hourWidth: _hourWidth, isDark: isDark).paint(canvas, Size(_graphWidth, _rowHeight));

          final rowPainter = GraphRowPainter(logs: rowLogs, rowDate: date, hourWidth: _hourWidth, isDark: isDark, medicationTypes: _medicationTypes, rowHeight: _rowHeight);
          for (var symbolData in rowPainter.getSymbols()) {
            if (symbolData.symbol.icon != null) {
              textPainter.text = TextSpan(
                text: String.fromCharCode(symbolData.symbol.icon!.codePoint),
                style: TextStyle(fontSize: 24.0, fontFamily: symbolData.symbol.icon!.fontFamily, package: symbolData.symbol.icon!.fontPackage, color: symbolData.symbol.color),
              );
            } else {
              textPainter.text = TextSpan(text: symbolData.symbol.text ?? '', style: TextStyle(color: symbolData.symbol.color, fontWeight: FontWeight.bold, fontSize: 20));
            }
            textPainter.layout();
            textPainter.paint(canvas, Offset(symbolData.x, symbolData.y));
          }
          canvas.restore();

          currentY += _rowHeight;
          canvas.drawLine(Offset(0, currentY), Offset(totalWidth, currentY), dividerPaint);
        }

        // Convert Canvas to Image Bytes
        final picture = recorder.endRecording();
        final image = await picture.toImage(totalWidth.toInt(), totalHeight.toInt());
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

        // Add Image as a new PDF Page
        if (byteData != null) {
          final pdfImage = pw.MemoryImage(byteData.buffer.asUint8List());
          
          pdf.addPage(pw.Page(
            pageFormat: PdfPageFormat(totalWidth, totalHeight), // Custom page size so it doesn't squish!
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.Image(pdfImage);
            }
          ));
        }
      }

      // 4. Save and Share the PDF
      final directory = await getTemporaryDirectory();
      // --- Dynamic Filename Logic (uses the patient's name) ---
      String userName = _logService.userName.trim();
      
      // Sanitize the name to prevent file-saving errors 
      // (Replaces spaces with underscores, removes special characters)
      String safeName = userName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_'); 
      
      // Create the filename: Use the alias if it exists, otherwise use a default
      String fileName = safeName.isNotEmpty 
          ? '${safeName}_Sleep_Diary_Export.pdf' 
          : 'Sleep_Diary_Export.pdf';

      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        Share.shareXFiles([XFile(file.path)], text: 'My Sleep Diary Report');
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export: $e')));
      }
    }
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
        title: const Text('Sleep Diary Daily Overview'),
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
          IconButton(
            icon: const Icon(Icons.picture_as_pdf), // Added a PDF icon!
            onPressed: _exportGraph,
            tooltip: "Export as PDF",
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

                              final rowPainter = GraphRowPainter(
                                logs: rowLogs,
                                rowDate: date,
                                hourWidth: _hourWidth,
                                isDark: isDark,
                                medicationTypes: _medicationTypes,
                                rowHeight: _rowHeight
                              );
                              final symbols = rowPainter.getSymbols();

                              return Container(
                                height: _rowHeight,
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Colors.grey.withAlpha(51))),
                                ),
                                child: Stack(
                                  children: [
                                    // Background
                                    CustomPaint(
                                      painter: GraphBackgroundPainter(
                                        logs: rowLogs,
                                        rowDate: date,
                                        hourWidth: _hourWidth,
                                        isDark: isDark
                                      ),
                                      size: Size(_graphWidth, _rowHeight),
                                    ),
                                    // Symbols
                                    ...symbols.map((symbolData) {
                                      return Positioned(
                                        left: symbolData.x,
                                        top: symbolData.y,
                                        child: GestureDetector(
                                          onTap: () => _showSymbolDetails(context, symbolData.symbol),
                                          child: symbolData.symbol.icon != null
                                            ? Icon(symbolData.symbol.icon, size: 24, color: symbolData.symbol.color)
                                            : Text(
                                                symbolData.symbol.text ?? '',
                                                style: TextStyle(color: symbolData.symbol.color, fontWeight: FontWeight.bold, fontSize: 20),
                                              ),
                                        ),
                                      );
                                    }),
                                  ],
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

class GraphBackgroundPainter extends CustomPainter {
  final List<DailyLog> logs;
  final DateTime rowDate;
  final double hourWidth;
  final bool isDark;

  GraphBackgroundPainter({required this.logs, required this.rowDate, required this.hourWidth, required this.isDark});

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
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GraphSymbol {
  final IconData? icon;
  final String? text;
  final DateTime time;
  final Color color;
  final String? name;
  final String? dosage;
  GraphSymbol({this.icon, this.text, required this.time, required this.color, this.name, this.dosage});
}

class SymbolData {
  final GraphSymbol symbol;
  final double x;
  final double y;
  SymbolData(this.symbol, this.x, this.y);
}

class GraphRowPainter {
  final List<DailyLog> logs;
  final DateTime rowDate;
  final double hourWidth;
  final bool isDark;
  final Map<String, Category> medicationTypes;
  final double rowHeight;

  GraphRowPainter({required this.logs, required this.rowDate, required this.hourWidth, required this.isDark, required this.medicationTypes, required this.rowHeight});

  // Convert time to X position (relative to Midnight 00:00 on rowDate)
  double getX(DateTime time) {
    final midnight = DateTime(rowDate.year, rowDate.month, rowDate.day, 0, 0);
    // Calculate difference in minutes from Midnight
    int diff = time.difference(midnight).inMinutes;
    return (diff / 60.0) * hourWidth;
  }

  List<SymbolData> getSymbols() {
    List<GraphSymbol> symbols = [];

    for (var log in logs) {
      // Collect Symbols
      // Caffeine (C/A)
      for (var s in log.substanceLog) {
        String code = "C";
        String name = "Caffeine";
        if (s.substanceTypeId == 'alcohol' ||
            s.substanceTypeId.toLowerCase().contains('wine') ||
            s.substanceTypeId.toLowerCase().contains('beer')) {
             code = "A";
             name = "Alcohol";
        }
        else if (s.substanceTypeId.toLowerCase().contains('cola')) {
             code = "C";
             name = "Caffeine";
        }

        Color c = code == "A" ? Colors.red : Colors.brown;
        symbols.add(GraphSymbol(text: code, time: s.time, color: c, name: name, dosage: s.amount));
      }

      // Medication
      for (var m in log.medicationLog) {
        final medType = medicationTypes[m.medicationTypeId];
        if (medType != null) {
          symbols.add(GraphSymbol(icon: medType.icon, time: m.time, color: medType.color, name: medType.name, dosage: m.dosage));
        } else {
          symbols.add(GraphSymbol(text: "M", time: m.time, color: Colors.green, name: "Medication", dosage: m.dosage));
        }
      }

      // Exercise
      for (var e in log.exerciseLog) {
        String exerciseName = "Exercise";
        String exerciseDosage = e.type; // 'light', 'medium', 'heavy' -> 'Light', 'Medium', 'Heavy'
        symbols.add(GraphSymbol(text: "E", time: e.startTime, color: Colors.orange, name: exerciseName, dosage: exerciseDosage));
      }
    }

    // Position symbols with collision detection
    List<SymbolData> positionedSymbols = [];
    List<Rect> drawnRects = [];

    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    for (var sym in symbols) {
      double x = getX(sym.time);
      if (x < 0 || x > 24 * hourWidth) continue;

      double w, h;
      if (sym.icon != null) {
        w = 24;
        h = 24;
      } else {
        textPainter.text = TextSpan(
          text: sym.text,
          style: TextStyle(color: sym.color, fontWeight: FontWeight.bold, fontSize: 20),
        );
        textPainter.layout();
        w = textPainter.width;
        h = textPainter.height;
      }

      bool placed = false;

      // Responsive yOffsets based on rowHeight
      double yBaseOffset = rowHeight * 0.16;
      double xBaseOffset = rowHeight * 0.24;
      List<double> yOffsets = [0, -yBaseOffset, yBaseOffset, -yBaseOffset * 2, yBaseOffset * 2];
      List<double> xOffsets = [0, xBaseOffset, -xBaseOffset, xBaseOffset * 2, -xBaseOffset * 2];

      for (var dx in xOffsets) {
        for (var dy in yOffsets) {
          double y = rowHeight / 2 - h / 2 + dy;
          double xOffset = x - w / 2 + dx;
          Rect candidate = Rect.fromLTWH(xOffset, y, w, h);

          bool overlaps = false;
          for (var r in drawnRects) {
            if (candidate.inflate(2).overlaps(r)) {
               overlaps = true;
               break;
            }
          }

          if (!overlaps) {
             positionedSymbols.add(SymbolData(sym, candidate.left, candidate.top));
             drawnRects.add(candidate);
             placed = true;
             break;
          }
        }
        if (placed) break;
      }

      if (!placed) {
         double y = rowHeight / 2 - h / 2 + yBaseOffset * 2.4; // fallback
         double xOffset = x - w / 2;
         positionedSymbols.add(SymbolData(sym, xOffset, y));
      }
    }

    return positionedSymbols;
  }
}

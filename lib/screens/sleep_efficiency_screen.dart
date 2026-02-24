import 'dart:math';
import 'dart:ui' as ui; // Added to resolve TextDirection
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../log_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class SleepEfficiencyScreen extends StatefulWidget {
  const SleepEfficiencyScreen({super.key});

  @override
  State<SleepEfficiencyScreen> createState() => _SleepEfficiencyScreenState();
}

class _SleepEfficiencyScreenState extends State<SleepEfficiencyScreen> {
  final LogService _logService = LogService();
  Map<DateTime, double> _timeInBedData = {};
  Map<DateTime, double> _timeAsleepData = {};
  Map<DateTime, double> _efficiencyData = {};
  
  bool _isLoading = true;
  final int _daysToLoad = 30; // Increased to 30 days for better trend analysis

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
    
    // Sort and filter last N days (newest to oldest)
    final sortedKeys = allLogs.keys.where((d) => !d.isAfter(today)).toList()
      ..sort((a, b) => b.compareTo(a)); 
    
    // Take recent days, then reverse to chronological order (Oldest -> Newest) for the graph
    final range = sortedKeys.take(_daysToLoad).toList().reversed.toList(); 

    Map<DateTime, double> inBedMap = {};
    Map<DateTime, double> asleepMap = {};
    Map<DateTime, double> effMap = {};

    for (var date in range) {
      final log = allLogs[date]!;
      
      double totalBedMinutes = 0;
      double totalSleepMinutes = 0;

      for (var entry in log.sleepLog) {
        // Time in Bed = Out - In
        DateTime end = entry.outOfBedTime ?? entry.wakeTime;
        double bedDur = end.difference(entry.bedTime).inMinutes.toDouble();
        totalBedMinutes += bedDur;

        // Time Asleep = (Wake - Asleep) - AwakeDur
        double sleepDur = entry.wakeTime.difference(entry.fellAsleepTime).inMinutes.toDouble();
        sleepDur -= entry.awakeDurationMinutes;
        if (sleepDur < 0) sleepDur = 0;
        totalSleepMinutes += sleepDur;
      }
      
      if (totalBedMinutes > 0) {
        inBedMap[date] = totalBedMinutes / 60.0;
        asleepMap[date] = totalSleepMinutes / 60.0;
        
        double efficiency = (totalSleepMinutes / totalBedMinutes) * 100;
        if (efficiency > 100) efficiency = 100;
        effMap[date] = efficiency;
      }
    }

    setState(() {
      _timeInBedData = inBedMap;
      _timeAsleepData = asleepMap;
      _efficiencyData = effMap;
      _isLoading = false;
    });
  }
  
  Future<void> _exportPdf() async {
    if (_timeInBedData.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF...')));

    try {
      final pdf = pw.Document();
      final double paddingLeft = 50.0;
      final double paddingRight = 40.0;
      final double graphWidth = max(800.0, _timeInBedData.length * 50.0);
      final double totalWidth = paddingLeft + graphWidth + paddingRight;
      final double totalHeight = 500.0;
      final double graphH = totalHeight - 150.0;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, totalWidth, totalHeight));

      canvas.drawRect(Rect.fromLTWH(0, 0, totalWidth, totalHeight), Paint()..color = Colors.white);

      final textPainter = TextPainter(textDirection: ui.TextDirection.ltr, textAlign: TextAlign.center);
      textPainter.text = const TextSpan(text: "Sleep Efficiency Trend", style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold));
      textPainter.layout();
      textPainter.paint(canvas, Offset((totalWidth - textPainter.width) / 2, 30));

      // FIX: Draw Y-Axis Grid (0 to 100%)
      canvas.save();
      canvas.translate(0, 100);
      final paintGrid = Paint()..color = Colors.grey.withAlpha(51)..strokeWidth = 1;
      for (int i = 0; i <= 5; i++) {
        double val = i * 20.0; // Grid lines at 0, 20, 40, 60, 80, 100
        double y = graphH - (val / 100.0) * graphH;
        canvas.drawLine(Offset(paddingLeft, y), Offset(totalWidth, y), paintGrid);
        
        textPainter.text = TextSpan(text: "${val.toInt()}%", style: const TextStyle(color: Colors.grey, fontSize: 12));
        textPainter.layout();
        textPainter.paint(canvas, Offset(paddingLeft - textPainter.width - 8, y - textPainter.height / 2));
      }
      canvas.restore();

      // FIX: Scale the data so "Time In Bed" is exactly 100% of the bar
      Map<DateTime, double> scaledBed = {};
      Map<DateTime, double> scaledSleep = {};
      for (var d in _timeInBedData.keys) {
        scaledBed[d] = 100.0; 
        scaledSleep[d] = _efficiencyData[d]!;
      }

      // Draw the Custom Painter
      canvas.save();
      canvas.translate(paddingLeft, 100);
      EfficiencyGraphPainter(
        dates: _timeInBedData.keys.toList(),
        bedData: scaledBed, // Scaled to 100%
        sleepData: scaledSleep, // Efficiency %
        efficiencyData: _efficiencyData,
        isDark: false,
        forcedMax: 100.0 // Force max bound to 100
      ).paint(canvas, Size(graphWidth, graphH));
      canvas.restore();

      final picture = recorder.endRecording();
      final image = await picture.toImage(totalWidth.toInt(), totalHeight.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat(totalWidth, totalHeight),
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Image(pw.MemoryImage(byteData.buffer.asUint8List())),
        ));
      }

      final directory = await getTemporaryDirectory();
      String safeName = _logService.userName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      String fileName = safeName.isNotEmpty ? '${safeName}_Efficiency_Report.pdf' : 'Efficiency_Report.pdf';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsBytes(await pdf.save());
      if (mounted) Share.shareXFiles([XFile(file.path)], text: 'Sleep Efficiency Report');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Efficiency'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _exportPdf, tooltip: "Export PDF"),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _timeInBedData.isEmpty 
          ? const Center(child: Text("Not enough sleep data."))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Time in Bed vs. Actual Sleep",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Grey = Time in Bed (Awake)\nColored = Actual Sleep",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // --- SCROLLABLE GRAPH CONTAINER ---
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withAlpha(13) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.withAlpha(51)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Dynamic width: Ensure roughly 50px per day, or full screen width if few days
                          double requiredWidth = _timeInBedData.length * 50.0;
                          double finalWidth = max(constraints.maxWidth, requiredWidth);

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            reverse: true, // Start at the end (Today)
                            child: SizedBox(
                              width: finalWidth,
                              height: constraints.maxHeight,
                              child: CustomPaint(
                                painter: EfficiencyGraphPainter(
                                  dates: _timeInBedData.keys.toList(),
                                  bedData: _timeInBedData,
                                  sleepData: _timeAsleepData,
                                  efficiencyData: _efficiencyData,
                                  isDark: isDark
                                ),
                              ),
                            ),
                          );
                        }
                      ),
                    ),
                  ),
                  const SizedBox(height: 0),
                  
                  // Legend / Key
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLegendItem(Colors.green, "> 90% (Good)"),
                      _buildLegendItem(Colors.orange, "70-90% (Fair)"),
                      _buildLegendItem(Colors.redAccent, "< 70% (Low)"),
                    ],
                  )
                ],
              ),
            ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12, height: 100,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class EfficiencyGraphPainter extends CustomPainter {
  final List<DateTime> dates;
  final Map<DateTime, double> bedData;
  final Map<DateTime, double> sleepData;
  final Map<DateTime, double> efficiencyData;
  final bool isDark;
  final double? forcedMax;

  EfficiencyGraphPainter({
    required this.dates, 
    required this.bedData, 
    required this.sleepData, 
    required this.efficiencyData, 
    required this.isDark,
    this.forcedMax
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dates.isEmpty) return;

    // Dimensions
    final double paddingBottom = 20.0;
    // ignore: unused_local_variable
    final double paddingLeft = 0.0; 
    final double graphH = size.height - paddingBottom - 15; // Space for % label on top
    
    // Step X is now based on the dynamic scrollable width
    final double stepX = size.width / dates.length;
    final double barWidth = stepX * 0.6;
    
    // Find Max Hours for scaling
    double maxHours = 0;
if (forcedMax != null) { // FIX: Allow PDF to force the max bound to 100
      maxHours = forcedMax!;
    } else {
      for (var v in bedData.values) {
        if (v > maxHours) maxHours = v;
      }
      maxHours = max(maxHours + 1, 10);
    } // Minimum 10h scale, add buffer

    final paintGrey = Paint()..color = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final paintSleep = Paint()..color = Colors.indigo;
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr, textAlign: TextAlign.center);

    for (int i = 0; i < dates.length; i++) {
      DateTime date = dates[i];
      double bedH = (bedData[date]! / maxHours) * graphH;
      double sleepH = (sleepData[date]! / maxHours) * graphH;
      double eff = efficiencyData[date]!;

      // X Position (Center of slot)
      double cx = i * stepX + stepX / 2;
      
      // 1. Draw Bed Bar (Background - Grey)
      // Bottom anchor: size.height - paddingBottom
      double bottomY = size.height - paddingBottom;
      
      Rect bedRect = Rect.fromLTWH(cx - barWidth / 2, bottomY - bedH, barWidth, bedH);
      canvas.drawRRect(RRect.fromRectAndRadius(bedRect, const Radius.circular(4)), paintGrey);

      // 2. Determine Color based on Efficiency
      Color barColor = Colors.indigo;
      if (eff >= 90) {
        barColor = Colors.green;
      } else if (eff >= 80) {
        barColor = Colors.lightGreen;
      } else if (eff >= 70) {
        barColor = Colors.orange;
      } else {
        barColor = Colors.redAccent;
      }
      
      paintSleep.color = barColor;

      // 3. Draw Sleep Bar (Foreground - Colored)
      Rect sleepRect = Rect.fromLTWH(cx - barWidth / 2, bottomY - sleepH, barWidth, sleepH);
      canvas.drawRRect(RRect.fromRectAndRadius(sleepRect, const Radius.circular(4)), paintSleep);

      // 4. Date Label
      textPainter.text = TextSpan(
        text: DateFormat('d/M').format(date),
        style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600]),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(cx - textPainter.width / 2, size.height - textPainter.height));

      // 5. Efficiency % Label (Above bar)
      textPainter.text = TextSpan(
        text: "${eff.round()}%",
        style: TextStyle(
          fontSize: 9, 
          fontWeight: FontWeight.bold, 
          color: isDark ? Colors.white70 : Colors.black87
        ),
      );
      textPainter.layout();
      // Draw slightly above the highest bar (which is bedRect top)
      canvas.drawText(textPainter, Offset(cx - textPainter.width / 2, bottomY - bedH - 12));
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
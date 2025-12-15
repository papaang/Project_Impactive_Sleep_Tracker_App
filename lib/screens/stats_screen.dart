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
  Map<DateTime, double> _weeklySleepData = {};
  bool _isLoading = true;

  String _formatHoursToHHhMM(double hours) {
    // format hours as {HH}h{MM}
    int h = hours.floor();
    int m = ((hours - h) * 60).round();
    return '${h.toString().padLeft(2, '0')}h${m.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  Future<void> _loadWeeklyData() async {
    try {
      setState(() => _isLoading = true);
      final now = DateTime.now();
      Map<DateTime, double> data = {};

      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final normalizedDate = DateTime(date.year, date.month, date.day);
        final log = await _logService.getDailyLog(normalizedDate);
        data[normalizedDate] = log.totalSleepHours;
      }

      setState(() {
        _weeklySleepData = data;
      });
    } catch (e) {
      // handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sleep Statistics')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Past 7 Days Sleep',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 16, // Assume max 16 hours for scale
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            // Unsure how to implement this
                            // tooltipBgColor: Colors.blueGrey,
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
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < _weeklySleepData.length) {
                                  final date = _weeklySleepData.keys.elementAt(index);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      DateFormat('E').format(date), // Mon, Tue...
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                              reservedSize: 30,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 2, // Grid lines every 2 hours
                              getTitlesWidget: (double value, TitleMeta meta) {
                                return Text(
                                  '${value.toInt()}h',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                );
                              },
                              reservedSize: 28,
                            ),
                          ),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 2,
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
                                color: Colors.indigo,
                                width: 16,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(4),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Hours slept per day',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
    );
  }
}

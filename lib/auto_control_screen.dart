import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:time_range_picker/time_range_picker.dart';
import 'package:google_fonts/google_fonts.dart';

class AutoControlScreen extends StatefulWidget {
  const AutoControlScreen({super.key});
  @override
  State<AutoControlScreen> createState() => _AutoControlScreenState();
}

class _AutoControlScreenState extends State<AutoControlScreen> {

  final List<FlSpot> _mowingStats = [
    FlSpot(0, 2), FlSpot(1, 3), FlSpot(2, 5),
    FlSpot(3, 3.1), FlSpot(4, 4), FlSpot(5, 3), FlSpot(6, 4),
  ];

  int _dayNameToWeekday(String day) {
    switch (day) {
      case 'Monday':    return DateTime.monday;
      case 'Tuesday':   return DateTime.tuesday;
      case 'Wednesday': return DateTime.wednesday;
      case 'Thursday':  return DateTime.thursday;
      case 'Friday':    return DateTime.friday;
      case 'Saturday':  return DateTime.saturday;
      case 'Sunday':    return DateTime.sunday;
      default:          return 0;
    }
  }

  /// Returns 0-based index for today (0=Monday…6=Sunday)
  int get _todayIndex => DateTime.now().weekday - 1;

  // List of Days of the Week
  final List<String> _daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  // For keeping track of selected days (true if selected, false if not)
  final List<bool> _selectedDays = List.generate(7, (index) => false);

  // For keeping track of whether the user wants to use the same time for all days
  bool _useSameTimeForAll = false;

  // For holding the selected time window when 'same time for all days' is chosen
  TimeRange? _selectedWindow;

  // new: one TimeRange (start+end) per weekday
  final List<TimeRange?> _selectedDayRanges = List.generate(7, (_) => null);

  // List to hold the upcoming schedules
  final List<_Job> _upcomingSchedules = [];

  /// Build today’s segments dynamically
  List<_Segment> get _todaySegments {
    final segments = <_Segment>[];

    // if today wasn’t selected, return empty
    if (!_selectedDays[_todayIndex]) return segments;

    if (_useSameTimeForAll && _selectedWindow != null) {
      segments.add(_Segment(
        _selectedWindow!.startTime.format(context),
        _selectedWindow!.endTime.format(context),
      ));
    } else {
      // new:
      final range = _selectedDayRanges[_todayIndex];
      if (range != null) {
        segments.add(_Segment(
          range.startTime.format(context),
          range.endTime.format(context),
        ));
      }
    }

    return segments;
  }

  /// Return only schedules that are in the future
  List<_Job> get _filteredUpcoming {
    final now = DateTime.now();
    return _upcomingSchedules.where((job) {
      final wd = _dayNameToWeekday(job.days);
      if (wd != now.weekday) return true;

      // It's today — parse start-time properly
      final parts = job.start.split(' ');       // ["6:00", "AM"]
      final timeParts = parts[0].split(':');    // ["6","00"]
      final hour = int.parse(timeParts[0]) % 12 + (parts[1] == 'PM' ? 12 : 0);
      final minute = int.parse(timeParts[1]);
      final dt = DateTime(now.year, now.month, now.day, hour, minute);
      return dt.isAfter(now);
    }).toList();
  }

  void _applySchedule() {
    final selectedDays = <String>[];
    for (int i = 0; i < _selectedDays.length; i++) {
      if (_selectedDays[i]) {
        selectedDays.add(_daysOfWeek[i]);
      }
    }

    log('Selected Days: $selectedDays');
    if (_useSameTimeForAll) {
      log('Time: ${_selectedWindow!.startTime.format(context)} – ${_selectedWindow!.endTime.format(context)}');
    } else {
      for (int i = 0; i < selectedDays.length; i++) {
        final range = _selectedDayRanges[i];
        if (range != null) {
          log('${selectedDays[i]} Time: '
              '${range.startTime.format(context)} – '
              '${range.endTime.format(context)}');
        }
      }
    }

    // Update the schedule logic
    setState(() {
      _upcomingSchedules.clear();
      for (final day in selectedDays) {
        if (_useSameTimeForAll) {
          _upcomingSchedules.add(_Job(
            day,
            _selectedWindow!.startTime.format(context),
            _selectedWindow!.endTime.format(context),
          ));
        } else {
          int index = _daysOfWeek.indexOf(day);
          final range = _selectedDayRanges[index];
          _upcomingSchedules.add(_Job(
            day,
            range != null ? range.startTime.format(context) : 'No Time Set',
            range != null ? range.endTime.format(context) : 'No Time Set',
          ));
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2A38),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [

              // ── MOWING SCHEDULE ──────────────────────────────────────
              _buildCard(
                title: 'Mowing Schedule',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text("Select Mowing Days:", style: GoogleFonts.robotoMono(color: Colors.white70)),
                    const SizedBox(height: 15),
                    // Days Selection
                    Row(
                      children: List.generate(_daysOfWeek.length, (index) {
                        final isSelected = _selectedDays[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDays[index] = !_selectedDays[index];
                              });
                            },
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.orange.shade700 : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.orange.shade600,
                                  width: 2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _daysOfWeek[index].substring(0, 1), // "M", "T", etc.
                                style: GoogleFonts.robotoMono(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: isSelected ? Colors.white : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    // Time Selection Option
                    Row(
                      children: [
                        Text("Use same time for all days", style: GoogleFonts.robotoMono(color: Colors.white70)),
                        SizedBox(width: 10,),
                        Switch(
                          value: _useSameTimeForAll,
                          onChanged: (value) {
                            setState(() {
                              _useSameTimeForAll = value;
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Time Picker for All Days or Specific Days
                    if (_useSameTimeForAll)
                    // Time for All Days
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [Colors.deepOrange, Colors.orangeAccent],
                          ),
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final range = await showTimeRangePicker(
                              context: context,
                              start: const TimeOfDay(hour: 6, minute: 0),
                              end: const TimeOfDay(hour: 18, minute: 0),
                            );
                            if (range != null) {
                              setState(() => _selectedWindow = range);
                            }
                          },
                          icon: const Icon(Icons.access_time, size: 20, color: Colors.black),
                          label: Text(
                            _selectedWindow == null
                                ? 'Select Mowing Time Window'
                                : '${_selectedWindow!.startTime.format(context)} – ${_selectedWindow!.endTime.format(context)}',
                            style: GoogleFonts.robotoMono(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                      )
                    else
                    // Specific Time for Each Day
                      Column(
                        children: List.generate(_daysOfWeek.length, (index) {
                          if (_selectedDays[index]) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(flex: 1,
                                    child: Text(_daysOfWeek[index], style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.bold),)),
                               Flexible(
                                  flex: 3,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final range = await showTimeRangePicker(
                                        context: context,
                                        start: const TimeOfDay(hour: 6, minute: 0),
                                        end: const TimeOfDay(hour: 18, minute: 0),
                                      );
                                      if (range != null) {
                                        setState(() {
                                          _selectedDayRanges[index] = range;
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.access_time, size: 16, color: Colors.black),
                                    label: Text(
                                      _selectedDayRanges[index] == null
                                          ? 'Select Range'
                                          : '${_selectedDayRanges[index]!.startTime.format(context)} – ${_selectedDayRanges[index]!.endTime.format(context)}',
                                      style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepOrangeAccent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return Container();
                          }
                        }),
                      ),

                    const SizedBox(height: 30),

                    // Apply Schedule Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_selectedDays.contains(true)) {
                            if (_useSameTimeForAll && _selectedWindow == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select a time window for all days')),
                              );
                              return;
                            }
                            if (!_useSameTimeForAll) {
                              bool allTimesSelected = true;
                              for (int i = 0; i < _selectedDays.length; i++) {
                                if (_selectedDays[i] && _selectedDayRanges[i] == null) {
                                  allTimesSelected = false;
                                  break;
                                }
                              }
                              if (!allTimesSelected) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please select a time for each selected day')),
                                );
                                return;
                              }
                            }
                            // Now actually apply inside setState:
                            setState(() {
                              _applySchedule();
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select at least one day for mowing')),
                            );
                          }
                        },
                        icon: const Icon(Icons.save, size: 16, color: Colors.white),
                        label: Text(
                          "Apply Schedule",
                          style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
        
              // ── TODAY & UPCOMING ─────────────────────────────────────
              _buildCard(
                title: 'Today\'s Timeline',
                child: _buildTimelineBar(_todaySegments),
              ),
              const SizedBox(height: 16),
              _buildCard(
                title: 'Upcoming Schedules',
                child: _buildUpcomingList(_filteredUpcoming),
              ),

              const SizedBox(height: 16),
        
              // ── MOWING STATS ─────────────────────────────────────────
              _buildCard(
                title: 'Weekly Mowing Stats',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 16, height: 4, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text('Hours Mowed',
                            style: GoogleFonts.robotoMono(
                                color: Colors.white70)),
                      ],
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      height: 180,
                      child: LineChart(
                        LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: _mowingStats,
                              isCurved: true,
                              color: Colors.orange,
                              barWidth: 3,
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.orange.withAlpha(60),
                              ),
                              dotData: FlDotData(show: false),
                            ),
                          ],
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, _) {
                                  const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
                                  return Text(days[v.toInt()],
                                      style: GoogleFonts.robotoMono(
                                          color: Colors.white70, fontSize: 10));
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true),
                            ),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              tooltipRoundedRadius: 8,
                              fitInsideHorizontally: true, // 👈 this is the key fix
                              fitInsideVertically: true,   // 👈 useful if you ever want to fix vertical overflow too
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  return LineTooltipItem(
                                    'Day: ${['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][spot.x.toInt()]}\n'
                                        'Hours: ${spot.y.toStringAsFixed(1)}',
                                    GoogleFonts.robotoMono(color: Colors.orangeAccent),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white)),
        color: const Color(0xFF2B3746),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.robotoMono(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineBar(List<_Segment> segments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: segments.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final seg = segments[i];
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Colors.orangeAccent, Colors.deepOrange],
                      ),
                    ),
                    child: Text(
                      '${seg.start} → ${seg.end}',
                      style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingList(List<_Job> jobs) {
    if (jobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 20,),
          child: Text(
            'No upcoming schedules to show',
            style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 14),
          ),
        ),
      );
    }

    return Column(
      children: jobs.map((job) {
        return ListTile(
          dense: true,
          leading: const Icon(Icons.schedule, color: Colors.orange),
          title: Text(job.days, style: GoogleFonts.robotoMono(color: Colors.white)),
          subtitle: Text('${job.start} → ${job.end}',
              style: GoogleFonts.robotoMono(color: Colors.white70)),
        );
      }).toList(),
    );
  }


}

// ── Supporting Models ─────────────────────────────────────────────
class _Segment {
  final String start, end;
  _Segment(this.start, this.end);
}

class _Job {
  final String days, start, end;
  _Job(this.days, this.start, this.end);
}

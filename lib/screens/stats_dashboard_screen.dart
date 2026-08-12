import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/note_provider.dart';
import '../models/note.dart';
import 'package:intl/intl.dart';

class StatsDashboardScreen extends StatefulWidget {
  const StatsDashboardScreen({super.key});

  @override
  State<StatsDashboardScreen> createState() => _StatsDashboardScreenState();
}

class _StatsDashboardScreenState extends State<StatsDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NoteProvider>(context, listen: false).fetchTrashNotes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context);
    final allNotes = noteProvider.notes;
    final trashNotes = noteProvider.trashNotes;

    int totalNotes = allNotes.length;
    int encryptedNotes = allNotes.where((n) => n.isEncrypted).length;
    int deletedNotes = trashNotes.length;

    Map<String, int> categoryCounts = {};
    for (var note in allNotes) {
      categoryCounts[note.category] = (categoryCounts[note.category] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الإحصائيات'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildQuickStats(totalNotes, encryptedNotes, deletedNotes),
            const SizedBox(height: 24),
            _buildCategoryChart(categoryCounts),
            const SizedBox(height: 24),
            _buildNotesOverTimeChart(allNotes),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(int total, int encrypted, int deleted) {
    return Row(
      children: [
        _statCard('إجمالي الملاحظات', total.toString(), Colors.blue),
        _statCard('المشفرة', encrypted.toString(), Icons.lock),
        _statCard('في السلة', deleted.toString(), Colors.red),
      ],
    );
  }

  Widget _statCard(String title, String value, dynamic colorOrIcon) {
    return Expanded(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              if (colorOrIcon is IconData)
                Icon(colorOrIcon, color: Colors.blueGrey)
              else
                Container(width: 10, height: 10, decoration: BoxDecoration(color: colorOrIcon as Color, shape: BoxShape.circle)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChart(Map<String, int> counts) {
    if (counts.isEmpty) return const SizedBox.shrink();

    List<PieChartSectionData> sections = [];
    int i = 0;
    final colors = [Colors.blue, Colors.green, Colors.purple, Colors.orange, Colors.red];
    
    counts.forEach((cat, count) {
      sections.add(PieChartSectionData(
        color: colors[i % colors.length],
        value: count.toDouble(),
        title: '$cat\n$count',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      i++;
    });

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('الملاحظات حسب الفئة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(PieChartData(sections: sections)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesOverTimeChart(List<Note> notes) {
    if (notes.isEmpty) return const SizedBox.shrink();

    // Group notes by day for the last 7 days
    Map<String, int> dailyCounts = {};
    DateTime now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      String dateStr = DateFormat('MM/dd').format(now.subtract(Duration(days: i)));
      dailyCounts[dateStr] = 0;
    }

    for (var note in notes) {
      DateTime dt = DateTime.fromMillisecondsSinceEpoch(note.timestamp);
      String dateStr = DateFormat('MM/dd').format(dt);
      if (dailyCounts.containsKey(dateStr)) {
        dailyCounts[dateStr] = dailyCounts[dateStr]! + 1;
      }
    }

    List<BarChartGroupData> barGroups = [];
    int index = 0;
    dailyCounts.entries.toList().reversed.forEach((entry) {
      barGroups.add(BarChartGroupData(
        x: index,
        barRods: [BarChartRodData(toY: entry.value.toDouble(), color: Colors.blue, width: 16)],
      ));
      index++;
    });

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('النشاط الأخير (آخر 7 أيام)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int idx = value.toInt();
                          if (idx >= 0 && idx < dailyCounts.length) {
                            return Text(dailyCounts.keys.toList().reversed.toList()[idx], style: const TextStyle(fontSize: 10));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

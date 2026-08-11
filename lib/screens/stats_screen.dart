import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/library_provider.dart';

enum _Granularity { year, month }

/// Statistiche di lettura: andamento negli anni (o nei mesi) di libri e pagine.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  _Granularity _granularity = _Granularity.year;

  static const _mesi = [
    'gen', 'feb', 'mar', 'apr', 'mag', 'giu',
    'lug', 'ago', 'set', 'ott', 'nov', 'dic',
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibraryProvider>();
    final byMonth = _granularity == _Granularity.month;

    final booksMap =
        byMonth ? provider.booksReadPerMonth() : provider.booksReadPerYear();
    final pagesMap =
        byMonth ? provider.pagesReadPerMonth() : provider.pagesReadPerYear();

    // Chiavi ordinate (anno oppure anno*100+mese) e relative etichette.
    final keys = <int>{...booksMap.keys, ...pagesMap.keys}.toList()..sort();
    final labels = keys.map((k) => _label(k, byMonth)).toList();
    final booksValues = keys.map((k) => booksMap[k] ?? 0).toList();
    final pagesValues = keys.map((k) => pagesMap[k] ?? 0).toList();

    final totalBooks = booksValues.fold<int>(0, (a, b) => a + b);
    final totalPages = pagesValues.fold<int>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistiche di lettura')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<_Granularity>(
              segments: const [
                ButtonSegment(
                    value: _Granularity.year,
                    label: Text('Per anno'),
                    icon: Icon(Icons.calendar_today)),
                ButtonSegment(
                    value: _Granularity.month,
                    label: Text('Per mese'),
                    icon: Icon(Icons.calendar_view_month)),
              ],
              selected: {_granularity},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  setState(() => _granularity = s.first),
            ),
          ),
          Expanded(
            child: keys.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Nessuna lettura registrata.\n\nAggiungi le date di lettura '
                        'ai libri (in modifica) per vedere qui l\'andamento.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _summaryTile(context, '$totalBooks',
                                'Libri letti', Icons.menu_book),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _summaryTile(context, _fmt(totalPages),
                                'Pagine lette', Icons.auto_stories),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _chartCard(
                        context,
                        title: byMonth
                            ? 'Libri letti per mese'
                            : 'Libri letti per anno',
                        labels: labels,
                        values: booksValues,
                        color: const Color(0xFF3E7C88),
                      ),
                      const SizedBox(height: 24),
                      _chartCard(
                        context,
                        title: byMonth
                            ? 'Pagine lette per mese'
                            : 'Pagine lette per anno',
                        labels: labels,
                        values: pagesValues,
                        color: const Color(0xFFD9654E),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Le riletture vengono conteggiate ogni volta, in base alla '
                        'data di fine lettura.',
                        style: TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _label(int key, bool byMonth) {
    if (!byMonth) return '$key';
    final year = key ~/ 100;
    final month = key % 100;
    return '${_mesi[(month - 1).clamp(0, 11)]} ${year % 100}';
  }

  Widget _summaryTile(
      BuildContext context, String value, String label, IconData icon) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _chartCard(
    BuildContext context, {
    required String title,
    required List<String> labels,
    required List<int> values,
    required Color color,
  }) {
    final maxVal = values.fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = (maxVal <= 0 ? 1 : maxVal) * 1.2;
    // Con molte barre riduciamo la larghezza e mostriamo un'etichetta ogni N.
    final n = labels.length;
    final barWidth = n > 24 ? 6.0 : (n > 12 ? 10.0 : 18.0);
    final labelStep = (n / 12).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                    '${labels[group.x]}\n${rod.toY.round()}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (value, meta) {
                      if (value != value.roundToDouble()) {
                        return const SizedBox.shrink();
                      }
                      return Text(_fmt(value.round()),
                          style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      if (i < 0 || i >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      // Con troppe barre mostriamo solo alcune etichette.
                      if (labelStep > 1 && i % labelStep != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(labels[i],
                            style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (int i = 0; i < labels.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i].toDouble(),
                        color: color,
                        width: barWidth,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

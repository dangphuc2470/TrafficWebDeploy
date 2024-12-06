import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class VehicleDataPoint {
  final double count;
  final DateTime timestamp;

  VehicleDataPoint(this.count, this.timestamp);
}

class TrafficLineChart extends StatefulWidget {
  const TrafficLineChart({super.key});

  @override
  TrafficLineChartState createState() => TrafficLineChartState();
}

class TrafficLineChartState extends State<TrafficLineChart> {
  List<List<VehicleDataPoint>> laneVehicleHistory = List.generate(4, (_) => []);
  List<double> lastKnownVehicleCounts = List.filled(4, 0);
  static const int MINUTES_TO_KEEP = 10;

  @override
  void initState() {
    super.initState();
    _setupFirebaseListener();
  }

  void _setupFirebaseListener() {
    final databaseReference = FirebaseDatabase.instance
        .ref('traffic_system/intersections/main_intersection/lanes');

    databaseReference.onValue.listen((event) {
      if (event.snapshot.value == null) return;

      List<dynamic> lanes = event.snapshot.value as List<dynamic>;
      DateTime currentTime = DateTime.now();
      bool needsUpdate = false;

      for (int i = 1; i < lanes.length; i++) {
        if (lanes[i] == null) continue;

        double vehicleCount = (lanes[i]['vehicle_count'] ?? 0).toDouble();
        if ((vehicleCount - lastKnownVehicleCounts[i-1]).abs() >= 1) {
          needsUpdate = true;
          lastKnownVehicleCounts[i-1] = vehicleCount;

          // Remove data points older than MINUTES_TO_KEEP minutes
          laneVehicleHistory[i-1].removeWhere((point) =>
          currentTime.difference(point.timestamp).inMinutes >= MINUTES_TO_KEEP);

          laneVehicleHistory[i-1].add(VehicleDataPoint(vehicleCount, currentTime));
        }
      }

      if (needsUpdate) {
        setState(() {});
      }
    });
  }

  Widget buildChart(BuildContext context) {
    int maxPoints = laneVehicleHistory.fold(0,
            (max, lane) => lane.length > max ? lane.length : max);

    return LineChart(
      LineChartData(
        lineBarsData: _generateLineBarData(maxPoints),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxPoints > 10 ? (maxPoints / 10).ceil().toDouble() : 1,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index >= maxPoints) return const Text('');

                DateTime pointTime = laneVehicleHistory
                    .firstWhere((lane) => lane.length > index)
                    .elementAt(index)
                    .timestamp;

                int secondsAgo = DateTime.now().difference(pointTime).inSeconds;
                return Text('${secondsAgo}s',
                    style: TextStyle(fontSize: 10));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(value.toInt().toString());
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        gridData: FlGridData(show: true),
        minX: 0,
        maxX: (maxPoints - 1).toDouble(),
      ),
    );
  }

  List<LineChartBarData> _generateLineBarData(int maxPoints) {
    List<Color> laneColors = [Colors.blue, Colors.green, Colors.red, Colors.purple];

    return List.generate(laneVehicleHistory.length, (laneIndex) {
      var laneData = laneVehicleHistory[laneIndex];

      return LineChartBarData(
        isCurved: true,
        color: laneColors[laneIndex],
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: FlDotData(show: true),
        belowBarData: BarAreaData(show: false),
        spots: List.generate(laneData.length, (i) =>
            FlSpot(i.toDouble(), laneData[i].count)
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.7,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: buildChart(context),
      ),
    );
  }
}
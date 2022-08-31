import 'package:flutter/material.dart';
import 'package:fcharts/fcharts.dart';
import './dataSpot.dart';
import 'dart:math';

class ChartGraph extends StatelessWidget {
  List<DataSpot> _data = [];
  Color _spotColor;
  String _vText;
  String _timeText;

  ChartGraph(this._data, this._spotColor, this._timeText, this._vText);
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
        aspectRatio: 4 / 3,
        child: LineChart(
          chartPadding:
              EdgeInsets.only(left: 50, right: 50, top: 20, bottom: 20),
          lines: [
            new Line<DataSpot, int, double>(
              data: _data,
              xFn: (dataspot) => dataspot.time,
              yFn: (dataspot) => dataspot.voltage,
              xAxis: ChartAxis(
                span:  _data.isNotEmpty ? IntSpan(_data[0].time, _data[_data.length - 1].time): IntSpan(0,0),
              ),
              yAxis: ChartAxis(
                  span: _data.isNotEmpty ? DoubleSpan(
                (() {
                  List<num> values = [];
                  for (DataSpot s in _data) {
                    values.add(s.voltage);
                  }
                  return double.parse(values.fold(values[0], min).toString());
                })(),
                (() {
                  List<num> values = [];
                  for (DataSpot s in _data) {
                    values.add(s.voltage);
                  }
                  return double.parse(values.fold(values[0], min).toString());
                })(),
              ): DoubleSpan(0, 0)
		  ),
              marker: MarkerOptions(
                paint: PaintOptions.fill(color: _spotColor),
                shape: MarkerShapes.circle,
              ),
              stroke: PaintOptions.stroke(color: _spotColor),
              legend: LegendItem(
                paint: const PaintOptions.fill(color: Colors.green),
                text: 'Voltage',
              ),
            )
          ],
        ));
  }
}

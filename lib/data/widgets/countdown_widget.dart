import 'package:flutter/material.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../constants.dart';

class CountdownDialog extends StatefulWidget {
  final int seconds;

  const CountdownDialog({super.key, required this.seconds});

  @override
  CountdownDialogState createState() => CountdownDialogState();
}

class CountdownDialogState extends State<CountdownDialog> {
  late int _remaining;
  Timer? _timer;
  double _progress = 1.0;
  final player = AudioPlayer();
  bool _isAlarmPlaying = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (_remaining < 1) {
        await _playChime();
        timer.cancel();
        setState(() {
          _isAlarmPlaying = true;
        });
      } else {
        setState(() {
          _remaining--;
          _progress = _remaining / widget.seconds;
        });
      }
    });
  }

  Future<void> _playChime() async {
    await player.setReleaseMode(ReleaseMode.loop); // alarm sound on loop
    await player.play(AssetSource('sounds/alarm.mp3'));
  }

  void _stopAlarm() {
    player.stop();
    setState(() {
      _isAlarmPlaying = false;
    });
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Timer", style: TextStyles.dialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularPercentIndicator(
            radius: 80.0,
            lineWidth: 20.0,
            percent: _progress,
            center: Text(
              '$_remaining s',
              style: TextStyles.titleText,
            ),
            progressColor: primaryColor,
            backgroundColor: dullColor,
            circularStrokeCap: CircularStrokeCap.butt,
          ),
        ],
      ),
      actions: [
        if (_isAlarmPlaying)
          TextButton(onPressed: _stopAlarm, child: Text("Stop Alarm"))
        else
          TextButton(
            child: Text("Cancel"),
            onPressed: () {
              _timer?.cancel();
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

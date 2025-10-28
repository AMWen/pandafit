import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/localdb_service.dart';

class PandaStreakWidget extends StatefulWidget {
  const PandaStreakWidget({super.key});

  @override
  State<PandaStreakWidget> createState() => PandaStreakWidgetState();
}

class PandaStreakWidgetState extends State<PandaStreakWidget> {
  int _streak = 0;
  bool _todayCompleted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  void _loadStreak() async {
    final dates = await LocalDB.getLoggedDates();
    final result = _calculateStreak(dates);

    setState(() {
      _streak = result.streak;
      _todayCompleted = result.todayCompleted;
      _isLoading = false;
    });
  }

  ({int streak, bool todayCompleted}) _calculateStreak(List<DateTime> dates) {
    if (dates.isEmpty) return (streak: 0, todayCompleted: false);

    final dateSet = dates.map((d) => DateTime(d.year, d.month, d.day)).toSet();

    int streak = 0;
    DateTime current = DateTime.now();
    bool todayCompleted = false;

    if (dateSet.contains(DateTime(current.year, current.month, current.day))) {
      streak++;
      todayCompleted = true;
    }
    current = current.subtract(Duration(days: 1));

    while (dateSet.contains(DateTime(current.year, current.month, current.day))) {
      streak++;
      current = current.subtract(Duration(days: 1));
    }

    return (streak: streak, todayCompleted: todayCompleted);
  }

  // Public method to allow parent widgets to refresh the streak
  void refresh() {
    _loadStreak();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox.shrink();
    }

    if (_streak == 0) {
      return Column(
        children: [
          SizedBox(height: 16),
          Text("Let's start powering up your panda!", style: TextStyles.mediumText),
          Image.asset('assets/images/sad_baby_panda.png', width: pandaWidth),
        ],
      );
    }

    if (_streak > 0 && _streak < 3) {
      return Column(
        children: [
          SizedBox(height: 16),
          Text(
            _todayCompleted
                ? (_streak == 1 ? '1 day completed! Way to go!' : '🔥 $_streak day streak!')
                : 'Keep going! Extend your streak to ${_streak + 1} days!',
            style: TextStyles.mediumText,
          ),
          Image.asset('assets/images/baby_panda.png', width: pandaWidth),
        ],
      );
    }

    if (_streak >= 3 && _streak < 7) {
      return Column(
        children: [
          SizedBox(height: 16),
          Text(
            _todayCompleted
                ? "You're a beast! 🔥 $_streak day streak"
                : 'Keep going! Extend your streak to ${_streak + 1} days!',
            style: TextStyles.mediumText,
          ),
          Image.asset('assets/images/strong_panda.png', width: pandaWidth),
        ],
      );
    }

    // _streak >= 7
    return Column(
      children: [
        SizedBox(height: 16),
        Text(
          _todayCompleted
              ? "You're unstoppable! 🔥💪 $_streak day streak!"
              : 'Keep the momentum! Extend your streak to ${_streak + 1} days!',
          style: TextStyles.mediumText,
        ),
        Image.asset('assets/images/super_strong_panda.png', width: pandaWidth),
      ],
    );
  }
}

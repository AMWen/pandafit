import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import '../data/constants.dart';

class OnboardingPage extends StatelessWidget {
  final VoidCallback onDone;

  const OnboardingPage({super.key, required this.onDone});

  List<PageViewModel> getPages(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final width = screenWidth / 2.5;

    return [
      PageViewModel(
        title: "Welcome to PandaFit",
        body:
            "Your personal workout companion! Track all your workouts in a single offline app.\n\n"
            "No account needed, your data stays with you!",
        image: Center(
          child: Container(
            width: screenWidth / 2,
            height: screenWidth / 2,
            color: Colors.grey[300],
            child: Center(
              child: Text(
                'PandaFit Logo\n🐼💪',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
      PageViewModel(
        title: "Daily Auto-Generated Workouts",
        body:
            "Fresh workouts are randomly generated every day, with exercises that specifically target various muscle groups.\n\n"
            "Simply select the type of workout you want to do for the day to get started!\n\n"
            "Tip: for Core, each side counts as 1 rep, but feel free to challenge yourself if you want to go for more!",
        image: Center(
          child: Container(
            width: width,
            height: width * 1.5,
            color: Colors.grey[300],
            child: Center(
              child: Text(
                'Screenshot:\nHome screen with\nUpper/Lower/Core tabs\nshowing today\'s workouts',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
      ),
      PageViewModel(
        title: "Tailor Your Workout",
        body:
            "Mark exercises as complete, skip them, or adjust weights as you go. Each exercise includes video links, form notes, and target muscles.\n\n"
            "Listen to your body! Reduce weight or reps as needed, or skip exercises — there's no shame in modifying your workout.\n\n"
            "Starting out? Celebrate every attempt! Your progress is automatically saved.",
        image: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: width,
                height: width * 1.5,
                color: Colors.grey[300],
                child: Center(
                  child: Text(
                    'Screenshot:\nExercise card with\ncheckboxes, weight,\nand skip button',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      PageViewModel(
        title: "Customize Your Experience",
        body:
            "Make this workout plan your own! Add custom exercises with notes and video links.\n\n"
            "Set preferences to always or never include certain exercises, and adjust workout settings like exercise counts per session.\n\n"
            "Remember: recovery is important. Pick and choose what works for you!",
        image: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: width,
                height: width * 1.5,
                color: Colors.grey[300],
                child: Center(
                  child: Text(
                    'Screenshot:\nSettings screen with\ncustom exercises\nand preferences',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      PageViewModel(
        title: "Log Other Activities",
        body:
            "Track cardio, sports, yoga, or any other activity!\n\n"
            "Add custom activities with duration tracking.\n\n"
            "Save your favorite activities for quick logging.",
        image: Center(
          child: Container(
            width: width,
            height: width * 1.5,
            color: Colors.grey[300],
            child: Center(
              child: Text(
                'Screenshot:\nActivities tab showing\ncustom activities like\nRunning, Yoga, etc.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
      ),
      PageViewModel(
        title: "View Your History & Streaks",
        body:
            "See your workout calendar with color-coded markers for different workout types.\n\n"
            "Track your streak and stay motivated!\n\n"
            "Review detailed history for each workout type with expandable entries.",
        image: Center(
          child: Container(
            width: width,
            height: width * 1.5,
            color: Colors.grey[300],
            child: Center(
              child: Text(
                'Screenshot:\nHistory tab with calendar,\nstreak widget,\nand workout history list',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
      ),
      PageViewModel(
        title: "Export & Import Your Data",
        body:
            "Export all your workout data to Excel with organized sheets.\n\n"
            "View your progress over time in easy-to-read tables.\n\n"
            "Import data selectively when migrating to a new device — choose what to replace or merge!",
        image: Center(
          child: Container(
            width: width,
            height: width * 1.5,
            color: Colors.grey[300],
            child: Center(
              child: Text(
                'Screenshot:\nImport dialog with\ncheckboxes for\nworkout history and settings',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: IntroductionScreen(
        dotsDecorator: DotsDecorator(activeColor: primaryColor),
        pages: getPages(context),
        onDone: onDone,
        showSkipButton: true,
        skip: const Text("Skip"),
        next: const Icon(Icons.arrow_forward),
        done: const Text("Done", style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import '../data/constants.dart';

class OnboardingPage extends StatelessWidget {
  final VoidCallback onDone;

  const OnboardingPage({super.key, required this.onDone});

  List<PageViewModel> getPages(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final width = screenWidth / 2.5;
    final spacing = screenWidth / 70;

    return [
      PageViewModel(
        title: "Welcome to PandaFit",
        bodyWidget: const Text(
          "Say hi to your 🐼 workout companion, and track all your workouts in one app!\n\n"
          "No account needed, your data stays with you!",
          textAlign: TextAlign.left,
          style: TextStyle(fontSize: 18),
        ),
        image: Center(
          child: Center(child: Image.asset("assets/images/small_icon.png", width: screenWidth / 2)),
        ),
      ),
      PageViewModel(
        title: "Daily Auto-Generated Workouts",
        bodyWidget: const Text(
          "Fresh workouts are randomly generated for you, targeting various muscle groups. No decision paralysis here!\n\n"
          "Simply select the type of workout you want to do for the day to get started.\n\n"
          "Friends see the same workout, so you can challenge them to join you! 🔥",
          textAlign: TextAlign.left,
          style: TextStyle(fontSize: 18),
        ),
        image: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset("assets/images/screenshots/2a_upper_body.png", width: width),
                SizedBox(width: spacing),
                Image.asset("assets/images/screenshots/2b_lower_body.png", width: width),
                SizedBox(width: spacing),
                Image.asset("assets/images/screenshots/2c_core.png", width: width),
              ],
            ),
          ),
        ),
      ),
      PageViewModel(
        title: "Explore New Exercises",
        bodyWidget: const Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 18),
            text:
                "Not sure how to do an exercise? No problem!\n\n"
                "Links to videos demonstrating the movements are included, along with form notes and target muscles.\n\n",
            children: [
              TextSpan(text: "Tip:", style: TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(
                text:
                    " Core lets you catch up if you missed yesterday's workout.\n\n"
                    "Each side counts as 1 rep (e.g., 12 side crunches = 6 per side). Feel free to challenge yourself and go for more, or adjust down as needed!",
              ),
            ],
          ),
          textAlign: TextAlign.left,
        ),
        image: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset("assets/images/screenshots/3a_form_notes.png", width: width),
                SizedBox(width: spacing),
                Image.asset("assets/images/screenshots/3b_inline_video.png", width: width),
              ],
            ),
          ),
        ),
      ),
      PageViewModel(
        title: "Customize Your Experience",
        bodyWidget: const Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 18),
            children: [
              TextSpan(
                text:
                    "Make this workout plan your own! Add your ✨ favorite exercises ✨ and set preferences to ",
              ),
              TextSpan(
                text: "include",
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
              TextSpan(text: " or "),
              TextSpan(
                text: "exclude",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    " certain movements.\n\n"
                    "Adjust weight and reps, or skip and take recovery time as needed.\n\n"
                    "Your workout, your rules, do what fits your goals!",
              ),
            ],
          ),
          textAlign: TextAlign.left,
        ),
        image: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset("assets/images/screenshots/4a_skip_progression.png", width: width),
                SizedBox(width: spacing),
                Image.asset("assets/images/screenshots/4b_workout_settings.png", width: width),
              ],
            ),
          ),
        ),
      ),
      PageViewModel(
        title: "Log Other Activities",
        bodyWidget: const Text(
          "Track cardio ❤️, yoga 🧘, or any other activity!\n\n"
          "Previous activities are stored for quick logging.",
          textAlign: TextAlign.left,
          style: TextStyle(fontSize: 18),
        ),
        image: Center(
          child: Image.asset("assets/images/screenshots/5_actiities.png", width: width),
        ),
      ),
      PageViewModel(
        title: "View Your History & Streaks",
        bodyWidget: const Text(
          "See your workout history with color-coded markers for different workout types.\n\n"
          "Watch your 🐼 grow stronger as you maintain your streak!\n\n"
          "Monitor your progress over time with detailed history for each workout type.",
          textAlign: TextAlign.left,
          style: TextStyle(fontSize: 18),
        ),
        image: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset("assets/images/screenshots/6a_panda_progression.png", width: width),
                SizedBox(width: spacing),
                Image.asset("assets/images/screenshots/6b_panda_strong.png", width: width),
                SizedBox(width: spacing),
                Image.asset("assets/images/screenshots/6c_workout_history.png", width: width),
              ],
            ),
          ),
        ),
      ),
      PageViewModel(
        title: "Export & Import Your Data",
        bodyWidget: const Text(
          "Export all your workout data to Excel with organized sheets in order to view your progress over time in editable tables.\n\n"
          "Migrating devices? You can selectively import workout history and preferences!",
          textAlign: TextAlign.left,
          style: TextStyle(fontSize: 18),
        ),
        image: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset("assets/images/screenshots/7a_import_export.png", width: width),
                SizedBox(width: spacing),
                Image.asset("assets/images/screenshots/7b_import_options.png", width: width),
              ],
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
        dotsDecorator: DotsDecorator(
          activeColor: primaryColor,
          size: const Size(6.0, 6.0),
          activeSize: const Size(8.0, 8.0),
          spacing: const EdgeInsets.symmetric(horizontal: 3.0),
        ),
        controlsPadding: const EdgeInsets.symmetric(horizontal: 4.0),
        bodyPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        pages: getPages(context),
        onDone: onDone,
        showSkipButton: true,
        showBackButton: true,
        skip: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Text("Skip", style: TextStyle(fontSize: 16)),
        ),
        back: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Icon(Icons.arrow_back, size: 20),
        ),
        next: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Icon(Icons.arrow_forward, size: 20),
        ),
        done: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Text("Done", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ),
    );
  }
}

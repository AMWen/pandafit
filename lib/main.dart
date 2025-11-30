import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding.dart';
import 'data/constants.dart';
import 'data/models/custom_exercise_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure edge-to-edge mode for system UI
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Hive
  await Hive.initFlutter();

  // Register Hive adapters
  Hive.registerAdapter(ExerciseCategoryAdapter());
  Hive.registerAdapter(CustomExercisePreferenceAdapter());
  Hive.registerAdapter(UserCustomExerciseAdapter());
  Hive.registerAdapter(UserActivityAdapter());
  Hive.registerAdapter(WorkoutGenerationPreferencesAdapter());

  runApp(const MyApp());
}

class SwipeScreens extends StatelessWidget {
  const SwipeScreens({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        children: [
          HomeScreen(),
          HistoryScreen(),
        ],
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showOnboarding = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    setState(() {
      _showOnboarding = !hasSeenOnboarding;
      _isLoading = false;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panda Fit',
      theme: ThemeData(
        colorSchemeSeed: primaryColor,
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          titleTextStyle: TextStyles.titleText,
          iconTheme: IconThemeData(color: secondaryColor),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
          foregroundColor: secondaryColor,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            side: BorderSide(color: primaryColor),
          ),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: secondaryColor,
          selectionColor: secondaryColor.withValues(alpha: 0.3),
          selectionHandleColor: secondaryColor,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(primary: primaryColor, secondary: secondaryColor),
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          titleTextStyle: TextStyles.titleText,
          iconTheme: IconThemeData(color: secondaryColor),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
          foregroundColor: secondaryColor,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            side: BorderSide(color: primaryColor),
          ),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: secondaryColor,
          selectionColor: secondaryColor.withValues(alpha: 0.3),
          selectionHandleColor: secondaryColor,
        ),
      ),
      home: _isLoading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _showOnboarding
              ? OnboardingPage(onDone: _completeOnboarding)
              : const SwipeScreens(),
      debugShowCheckedModeBanner: false,
    );
  }
}

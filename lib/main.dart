import 'package:flutter/material.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'data/constants.dart';

void main() => runApp(MyApp());

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      ),
      home: SwipeScreens(),
      debugShowCheckedModeBanner: false,
    );
  }
}

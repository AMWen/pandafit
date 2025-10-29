import 'package:flutter/material.dart';

import 'models/exercise_model.dart';
import 'models/core_exercise_model.dart';

Color primaryColor = Color.fromARGB(255, 3, 78, 140);
Color secondaryColor = Colors.grey[200]!;
Color dullColor = Colors.grey[500]!;
double pandaWidth = 200;

// Calendar marker colors for different workout types
class WorkoutColors {
  static const Color upperBody = Color(0xFF2196F3); // Blue
  static const Color lowerBody = Color(0xFFFF9800); // Orange
  static const Color core = Color(0xFF4CAF50); // Green
  static const Color mixed = Color(0xFF9C27B0); // Purple (when multiple types completed)

  // Helper to get color for a specific muscle group
  static Color forMuscleGroup(MuscleGroup group) {
    switch (group) {
      case MuscleGroup.upperBody:
        return upperBody;
      case MuscleGroup.lowerBody:
        return lowerBody;
      case MuscleGroup.core:
        return core;
    }
  }
}

// Format weight to show decimals only when necessary
String formatWeight(double weight) {
  if (weight == weight.roundToDouble()) {
    return weight.toInt().toString();
  }
  return weight.toString();
}

class TextStyles {
  static const TextStyle whiteText = TextStyle(color: Colors.white);
  static const TextStyle mediumText = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
  static const TextStyle normalText = TextStyle(fontSize: 16);
  static const TextStyle titleText = TextStyle(fontSize: 20, fontWeight: FontWeight.w500);
  static const TextStyle dialogTitle = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
  static const TextStyle labelText = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
  static const TextStyle inputText = TextStyle(fontSize: 14, fontWeight: FontWeight.normal);
  static const TextStyle hintText = TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic);
}

// Exercise Database - Easy to Extend!
// To add new exercises: Just add to the appropriate list below
class ExerciseDatabase {
  // Helper method to create exercises with auto-generated YouTube search links
  // Sets is always 3 for all exercises
  static Exercise createExercise({
    required String name,
    required MuscleGroup muscleGroup,
    List<String> targetMuscles = const [],
    String reps = "8-12",
    String notes = "",
    double? beginnerWeight,
  }) {
    final searchQuery = name.replaceAll(' ', '+').toLowerCase();
    return Exercise(
      name: name,
      muscleGroup: muscleGroup,
      targetMuscles: targetMuscles,
      reps: reps,
      videoLink: 'https://www.youtube.com/results?search_query=$searchQuery+dumbbell',
      notes: notes,
      weight: beginnerWeight,
    );
  }

  // CHEST EXERCISES
  static final List<Exercise> chestExercises = [
    createExercise(
      name: "Incline Dumbbell Press",
      muscleGroup: MuscleGroup.upperBody,
      targetMuscles: ["Upper Pecs", "Front Delts"],
      reps: "8-12",
      notes: "Set bench to 30-45 degrees. Keep elbows at 45-degree angle from body. Press up and slightly inward at top. Retract shoulder blades throughout.",
      beginnerWeight: 15.0,
    ),
    createExercise(
      name: "Flat Dumbbell Press",
      muscleGroup: MuscleGroup.upperBody,
      targetMuscles: ["Mid Pecs", "Front Delts", "Triceps"],
      reps: "8-12",
      notes: "Lower dumbbells until elbows are at 90 degrees or slightly below chest level. Keep shoulder blades retracted. Press straight up, don't let dumbbells drift over face.",
      beginnerWeight: 15.0,
    ),
    createExercise(
      name: "Dumbbell Flys",
      muscleGroup: MuscleGroup.upperBody,
      targetMuscles: ["Pecs"],
      reps: "10-15",
      notes: "Keep slight bend in elbows (like hugging a tree). Lower until you feel a stretch in chest, don't go too deep. Focus on squeezing chest at top.",
      beginnerWeight: 10.0,
    ),
  ];

  // BACK EXERCISES
  static final List<Exercise> backExercises = [
    createExercise(
      name: "Chest-Supported Dumbbell Row",
      muscleGroup: MuscleGroup.upperBody,
      targetMuscles: ["Mid Back", "Lats"],
      reps: "10-12",
      notes: "Lie face down on incline bench. Pull elbows straight back past your torso. Squeeze shoulder blades together at top. Lead with elbows, not hands.",
      beginnerWeight: 15.0,
    ),
    createExercise(
      name: "Single-Arm Dumbbell Row",
      muscleGroup: MuscleGroup.upperBody,
      targetMuscles: ["Lats", "Mid Back"],
      reps: "10-12",
      notes: "Place knee and hand on bench. Keep back flat and parallel to floor. Pull weight toward hip, not straight up. Keep core tight. Control the descent.",
      beginnerWeight: 15.0,
    ),
    createExercise(
      name: "Dumbbell Pullover",
      muscleGroup: MuscleGroup.upperBody,
      targetMuscles: ["Lats", "Pecs"],
      reps: "10-12",
      notes: "Lie perpendicular on bench (shoulders only). Lower dumbbell behind head until you feel lat stretch. Keep slight bend in elbows. Pull back using lats, not arms.",
      beginnerWeight: 15.0,
    ),
  ];

  // SHOULDER EXERCISES
  static final List<Exercise> shoulderExercises = [
    createExercise(
      name: "Dumbbell Shoulder Press",
      muscleGroup: MuscleGroup.upperBody,
      targetMuscles: ["Front Delts", "Side Delts"],
      reps: "8-12",
      notes: "Start with dumbbells at shoulder height. Press straight up, rotating slightly inward at top. Keep core tight, avoid arching lower back. Lower with control.",
      beginnerWeight: 15.0,
    ),
    createExercise(
      name: "Lateral Raises",
      muscleGroup: MuscleGroup.upperBody,
      targetMuscles: ["Side Delts"],
      reps: "12-15",
      notes: "Keep slight bend in elbows. Raise arms out to sides until parallel to floor. Lead with elbows, pour pinky slightly upward at top. Control descent, don't let weights drop.",
      beginnerWeight: 10.0,
    ),
    createExercise(
      name: "Leaning Dumbbell Lateral Raise",
      muscleGroup: MuscleGroup.upperBody,
      targetMuscles: ["Side Delts"],
      reps: "12-15",
      notes: "Hold onto sturdy support with one hand. Lean away at angle. Raise dumbbell to side, emphasizing the stretch at bottom. Increases range of motion vs standard lateral raise.",
      beginnerWeight: 10.0,
    ),
    createExercise(
      name: "Reverse Flys",
      muscleGroup: MuscleGroup.upperBody,
      targetMuscles: ["Rear Delts", "Upper Back"],
      reps: "12-15",
      notes: "Hinge at hips until torso is near parallel to floor. Keep back flat, slight knee bend. Raise dumbbells out to sides, squeeze shoulder blades. Keep slight elbow bend throughout.",
      beginnerWeight: 10.0,
    ),
  ];

  // ARM EXERCISES
  static final List<Exercise> armExercises = [
    createExercise(
      name: "Incline Dumbbell Curls",
      muscleGroup: MuscleGroup.upperBody,
      targetMuscles: ["Biceps Long Head", "Brachialis"],
      reps: "10-12",
      notes: "Set bench to 45 degrees. Let arms hang straight down with full stretch. Curl up while keeping elbows stationary. Squeeze at top, control the descent. Don't swing.",
      beginnerWeight: 10.0,
    ),
    createExercise(
      name: "Preacher Curls",
      muscleGroup: MuscleGroup.upperBody,
      targetMuscles: ["Biceps Short Head", "Brachialis"],
      reps: "10-12",
      notes: "Rest upper arms on pad, keep armpits tight to top of pad. Curl up while keeping upper arms pressed down. Go to full extension at bottom. Control the negative phase.",
      beginnerWeight: 10.0,
    ),
    createExercise(
      name: "Hammer Curls",
      muscleGroup: MuscleGroup.upperBody,
      targetMuscles: ["Brachialis", "Biceps", "Forearms"],
      reps: "10-12",
      notes: "Hold dumbbells with palms facing each other (neutral grip). Keep elbows tight to sides. Curl straight up without rotating wrists. Squeeze at top, control descent.",
      beginnerWeight: 10.0,
    ),
    createExercise(
      name: "Overhead Tricep Extension",
      muscleGroup: MuscleGroup.upperBody,
      targetMuscles: ["Triceps Long Head"],
      reps: "10-12",
      notes: "Hold dumbbell overhead with both hands. Keep elbows pointed straight up and close to head. Lower behind head until you feel tricep stretch. Extend back up without moving elbows.",
      beginnerWeight: 10.0,
    ),
    createExercise(
      name: "Tricep Kickbacks",
      muscleGroup: MuscleGroup.upperBody,
      targetMuscles: ["Triceps"],
      reps: "12-15",
      notes: "Hinge at hips, keep back flat. Pin upper arm parallel to floor. Extend elbow fully until arm is straight, squeeze tricep hard. Only forearm should move.",
      beginnerWeight: 10.0,
    ),
  ];

  // LEG EXERCISES
  static final List<Exercise> legExercises = [
    createExercise(
      name: "Wide-Stance Bulgarian Split Squat",
      muscleGroup: MuscleGroup.lowerBody,
      targetMuscles: ["Glutes", "Hamstrings"],
      reps: "10-12",
      notes: "Place back foot on bench. Take longer step forward (wider stance). Keep torso upright. Descend until back knee nearly touches ground. Drive through front heel. Emphasizes glutes more than quads.",
      beginnerWeight: 20.0,
    ),
    createExercise(
      name: "Narrow-Stance Bulgarian Split Squat",
      muscleGroup: MuscleGroup.lowerBody,
      targetMuscles: ["Quads"],
      reps: "10-12",
      notes: "Place back foot on bench. Take shorter step forward (narrower stance). Allow front knee to travel forward over toes. Keep torso more upright. Targets quads more than glutes.",
      beginnerWeight: 20.0,
    ),
    createExercise(
      name: "Romanian Deadlift",
      muscleGroup: MuscleGroup.lowerBody,
      targetMuscles: ["Hamstrings", "Glutes"],
      reps: "10-12",
      notes: "Hold dumbbells at thighs. Hinge at hips by pushing butt back. Keep back flat, slight knee bend. Lower until you feel hamstring stretch (mid-shin). Squeeze glutes to return. Don't round back.",
      beginnerWeight: 20.0,
    ),
    createExercise(
      name: "Goblet Squat",
      muscleGroup: MuscleGroup.lowerBody,
      targetMuscles: ["Quads", "Glutes"],
      reps: "10-15",
      notes: "Hold dumbbell vertically at chest (like a goblet). Squat down keeping chest up. Push knees out, elbows go between knees. Go deep (below parallel if possible). Drive through heels.",
      beginnerWeight: 20.0,
    ),
    createExercise(
      name: "Reverse Nordic",
      muscleGroup: MuscleGroup.lowerBody,
      targetMuscles: ["Quads"],
      reps: "8-10",
      notes: "Kneel on pad, secure feet. Keep body straight from knees to shoulders. Lean back slowly under control. Go as far as comfortable. Return using quads. Very challenging - use assistance if needed.",
      beginnerWeight: 0.0,
    ),
    createExercise(
      name: "Sissy Squat",
      muscleGroup: MuscleGroup.lowerBody,
      targetMuscles: ["Quads"],
      reps: "8-10",
      notes: "Hold onto stable support. Rise on toes, push knees forward. Lean back while bending knees. Keep hips extended, body in straight line. Advanced exercise - start with partial range if needed.",
      beginnerWeight: 0.0,
    ),
    createExercise(
      name: "Dumbbell Lunges",
      muscleGroup: MuscleGroup.lowerBody,
      targetMuscles: ["Quads", "Glutes"],
      reps: "10-12",
      notes: "Hold dumbbells at sides. Step forward with one leg. Lower back knee toward ground (don't slam). Keep torso upright, front knee over ankle. Push through front heel to return. Alternate legs.",
      beginnerWeight: 20.0,
    ),
  ];
}

// Core workout routine options (sets x exercises per set)
final List<List<int>> coreRoutineOptions = [
  [1, 7], // # sets of # exercises
  [2, 4],
  [2, 5],
  [2, 6],
  [3, 3],
  [3, 4],
];

// Core exercise pool with all core exercises
final List<CoreExercise> coreExercisePool = [
  CoreExercise(name: 'Crunches', amount: 25, increment: 5, videoLink: 'https://youtu.be/s0j8dENaT1g'),
  CoreExercise(
    name: 'Side Crunches',
    amount: 30,
    increment: 2,
    videoLink: 'https://youtu.be/q0QyCrpiNgI',
  ),
  CoreExercise(
    name: 'Alternating Crunches',
    amount: 16,
    increment: 2,
    videoLink: 'https://youtu.be/2IzByyOeGIQ',
  ),
  CoreExercise(
    name: 'Crunch Twists',
    amount: 16,
    increment: 2,
    videoLink: 'https://youtu.be/3lEKIInCo2o',
  ),
  CoreExercise(
    name: 'Reverse Crunches',
    amount: 15,
    increment: 5,
    videoLink: 'https://youtu.be/llXzSzEdNss',
  ),
  CoreExercise(
    name: 'Elevated Crunches',
    amount: 15,
    increment: 5,
    videoLink: 'https://youtu.be/ixH4kRjxqb4',
  ),
  CoreExercise(
    name: 'Body Crunches',
    amount: 15,
    increment: 5,
    videoLink: 'https://youtu.be/ixwJ6A8qyuA',
  ),
  CoreExercise(name: 'Side Bends', amount: 20, increment: 2, videoLink: 'https://youtu.be/FRDPoaiD1DQ'),
  CoreExercise(name: 'V-Ups', amount: 10, increment: 2, videoLink: 'https://youtu.be/WAcaMktW7j0'),
  CoreExercise(
    name: 'Oblique V-Ups',
    amount: 12,
    increment: 4,
    videoLink: 'https://youtu.be/zXa8d5kYqAI',
  ),
  CoreExercise(name: 'Corkscrews', amount: 12, increment: 2, videoLink: 'https://youtu.be/XjyC3bnrB7o'),
  CoreExercise(name: 'Twists', amount: 20, increment: 2, videoLink: 'https://youtu.be/cOAvMdawV90'),
  CoreExercise(
    name: 'Russian Twists',
    amount: 16,
    increment: 2,
    videoLink: 'https://youtu.be/gEFbg0AXowo',
  ),
  CoreExercise(
    name: 'Leg Lifts',
    amount: 9,
    increment: 3,
    videoLink: 'https://youtu.be/lktF6euie0o',
  ),
  CoreExercise(
    name: 'Pulse Ups',
    amount: 10,
    increment: 2,
    videoLink: 'https://youtu.be/v30TIy18LEo',
  ),
  CoreExercise(
    name: 'Pendulums',
    amount: 12,
    increment: 2,
    videoLink: 'https://youtu.be/u4JkRwCc13E',
  ),
  CoreExercise(
    name: 'Scissors',
    amount: 40,
    increment: 2,
    videoLink: 'https://youtu.be/yY9yfNQzz04',
  ),
  CoreExercise(
    name: 'Mountain Climbers',
    amount: 20,
    increment: 2,
    videoLink: 'https://youtu.be/kLh-uczlPLg',
  ),
  CoreExercise(
    name: 'Push Throughs',
    amount: 20,
    increment: 5,
    videoLink: 'https://youtu.be/iL__5TqPAfU',
  ),
  CoreExercise(name: 'Bicycles', amount: 20, increment: 2, videoLink: 'https://youtu.be/251erijgyA0'),
  CoreExercise(
    name: 'Planks Knee to Elbow',
    amount: 16,
    increment: 2,
    videoLink: 'https://youtu.be/Po3ltHqnnC0',
  ),
  CoreExercise(
    name: 'Plank',
    amount: 30,
    isTimed: true,
    increment: 15,
    videoLink: 'https://youtu.be/hvZbp_3O9rI',
  ),
  CoreExercise(
    name: 'Side Plank',
    amount: 30,
    isTimed: true,
    increment: 15,
    videoLink: 'https://youtu.be/6--6Q-dPYns',
  ),
  CoreExercise(
    name: 'Hollow Rock Hold',
    amount: 10,
    isTimed: true,
    increment: 5,
    videoLink: 'https://youtu.be/7QMpN9uFHeI',
  ),
  CoreExercise(name: 'Goalies', amount: 20, increment: 2, videoLink: 'https://youtu.be/gDrMWkoQ1rY'),
];


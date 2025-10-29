// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_exercise_preferences.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomExercisePreferenceAdapter
    extends TypeAdapter<CustomExercisePreference> {
  @override
  final int typeId = 1;

  @override
  CustomExercisePreference read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomExercisePreference(
      exerciseName: fields[0] as String,
      alwaysInclude: fields[1] as bool,
      customStartingWeight: fields[2] as double?,
      customRepRange: fields[3] as String?,
      neverInclude: fields[4] as bool,
      customNotes: fields[5] as String?,
      customVideoLink: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CustomExercisePreference obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.exerciseName)
      ..writeByte(1)
      ..write(obj.alwaysInclude)
      ..writeByte(2)
      ..write(obj.customStartingWeight)
      ..writeByte(3)
      ..write(obj.customRepRange)
      ..writeByte(4)
      ..write(obj.neverInclude)
      ..writeByte(5)
      ..write(obj.customNotes)
      ..writeByte(6)
      ..write(obj.customVideoLink);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomExercisePreferenceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserCustomExerciseAdapter extends TypeAdapter<UserCustomExercise> {
  @override
  final int typeId = 2;

  @override
  UserCustomExercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserCustomExercise(
      name: fields[0] as String,
      category: fields[1] as ExerciseCategory,
      targetMuscles: (fields[2] as List).cast<String>(),
      reps: fields[3] as String,
      notes: fields[4] as String,
      beginnerWeight: fields[5] as double?,
      videoLink: fields[6] as String,
      alwaysInclude: fields[7] as bool,
      neverInclude: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, UserCustomExercise obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.category)
      ..writeByte(2)
      ..write(obj.targetMuscles)
      ..writeByte(3)
      ..write(obj.reps)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.beginnerWeight)
      ..writeByte(6)
      ..write(obj.videoLink)
      ..writeByte(7)
      ..write(obj.alwaysInclude)
      ..writeByte(8)
      ..write(obj.neverInclude);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserCustomExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutGenerationPreferencesAdapter
    extends TypeAdapter<WorkoutGenerationPreferences> {
  @override
  final int typeId = 3;

  @override
  WorkoutGenerationPreferences read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutGenerationPreferences(
      upperBodyChestCount: fields[0] as int,
      upperBodyBackCount: fields[1] as int,
      upperBodyShoulderCount: fields[2] as int,
      upperBodyArmCount: fields[3] as int,
      lowerBodyCount: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutGenerationPreferences obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.upperBodyChestCount)
      ..writeByte(1)
      ..write(obj.upperBodyBackCount)
      ..writeByte(2)
      ..write(obj.upperBodyShoulderCount)
      ..writeByte(3)
      ..write(obj.upperBodyArmCount)
      ..writeByte(4)
      ..write(obj.lowerBodyCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutGenerationPreferencesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExerciseCategoryAdapter extends TypeAdapter<ExerciseCategory> {
  @override
  final int typeId = 0;

  @override
  ExerciseCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ExerciseCategory.chest;
      case 1:
        return ExerciseCategory.back;
      case 2:
        return ExerciseCategory.shoulders;
      case 3:
        return ExerciseCategory.arms;
      case 4:
        return ExerciseCategory.legs;
      default:
        return ExerciseCategory.chest;
    }
  }

  @override
  void write(BinaryWriter writer, ExerciseCategory obj) {
    switch (obj) {
      case ExerciseCategory.chest:
        writer.writeByte(0);
        break;
      case ExerciseCategory.back:
        writer.writeByte(1);
        break;
      case ExerciseCategory.shoulders:
        writer.writeByte(2);
        break;
      case ExerciseCategory.arms:
        writer.writeByte(3);
        break;
      case ExerciseCategory.legs:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

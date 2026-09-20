// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routine_item.dart';

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const RoutineExerciseConfigSchema = Schema(
  name: r'RoutineExerciseConfig',
  id: 7481024691787037601,
  properties: {
    r'exerciseId': PropertySchema(
      id: 0,
      name: r'exerciseId',
      type: IsarType.long,
    ),
    r'exerciseName': PropertySchema(
      id: 1,
      name: r'exerciseName',
      type: IsarType.string,
    ),
    r'isCompound': PropertySchema(
      id: 2,
      name: r'isCompound',
      type: IsarType.bool,
    ),
    r'maxReps': PropertySchema(
      id: 3,
      name: r'maxReps',
      type: IsarType.long,
    ),
    r'minReps': PropertySchema(
      id: 4,
      name: r'minReps',
      type: IsarType.long,
    ),
    r'muscleGroup': PropertySchema(
      id: 5,
      name: r'muscleGroup',
      type: IsarType.string,
    ),
    r'restSeconds': PropertySchema(
      id: 6,
      name: r'restSeconds',
      type: IsarType.long,
    ),
    r'targetRpe': PropertySchema(
      id: 7,
      name: r'targetRpe',
      type: IsarType.double,
    ),
    r'targetSets': PropertySchema(
      id: 8,
      name: r'targetSets',
      type: IsarType.long,
    )
  },
  estimateSize: _routineExerciseConfigEstimateSize,
  serialize: _routineExerciseConfigSerialize,
  deserialize: _routineExerciseConfigDeserialize,
  deserializeProp: _routineExerciseConfigDeserializeProp,
);

int _routineExerciseConfigEstimateSize(
  RoutineExerciseConfig object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.exerciseName.length * 3;
  bytesCount += 3 + object.muscleGroup.length * 3;
  return bytesCount;
}

void _routineExerciseConfigSerialize(
  RoutineExerciseConfig object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.exerciseId);
  writer.writeString(offsets[1], object.exerciseName);
  writer.writeBool(offsets[2], object.isCompound);
  writer.writeLong(offsets[3], object.maxReps);
  writer.writeLong(offsets[4], object.minReps);
  writer.writeString(offsets[5], object.muscleGroup);
  writer.writeLong(offsets[6], object.restSeconds);
  writer.writeDouble(offsets[7], object.targetRpe);
  writer.writeLong(offsets[8], object.targetSets);
}

RoutineExerciseConfig _routineExerciseConfigDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = RoutineExerciseConfig();
  object.exerciseId = reader.readLong(offsets[0]);
  object.exerciseName = reader.readString(offsets[1]);
  object.isCompound = reader.readBool(offsets[2]);
  object.maxReps = reader.readLong(offsets[3]);
  object.minReps = reader.readLong(offsets[4]);
  object.muscleGroup = reader.readString(offsets[5]);
  object.restSeconds = reader.readLong(offsets[6]);
  object.targetRpe = reader.readDouble(offsets[7]);
  object.targetSets = reader.readLong(offsets[8]);
  return object;
}

P _routineExerciseConfigDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readDouble(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension RoutineExerciseConfigQueryFilter on QueryBuilder<
    RoutineExerciseConfig, RoutineExerciseConfig, QFilterCondition> {
  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> exerciseIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'exerciseId',
        value: value,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> exerciseIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'exerciseId',
        value: value,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> exerciseIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'exerciseId',
        value: value,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> exerciseIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'exerciseId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> exerciseNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'exerciseName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> exerciseNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'exerciseName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> exerciseNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'exerciseName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> exerciseNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'exerciseName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> exerciseNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'exerciseName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> exerciseNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'exerciseName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
          QAfterFilterCondition>
      exerciseNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'exerciseName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
          QAfterFilterCondition>
      exerciseNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'exerciseName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> exerciseNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'exerciseName',
        value: '',
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> exerciseNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'exerciseName',
        value: '',
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> isCompoundEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isCompound',
        value: value,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> maxRepsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'maxReps',
        value: value,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> maxRepsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'maxReps',
        value: value,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> maxRepsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'maxReps',
        value: value,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> maxRepsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'maxReps',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> minRepsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'minReps',
        value: value,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> minRepsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'minReps',
        value: value,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> minRepsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'minReps',
        value: value,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> minRepsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'minReps',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> muscleGroupEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'muscleGroup',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> muscleGroupGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'muscleGroup',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> muscleGroupLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'muscleGroup',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> muscleGroupBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'muscleGroup',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> muscleGroupStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'muscleGroup',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> muscleGroupEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'muscleGroup',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
          QAfterFilterCondition>
      muscleGroupContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'muscleGroup',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
          QAfterFilterCondition>
      muscleGroupMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'muscleGroup',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> muscleGroupIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'muscleGroup',
        value: '',
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> muscleGroupIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'muscleGroup',
        value: '',
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> restSecondsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'restSeconds',
        value: value,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> restSecondsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'restSeconds',
        value: value,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> restSecondsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'restSeconds',
        value: value,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> restSecondsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'restSeconds',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> targetRpeEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetRpe',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> targetRpeGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'targetRpe',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> targetRpeLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'targetRpe',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> targetRpeBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'targetRpe',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> targetSetsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetSets',
        value: value,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> targetSetsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'targetSets',
        value: value,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> targetSetsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'targetSets',
        value: value,
      ));
    });
  }

  QueryBuilder<RoutineExerciseConfig, RoutineExerciseConfig,
      QAfterFilterCondition> targetSetsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'targetSets',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension RoutineExerciseConfigQueryObject on QueryBuilder<
    RoutineExerciseConfig, RoutineExerciseConfig, QFilterCondition> {}

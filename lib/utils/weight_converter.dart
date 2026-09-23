import 'package:flutter/foundation.dart';

enum WeightUnit { kg, lbs }

class GlobalSettings {
  // Inizializzato a 'kg' di default
  static final ValueNotifier<String> weightUnitNotifier = ValueNotifier<String>(
    'kg',
  );
}

class WeightConverter {
  static const double _lbsPerKg = 2.20462262;

  /// Da kg (memorizzati su DB) all'unità da mostrare nell'interfaccia
  static double toDisplay(double weightInKg, WeightUnit unit) {
    if (unit == WeightUnit.lbs) {
      return weightInKg * _lbsPerKg;
    }
    return weightInKg;
  }

  /// Dal valore digitato nell'interfaccia al valore normalizzato in kg per Isar
  static double toDatabaseKg(double displayWeight, WeightUnit unit) {
    if (unit == WeightUnit.lbs) {
      return displayWeight / _lbsPerKg;
    }
    return displayWeight;
  }

  /// Stringa formattata rapida
  static String format(double weightInKg, WeightUnit unit, {int decimals = 1}) {
    final val = toDisplay(weightInKg, unit);
    final label = unit == WeightUnit.lbs ? 'lbs' : 'kg';
    return '${val.toStringAsFixed(decimals)} $label';
  }
}

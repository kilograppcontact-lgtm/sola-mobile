import 'dart:io';
import 'dart:math' as math; // Добавляем math для функции max
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();

  /// Типы данных для чтения и записи
  final _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  // Разрешения
  final _permissions = [
    HealthDataAccess.READ_WRITE, // Шаги
    HealthDataAccess.READ_WRITE, // Калории
  ];

  /// Настройка
  Future<void> configure() async {
    await _health.configure();
  }

  /// Запрос разрешений
  Future<bool> requestAuthorization() async {
    try {
      await configure();

      if (Platform.isAndroid) {
        final activityStatus = await Permission.activityRecognition.request();
        if (!activityStatus.isGranted) {
          print("Activity recognition permission denied");
        }
      }

      final status = await _health.getHealthConnectSdkStatus();
      if (status == HealthConnectSdkStatus.sdkUnavailable) {
        return false;
      }
      if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        await _health.installHealthConnect();
        return false;
      }

      return await _health.requestAuthorization(
        _types,
        permissions: _permissions,
      );
    } catch (e) {
      print("Authorization Exception: $e");
      return false;
    }
  }

  /// Проверка прав
  Future<bool> hasPermissions() async {
    try {
      final has = await _health.hasPermissions(_types, permissions: _permissions);
      return has == true;
    } catch (e) {
      return false;
    }
  }

  /// Получение данных за СЕГОДНЯ
  Future<Map<String, int>> fetchTodayData() async {
    try {
      await configure();

      bool? hasPermissions = await _health.hasPermissions(
        _types,
        permissions: _permissions,
      );

      if (hasPermissions != true) {
        bool authorized = await requestAuthorization();
        if (!authorized) {
          return {'steps': 0, 'kcal': 0};
        }
      }

      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      // 1. Шаги
      int? steps = await _health.getTotalStepsInInterval(midnight, now);
      int safeSteps = steps ?? 0;

      // 2. Калории из Health Connect
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: midnight,
        endTime: now,
      );

      double fetchedKcal = 0;
      healthData = _health.removeDuplicates(healthData);
      for (var point in healthData) {
        final val = point.value;
        if (val is NumericHealthValue) {
          fetchedKcal += val.numericValue;
        }
      }

      // --- УЛУЧШЕННАЯ ЛОГИКА ---
      // Рассчитываем калории по шагам (примерно 0.045 ккал на шаг)
      double calculatedKcal = safeSteps * 0.045;

      // Берем максимум. Это решит проблему 0 ккал из Samsung Health
      // и не испортит данные, если Health Connect вернет больше (например, от тренировки).
      double finalKcal = fetchedKcal;

      // Если HC вернул 0 или подозрительно мало (меньше половины от расчетного),
      // используем расчет по шагам.
      if (fetchedKcal < (calculatedKcal * 0.5)) {
        print("HealthService: HC returned low kcal ($fetchedKcal). Using calculated: $calculatedKcal");
        finalKcal = calculatedKcal;
      }

      return {
        'steps': safeSteps,
        'kcal': finalKcal.toInt(),
      };
    } catch (e) {
      print("Error fetching data: $e");
      return {'steps': 0, 'kcal': 0};
    }
  }
}
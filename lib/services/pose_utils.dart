import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseUtils {
  /// Вычисляет угол между тремя точками
  static double calculateAngle(PoseLandmark first, PoseLandmark mid, PoseLandmark last) {
    double radians = math.atan2(last.y - mid.y, last.x - mid.x) -
        math.atan2(first.y - mid.y, first.x - mid.x);
    double degrees = radians * 180.0 / math.pi;
    degrees = degrees.abs();
    if (degrees > 180.0) {
      degrees = 360.0 - degrees;
    }
    return degrees;
  }

  /// СТРОГАЯ проверка приседания
  static ({String feedback, bool isRep, bool isGoodPose}) checkSquat(List<PoseLandmark> landmarks) {
    // 1. Ищем точки левой ноги
    final hip = landmarks.firstWhere((l) => l.type == PoseLandmarkType.leftHip);
    final knee = landmarks.firstWhere((l) => l.type == PoseLandmarkType.leftKnee);
    final ankle = landmarks.firstWhere((l) => l.type == PoseLandmarkType.leftAnkle);

    // 2. ПРОВЕРКА ВИДИМОСТИ (Строгость)
    // Если AI уверен меньше чем на 65%, что видит колено или бедро - игнорируем.
    // Это уберет ложные срабатывания в темноте или при смазывании.
    if (hip.likelihood < 0.65 || knee.likelihood < 0.65 || ankle.likelihood < 0.65) {
      return (feedback: "Вас плохо видно", isRep: false, isGoodPose: false);
    }

    double angle = calculateAngle(hip, knee, ankle);

    // 3. УЖЕСТОЧЕННЫЕ УГЛЫ
    // > 165: Почти полная прямая нога (было 160)
    if (angle > 165) {
      return (feedback: "Встаньте прямо", isRep: false, isGoodPose: true);
    }
    // < 85: Хороший глубокий присед (было 95)
    else if (angle < 85) {
      return (feedback: "Вверх!", isRep: true, isGoodPose: true);
    }
    // Промежуточные состояния
    else if (angle < 130) {
      return (feedback: "Ниже...", isRep: false, isGoodPose: true);
    }

    return (feedback: "", isRep: false, isGoodPose: true);
  }
}
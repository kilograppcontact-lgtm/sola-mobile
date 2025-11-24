import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

// -------------------------
// НОВАЯ ЦВЕТОВАЯ ПАЛИТРА 🎨
// -------------------------
class AppColors {
  // --- ОСНОВНЫЕ ЦВЕТА ---
  static const primary   = Color(0xFF6366F1); // Яркий Индиго
  static const secondary = Color(0xFFEC4899); // Яркий Розовый
  static const accent    = Color(0xFF0D9488); // Глубокий Бирюзовый

  // --- ФОН ---
  static const pageBackground = Color(0xFFF8FAFC); // Очень светлый серо-синий (Neutral 50)
  static const cardBackground = Color(0xFFFFFFFF); // Белый

  static const white = Color(0xFFFFFFFF); // Белый (Основной)

  // --- НЕЙТРАЛЬНЫЕ (Без изменений) ---
  static const neutral50  = Color(0xFFf8fafc);
  static const neutral100 = Color(0xFFf1f5f9);
  static const neutral200 = Color(0xFFe2e8f0);
  static const neutral300 = Color(0xFFcbd5e1);
  static const neutral400 = Color(0xFF94a3b8);
  static const neutral500 = Color(0xFF64748b);
  static const neutral600 = Color(0xFF475569);
  static const neutral700 = Color(0xFF334155);
  static const neutral800 = Color(0xFF1e293b);
  static const neutral900 = Color(0xFF0f172a);

  // --- СЕМАНТИЧЕСКИЕ (Без изменений) ---
  static const green = Color(0xFF16A34A);
  static const red   = Color(0xFFDC2626);

  // --- НОВЫЕ ГРАДИЕНТЫ ---
  // Главный градиент (для FAB, кнопок, хедера)
  static const gradientPrimary = [Color(0xFF818CF8), Color(0xFF6366F1)]; // Светлый Индиго -> Индиго

  // Градиенты для карточек приемов пищи
  static const gradientBreakfast = [Color(0xFFF472B6), Color(0xFFEC4899)]; // Светлый Розовый -> Розовый
  static const gradientLunch     = [Color(0xFF86EFAC), Color(0xFF16A34A)]; // Зеленый (как и был)
  static const gradientDinner    = [Color(0xFF818CF8), Color(0xFF6366F1)]; // Индиго (как главный)
  static const gradientSnack     = [Color(0xFF5EEAD4), Color(0xFF0D9488)]; // Светлый Бирюзовый -> Бирюзовый
}

/* ------------------------- INPUT ------------------------- */
InputDecoration kiloInput(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: AppColors.neutral300),
  filled: true,
  fillColor: AppColors.neutral50,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.neutral200)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.neutral200)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
);


class KiloCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final Color? borderColor;
  const KiloCard({super.key, required this.child, this.padding, this.margin, this.color, this.borderColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? AppColors.neutral200, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Базовый виджет для всех скелетон-загрузчиков.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.height,
    this.width,
    this.radius = 12, // По умолчанию как у kiloInput
  });

  final double? height, width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.neutral100, // <-- Используем ваши цвета
      highlightColor: AppColors.neutral50, // <-- Используем ваши цвета
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
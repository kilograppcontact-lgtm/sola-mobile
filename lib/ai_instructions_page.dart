import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'index.dart'; // Для KiloCard
import 'sola_ai.dart'; // Для перехода к чату

class AiInstructionsPage extends StatelessWidget {
  const AiInstructionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('Возможности Sola Pro'),
        centerTitle: true,
        backgroundColor: AppColors.pageBackground,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 1. Заголовок с градиентом
            Center(
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: AppColors.gradientPrimary,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: const Text(
                  'Ваш ИИ-Ассистент\nВсегда под рукой',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sola AI интегрирован прямо в приложение, чтобы сделать ваш путь к цели максимально простым.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.neutral600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // 2. Секция: Сканер еды
            _buildFeatureCard(
              context,
              icon: Icons.center_focus_strong_rounded,
              color: AppColors.primary,
              title: 'Умный сканер еды',
              description:
              'Больше не нужно искать продукты вручную. Просто наведите камеру на блюдо, и AI мгновенно распознает его, посчитает калории и БЖУ.',
              badge: 'Самый быстрый способ',
            ),
            const SizedBox(height: 16),

            // 3. Секция: Чат с тренером
            _buildFeatureCard(
              context,
              icon: Icons.auto_awesome_rounded,
              color: AppColors.secondary, // Розовый
              title: 'Персональный коуч',
              description:
              'Задавайте любые вопросы: "Что съесть на ужин?", "Как заменить этот продукт?", "Оцени мой прогресс". Sola AI знает ваш профиль и дает персонализированные советы.',
            ),
            const SizedBox(height: 16),

            // 4. Секция: Визуализация
            _buildFeatureCard(
              context,
              icon: Icons.analytics_rounded,
              color: AppColors.green,
              title: 'Визуализация тела',
              description:
              'Увидьте результат еще до начала. AI создает фотореалистичную модель вашего тела на основе целей, чтобы мотивировать вас.',
            ),

            const SizedBox(height: 40),

            // Кнопка действия
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Переходим к чату Sola AI
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const SolaAiPage(hasSubscription: true)),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Открыть чат с Sola AI'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
      BuildContext context, {
        required IconData icon,
        required Color color,
        required String title,
        required String description,
        String? badge,
      }) {
    return KiloCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Иконка в круге
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              // Бейдж (если есть)
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.neutral600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
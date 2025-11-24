import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'auth_api.dart';
import 'dart:async';

class PurchasePage extends StatefulWidget {
  const PurchasePage({super.key});

  @override
  State<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage> {
  final _api = AuthApi();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, введите номер телефона'), backgroundColor: AppColors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Используем API-метод, который мы добавим в auth_api.dart
      final response = await _api.createApplication(_phoneController.text);

      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _isSuccess = true;
          _isLoading = false;
        });
        // Показываем экран успеха на 2 секунды и закрываем
        Timer(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context, true); // true = заявка отправлена
          }
        });
      } else {
        throw Exception(response['message']?.toString() ?? 'Неизвестная ошибка');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sola Pro'),
        elevation: 0,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isSuccess
            ? _buildSuccessView() // Экран "Спасибо!"
            : _buildFormView(),      // Экран оформления
      ),
    );
  }

  /// ЭКРАН 1: Форма оформления
  Widget _buildFormView() {
    return ListView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.all(16.0),
      children: [
        // 1. "Герой"
        KiloCard(
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.gradientPrimary,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 44),
                SizedBox(height: 16),
                Text(
                  'Получите Sola Pro',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                SizedBox(height: 8),
                Text(
                  'Разблокируйте полный потенциал приложения с платной подпиской.',
                  style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 2. "Что внутри"
        KiloCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Что входит в подписку', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              SizedBox(height: 16),
              _FeatureRow(
                icon: Icons.auto_awesome_rounded,
                title: 'Персональный Sola AI',
                subtitle: 'AI-тренер и диетолог в вашем кармане.',
                color: AppColors.primary,
              ),
              Divider(height: 32),
              _FeatureRow(
                icon: Icons.analytics_rounded,
                title: 'AI-визуализация тела',
                subtitle: 'Увидьте свой будущий прогресс.',
                color: AppColors.secondary,
              ),
              Divider(height: 32),
              _FeatureRow(
                icon: Icons.restaurant_menu_rounded,
                title: 'Генерация диет',
                subtitle: 'Персональный план питания на каждый день.',
                color: AppColors.green,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 3. Форма заявки
        KiloCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Оставить заявку', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              const Text(
                'Введите ваш номер телефона, и мы свяжемся с вами для оформления подписки.',
                style: TextStyle(color: AppColors.neutral600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: kiloInput('Ваш номер телефона'),
                keyboardType: TextInputType.phone,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitApplication,
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded),
                  label: Text(_isLoading ? 'Отправка...' : 'Отправить заявку'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ЭКРАН 2: Успех
  Widget _buildSuccessView() {
    return Padding(
      key: const ValueKey('success'),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Icon(Icons.check_circle_outline_rounded, color: AppColors.green, size: 80),
          SizedBox(height: 24),
          Text(
            'Заявка принята!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.neutral900),
          ),
          SizedBox(height: 12),
          Text(
            'Мы скоро с вами свяжемся.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.neutral600, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// Вспомогательный виджет для строки "фичи"
class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _FeatureRow({required this.icon, required this.title, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: AppColors.neutral600)),
            ],
          ),
        ),
      ],
    );
  }
}
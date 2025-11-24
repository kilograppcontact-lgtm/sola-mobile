import 'package:flutter/material.dart';
import 'auth_api.dart';
import 'app_theme.dart'; // Убедитесь, что пути верные
import 'main.dart'; // Для KiloCard, Skeleton

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  final _api = AuthApi();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getAchievements();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои достижения')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeleton();
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) return const Center(child: Text('Нет доступных достижений'));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildAchievementRow(item);
            },
          );
        },
      ),
    );
  }

  Widget _buildAchievementRow(Map<String, dynamic> item) {
    final bool unlocked = item['is_unlocked'] == true;

    // Маппинг иконок с бэкенда на Flutter Icons
    IconData iconData = Icons.star;
    if (item['icon'] == 'restaurant') iconData = Icons.restaurant_menu_rounded;
    if (item['icon'] == 'fitness_center') iconData = Icons.fitness_center_rounded;
    if (item['icon'] == 'fire') iconData = Icons.local_fire_department_rounded;
    if (item['icon'] == 'bolt') iconData = Icons.flash_on_rounded;
    if (item['icon'] == 'whatshot') iconData = Icons.whatshot_rounded;

    // Цвета
    Color baseColor = AppColors.neutral400;
    if (unlocked) {
      if (item['color'] == 'green') baseColor = AppColors.green;
      if (item['color'] == 'blue') baseColor = AppColors.primary;
      if (item['color'] == 'orange') baseColor = const Color(0xFFFF9800);
      if (item['color'] == 'red') baseColor = AppColors.red;
      if (item['color'] == 'purple') baseColor = Colors.purpleAccent;
    }

    return KiloCard(
      color: unlocked ? baseColor.withOpacity(0.05) : AppColors.neutral50,
      borderColor: unlocked ? baseColor.withOpacity(0.3) : AppColors.neutral200,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Иконка
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: unlocked ? baseColor.withOpacity(0.1) : AppColors.neutral200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              unlocked ? iconData : Icons.lock_rounded,
              color: unlocked ? baseColor : AppColors.neutral400,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          // Текст
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: unlocked ? AppColors.neutral900 : AppColors.neutral500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['description'] ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: unlocked ? AppColors.neutral700 : AppColors.neutral400,
                  ),
                ),
              ],
            ),
          ),
          if (unlocked)
            const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 20),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const Skeleton(height: 80, width: double.infinity),
    );
  }
}

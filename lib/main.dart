import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'dart:typed_data';

import 'package:intl/date_symbol_data_local.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
// --- НОВЫЕ ПАКЕТЫ ---
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
// --------------------
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'trainings_calendar_page.dart';
import 'package:showcaseview/showcaseview.dart';
import 'auth_api.dart';
import 'login.dart';
import 'onboarding_flow.dart';
import 'confirm_analysis_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'achievements_page.dart';
import 'ai_instructions_page.dart';

import 'app_theme.dart';
import 'sola_ai.dart';
import 'scan_sheet.dart';
import 'purchase_page.dart';
import 'services/health_service.dart';

// --- ДОБАВЛЕННЫЕ ИМПОРТЫ ДЛЯ FIREBASE ---
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// перед тем как показать LoginPage или KiloShell.
class AuthCheckPage extends StatefulWidget {
  const AuthCheckPage({super.key});

  @override
  State<AuthCheckPage> createState() => _AuthCheckPageState();
}


class _AuthCheckPageState extends State<AuthCheckPage> {
  final _api = AuthApi();

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  /// Запрашивает разрешение и отправляет FCM-токен на бэкенд
  Future<void> _registerFcmToken() async {
    try {
      final fcm = FirebaseMessaging.instance;

      // Запрос разрешений (важно для iOS)
      await fcm.requestPermission();

      final token = await fcm.getToken();

      if (token != null) {
        print('FCM Token: $token');
        // Отправляем токен на наш бэкенд
        await _api.registerDeviceToken(token);
      }

      // Слушаем обновления токена (если он изменится)
      fcm.onTokenRefresh.listen((newToken) {
        if (newToken != null) {
          _api.registerDeviceToken(newToken);
        }
      });

    } catch (e) {
      print('Failed to register FCM token: $e');
    }
  }
  // ---

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final user = await _api.me();

      if (!mounted) return;

      if (user != null) {
        // Получаем ОБА флага онбординга
        final bool oldOnboardingComplete = user['onboarding_complete'] as bool? ?? false;
        final bool newOnboardingComplete = user['onboarding_v2_complete'] as bool? ?? false;

        await _registerFcmToken(); // Регистрируем токен устройства
// Исправленное условие: отправляем на онбординг только если
        // НИ старый, НИ новый онбординг не пройдены.
        if (!newOnboardingComplete && !oldOnboardingComplete) {

          // --- НОВАЯ ЛОГИКА ---
          // Пользователь залогинен, но не прошел никакой онбординг.
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OnboardingFlowPage()),
          );
        } else {
          // --- ЛОГИКА ДЛЯ ДЕЙСТВУЮЩИХ ИЛИ ПРОШЕДШИХ V2 ---
          // Пользователь старый (old=true) ИЛИ прошел новый (new=true).
          // Пускаем в приложение.
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              // startOnboarding: !oldOnboardingComplete покажет старый тур
              // только если old=false (но мы уже проверили, что один из них true).
              // Для новых V2 юзеров old тоже ставится в true на бэкенде, так что тур не покажется.
              builder: (_) => KiloShell(startOnboarding: !oldOnboardingComplete),
            ),
          );
        }

      } else {
        // Сессия недействительна или отсутствует (me() вернул null).
        // Название LoginPage будет изменено на SimpleLoginPage
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()), // <-- ИЗМЕНЕНО
        );
      }
    } catch (e) {
      // Любая ошибка (сеть, 401 и т.д.) - отправляем на логин.
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()), // <-- ИЗМЕНЕНО
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }




void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);


  try {
    await Firebase.initializeApp(
    );
    print("Firebase initialized");
  } catch (e) {
    print('Failed to initialize Firebase: $e');
  }


  runApp(const MyApp());
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary, // Новый основной цвет
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Sola',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: scheme.copyWith(
            primary: AppColors.primary,
            secondary: AppColors.secondary,
            surface: AppColors.cardBackground,
            background: AppColors.pageBackground,
          ),
          scaffoldBackgroundColor: AppColors.pageBackground,
          cardColor: AppColors.cardBackground,
          fontFamily: 'Inter',
          appBarTheme: const AppBarTheme(
            scrolledUnderElevation: 0.0,
            backgroundColor: AppColors.pageBackground,
            foregroundColor: AppColors.neutral900,
            elevation: 0,
            titleTextStyle: TextStyle(
              color: AppColors.neutral900,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          // Стиль для OutlinedButton
          outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.neutral700,
                side: const BorderSide(color: AppColors.neutral200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              )),
          // Стиль для ElevatedButton
          elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                // Используем градиент для кнопок!
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20)))),
      home: const AuthCheckPage(),
    );
  }
}

/* ------------------------- SHELL ------------------------- */

double bottomContentPadding(BuildContext context) {
  const barHeight = 72.0;
  const gap = 16.0;
  return barHeight + MediaQuery.of(context).padding.bottom + gap;
}

class KiloShell extends StatefulWidget {
  final bool startOnboarding;

  const KiloShell({
    super.key,
    this.startOnboarding = false,
  });

  @override
  State<KiloShell> createState() => _KiloShellState();
}

class _KiloShellState extends State<KiloShell> with TickerProviderStateMixin {
  int _index = 0; // Начинаем с "Главной"
  late final PageController _pageController;
  late final AnimationController _fabPulse;

  bool _hasSubscription = false; // <-- НОВАЯ ПЕРЕМЕННАЯ
  bool _isScannerOpening = false;
  bool _onboardingStarted = false;
  final GlobalKey _keyFab = GlobalKey();
  final GlobalKey _keyNavHome = GlobalKey();
  final GlobalKey _keyNavMeals = GlobalKey();
  final GlobalKey _keyNavAi = GlobalKey();

  /// Надежно парсит boolean из API
  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }

  final _api = AuthApi();
  // Future для ВСЕХ данных дашборда
  late Future<Map<String, dynamic>> _dashboardDataFuture;

  final GlobalKey<_MealsLogPageState> _mealsPageKey = GlobalKey<_MealsLogPageState>();

  final GlobalKey<TrainingsCalendarPageState> _calendarPageKey = GlobalKey<TrainingsCalendarPageState>();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
    _fabPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    // Загружаем все данные для дашборда при старте
    _dashboardDataFuture = _loadDashboardData();

    // --- СИНХРОНИЗАЦИЯ ЗДОРОВЬЯ ПРИ СТАРТЕ ---
    _syncHealthData();

    // --- ПРОВЕРКА НОВЫХ АЧИВОК ---
    // Ждем 2 секунды, чтобы интерфейс прогрузился, затем проверяем
    Future.delayed(const Duration(seconds: 2), _checkAchievementsLoop);
  }

  /// Показывает диалог, если нет подписки для сканера
  Future<void> _showScanPaywall() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.center_focus_strong_rounded, size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              const Text(
                'Умный сканер еды',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.neutral900),
              ),
              const SizedBox(height: 12),
              const Text(
                'Распознавание блюд по фото доступно только в подписке Sola Pro. Вы можете ввести калории вручную бесплатно.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.neutral600, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'buy'),
                  child: const Text('Оформить подписку'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, 'manual'),
                  child: const Text('Ввести вручную'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;

    if (result == 'buy') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchasePage()));
    } else if (result == 'manual') {
      // Открываем ручной ввод
      final bool? mealAdded = await _AddMealSheet.open(context);
      if (mealAdded == true) {
        _refreshAllPages();
        _animateTo(1);
      }
    }
  }

  // Метод синхронизации
  Future<void> _syncHealthData() async {
    try {
      final health = HealthService();
      final data = await health.fetchTodayData();
      final int steps = data['steps'] ?? 0;
      final int kcal = data['kcal'] ?? 0;

      // Получаем текущую дату в формате YYYY-MM-DD
      final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      if (steps > 0 || kcal > 0) {
        print("Syncing Health: $steps steps, $kcal kcal for date: $todayStr");

        // Передаем дату
        await _api.syncActivityLog(
            steps: steps,
            activeKcal: kcal,
            date: todayStr
        );

        if (mounted) {
          _refreshAllPages();
        }
      }
    } catch (e) {
      print("Health sync flow error: $e");
    }
  }

  Future<void> _checkAchievementsLoop() async {
    try {
      final newAchievements = await _api.checkNewAchievements();
      if (newAchievements.isNotEmpty && mounted) {
        for (var ach in newAchievements) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _AchievementUnlockedDialog(achievement: ach),
          );
        }
      }
    } catch (e) {
      print("Achievements check error: $e");
    }
  }
// Единая функция загрузки данных
  Future<Map<String, dynamic>> _loadDashboardData() async {
    try {
      final now = DateTime.now();
      final currentMonth = DateFormat('yyyy-MM').format(now);

      // Вычисляем следующий месяц (с учетом перехода через год)
      final nextMonthDate = (now.month == 12)
          ? DateTime(now.year + 1, 1)
          : DateTime(now.year, now.month + 1);
      final nextMonth = DateFormat('yyyy-MM').format(nextMonthDate);


      // Загружаем все 5 эндпоинтов параллельно
      final results = await Future.wait([
        _api.getProfileData(), // [0] Данные профиля
        _api.getTodayMeals(),  // [1] Данные о приемах пищи
        _api.getTrainings(currentMonth), // [2] Тренировки (Этот месяц)
        _api.getTrainings(nextMonth),    // [3] Тренировки (Следующий месяц)
        _api.getTodayActivity(),         // [4] Активность за сегодня (НОВОЕ)
      ]);

      // Объединяем 2 списка тренировок в один
      final List<Map<String, dynamic>> allTrainings = [
        ...((results[2] as List? ?? []).cast<Map<String, dynamic>>()),
        ...((results[3] as List? ?? []).cast<Map<String, dynamic>>()),
      ];

      // Объединяем все в одну Map
      final Map<String, dynamic> data = {
        'profile': results[0],
        'meals': results[1],
        'trainings': allTrainings,
        'activity': results[4],
      };

      if (mounted) {
        // Явно указываем, что results[0] это Map
        final profileData = results[0] as Map<String, dynamic>;
        final userMap = profileData['user'] as Map<String, dynamic>?;
        _hasSubscription = userMap?['has_subscription'] == true;

        // Проверяем флаг приветствия
        print("DEBUG: show_welcome_popup from server: ${userMap?['show_welcome_popup']}"); // <-- Лог в консоль

        final bool showWelcome = _parseBool(userMap?['show_welcome_popup']); // <-- Используем _parseBool
        if (showWelcome) {
          // Запускаем диалог после построения кадра
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showSubscriptionSuccessDialog();
          });
        }
      }
      // ---------------------------------

      return data;
    } catch (e) {
      _logout(); // Выход при любой ошибке
      return Future.error(e);
    }
  }

// Обновляем данные на всех страницах
  void _refreshAllPages() {
    setState(() {
      _dashboardDataFuture = _loadDashboardData();
    });
    _mealsPageKey.currentState?.loadData();
    _calendarPageKey.currentState?.initState();
  }

  // Метод показа диалога
  void _showSubscriptionSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Нельзя закрыть кликом мимо
      builder: (context) => _SubscriptionSuccessDialog(),
    ).then((_) {
      // Когда диалог закрыт, дергаем API, чтобы больше не показывать
      _api.dismissWelcomePopup();
    });
  }

  void _logout() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fabPulse.dispose();
    super.dispose();
  }

  Future<void> _animateTo(int i) async {
    if (i > 2) return;
    // ---

    if (_index == i) {
      // Обновление при повторном нажатии
      switch (i) {
        case 0:
          setState(() => _dashboardDataFuture = _loadDashboardData());
          break;
        case 1:
          _mealsPageKey.currentState?.loadData();
          break;
        case 2:
        // Обновляем календарь (вызываем initState для перезагрузки)
          _calendarPageKey.currentState?.initState();
          break;
      // case 3 удален
      }
      return;
    }
    setState(() => _index = i);
    await _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> openScanner() async {
    if (_isScannerOpening) return;

    if (!_hasSubscription) {
      await _showScanPaywall();
      return;
    }

    setState(() => _isScannerOpening = true);

    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Разрешение на камеру отклонено')),
          );
        }
        return;
      }
      if (!mounted) return;

      final hour = DateTime.now().hour;
      String defaultMealType = 'snack';

      if (hour >= 5 && hour < 11) {
        defaultMealType = 'breakfast';
      } else if (hour >= 11 && hour < 16) {
        defaultMealType = 'lunch';
      } else if (hour >= 16 && hour < 22) {
        defaultMealType = 'dinner';
      }

      final bool? didSave = await showModalBottomSheet<bool?>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.black,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (c) => ScanSheet(
          defaultMealType: defaultMealType,
        ),
      );

      if (didSave == true) {
        _refreshAllPages(); // Обновляем ВСЕ
        _animateTo(1); // Переходим на страницу "Питание"
      }
    } catch (e) {
      debugPrint('Ошибка открытия сканера: $e');
    } finally {
      if (mounted) {
        setState(() => _isScannerOpening = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {

    return ShowCaseWidget(
      onFinish: () {
        _api.completeOnboarding();
      },
      builder: (context) {

        if (widget.startOnboarding && !_onboardingStarted) {

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onboardingStarted = true;

            ShowCaseWidget.of(context).startShowCase([
              _keyNavHome,
              _keyNavMeals,
              _keyFab,
              _keyNavAi,
            ]);
          });
        }

        final nav = _BottomGlassBar(
          index: _index,
          onTap: _animateTo,
          hasSubscription: _hasSubscription,
          items: [
            _NavSpec(icon: Icons.grid_view_rounded, label: 'Главная', key: _keyNavHome),
            _NavSpec(icon: Icons.restaurant_menu_rounded, label: 'Питание', key: _keyNavMeals),
            _NavSpec(icon: Icons.calendar_month_rounded, label: 'Календарь'),
            _NavSpec(icon: Icons.auto_awesome_rounded, label: 'SolaAI', key: _keyNavAi),
          ],
        );

        return Scaffold(
          extendBody: true,
          resizeToAvoidBottomInset: true,
          body: FutureBuilder<Map<String, dynamic>>(
            future: _dashboardDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const DashboardPageSkeleton();
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Scaffold(body: Center(child: Text('Ошибка загрузки данных...')));
              }

              final data = snapshot.data!;

              // --- НОВАЯ ЛОГИКА: Поиск ближайшей тренировки ---
              final allWorkouts = (data['trainings'] as List? ?? [])
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList();

              final now = DateTime.now();

              final upcomingSignedUp = allWorkouts.where((workout) {
                try {
                  final isSignedUp = _parseBool(workout['is_signed_up_by_me']);
                  final startTimeStr = workout['start_time'];
                  final dateStr = workout['date'];
                  if (startTimeStr == null || dateStr == null) return false;

                  final timeParts = startTimeStr.split(':');
                  final dateParts = dateStr.split('-');

                  final workoutTime = DateTime(
                    int.parse(dateParts[0]), // year
                    int.parse(dateParts[1]), // month
                    int.parse(dateParts[2]), // day
                    int.parse(timeParts[0]), // hour
                    int.parse(timeParts[1]), // minute
                  );

                  return isSignedUp && workoutTime.isAfter(now);
                } catch(e) {
                  return false;
                }
              }).toList();

              upcomingSignedUp.sort((a, b) {
                // Безопасный парсинг
                try {
                  final aTime = DateTime.parse('${a['date']}T${a['start_time']}:00');
                  final bTime = DateTime.parse('${b['date']}T${b['start_time']}:00');
                  return aTime.compareTo(bTime);
                } catch(e) {
                  return 0;
                }
              });

              final Map<String, dynamic>? soonestWorkout = upcomingSignedUp.isNotEmpty
                  ? upcomingSignedUp.first
                  : null;

// Передаем собранные данные на страницы
              return PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  DashboardPage(
                    key: const PageStorageKey('dashboard'),
                    onRefresh: () async {
                      _refreshAllPages();
                    },
                    profileData: data['profile'] as Map<String, dynamic>? ?? {},
                    user: data['profile']?['user'] as Map<String, dynamic>? ?? {},
                    currentStreak: (data['profile']?['user']?['current_streak'] as int?) ?? 0,
                    last7DaysStatus: (data['profile']?['user']?['last_7_days_status'] as List?)
                        ?.map((e) => e == true)
                        .toList() ?? [],
                    fatLossProgress: data['profile']?['fat_loss_progress'] as Map<String, dynamic>?,
                    progressCheckpoints: (data['profile']?['progress_checkpoints'] as List? ?? []),
                    mealsData: data['meals'] as Map<String, dynamic>? ?? {},
                    activityData: data['activity'] as Map<String, dynamic>? ?? {},
                    upcomingWorkout: soonestWorkout,
                  ),
                  MealsLogPage(
                    key: _mealsPageKey,
                    onMealChange: _refreshAllPages,
                    diet: data['profile']?['diet'] as Map<String, dynamic>?,
                  ),
                  TrainingsCalendarPage(
                    key: _calendarPageKey,
                    onTrainingChanged: _refreshAllPages,
                    hasSubscription: (data['profile']?['user']?['has_subscription'] as bool? ?? false),
                  ),
                  // ---
                ],
              );
            },
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          floatingActionButton: ScaleTransition(
            scale: Tween(begin: 0.98, end: 1.0).animate(
              CurvedAnimation(parent: _fabPulse, curve: Curves.easeInOut),
            ),
            // 9. Оборачиваем FAB в Showcase
            child: Showcase(
              key: _keyFab,
              title: 'Сканирование еды',
              description: 'Нажмите сюда, чтобы распознать блюдо с помощью камеры',
              child: GestureDetector(
                onTap: openScanner,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 18, offset: const Offset(0, 10)),
                    ],
                    gradient: const LinearGradient(
                      colors: AppColors.gradientPrimary,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.center_focus_strong_rounded, color: Colors.white, size: 34),
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: nav,
        );
      }, // 10. Закрываем builder
    ); // 11. Закрываем ShowCaseWidget
  }
}

/* ------------------------- NAV BAR (glass) ------------------------- */
class _NavSpec {
  final IconData icon;
  final String label;
  final GlobalKey? key;
  const _NavSpec({required this.icon, required this.label, this.key});
}

class _BottomGlassBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<_NavSpec> items;
  final bool hasSubscription;

  const _BottomGlassBar({
    required this.index,
    required this.onTap,
    required this.items,
    required this.hasSubscription,
  });

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + pad / 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.cardBackground.withOpacity(0.85),
              border: Border.all(color: AppColors.neutral200),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: items[0].icon, label: items[0].label, active: index == 0, onTap: () => onTap(0), showcaseKey: items[0].key),
                _NavItem(icon: items[1].icon, label: items[1].label, active: index == 1, onTap: () => onTap(1), showcaseKey: items[1].key),
                const SizedBox(width: 56),
                _NavItem(icon: items[2].icon, label: items[2].label, active: index == 2, onTap: () => onTap(2), showcaseKey: items[2].key),
                _NavItem(
                  icon: items[3].icon,
                  label: items[3].label,
                  active: false,
                  showcaseKey: items[3].key,
                  onTap: () {
                    Navigator.push(
                      context,
                      // Используем переданную переменную hasSubscription
                      MaterialPageRoute(builder: (_) => SolaAiPage(hasSubscription: hasSubscription)),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final GlobalKey? showcaseKey;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.showcaseKey,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.neutral400;

    Widget content = InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color: color,
                fontSize: active ? 12 : 11,
                fontWeight: FontWeight.w700,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );

    if (showcaseKey != null) {
      String title = '';
      String description = '';
      if (label == 'Главная') {
        title = 'Главный экран';
        description = 'Здесь ваш основной дашборд с прогрессом и калориями';
      } else if (label == 'Питание') {
        title = 'Питание';
        description = 'Тут вы найдете логи приемов пищи и вашу диету';
      } else if (label == 'SolaAI') {
        title = 'Sola AI';
        description = 'Ваш персональный AI-тренер и ассистент';
      } else if (label == 'Календарь') {
        title = 'Календарь';
        description = 'Здесь вы можете записываться на групповые тренировки';
      }

      return Showcase(
        key: showcaseKey!,
        title: title,
        description: description,
        child: content,
      );
    }

    return content;
  }
}

/* --------------------------------------------------------- */
/* ------------------------- DASHBOARD PAGE (NEW) ---------------- */
/* --------------------------------------------------------- */

class DashboardPage extends StatelessWidget {
  final VoidCallback onRefresh;

  final Map<String, dynamic> profileData;
  final Map<String, dynamic> user;
  final Map<String, dynamic>? fatLossProgress;
  final List progressCheckpoints;
  final Map<String, dynamic> mealsData;
  final Map<String, dynamic> activityData;
  final Map<String, dynamic>? upcomingWorkout;
  final int currentStreak;
  final List<bool> last7DaysStatus;

  const DashboardPage({
    super.key,
    required this.onRefresh,
    required this.profileData,
    required this.user,
    required this.fatLossProgress,
    required this.progressCheckpoints,
    required this.mealsData,
    this.activityData = const {},
    this.upcomingWorkout,
    this.currentStreak = 0,
    this.last7DaysStatus = const [],
  });
  Widget _buildAvatarPlaceholder(Map<String, dynamic> user) {
    return Text(
      (user['name'] ?? "U").substring(0, 1).toUpperCase(),
      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
    );
  }

  void _showLoadingDialog(BuildContext context, String text) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(text),
            ],
          ),
        ),
      ),
    );
  }



  Future<void> _uploadAnalysis(BuildContext context, bool isFirstAnalysis) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    if (!context.mounted) return;
    _showLoadingDialog(context, 'Анализ файла...');

    try {
      final api = AuthApi();
      final File imageFile = File(image.path);

      final Map<String, dynamic> analysisData = await api.uploadBodyAnalysis(imageFile);

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Закрываем диалог загрузки

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ConfirmAnalysisPage(
            initialData: analysisData,
            isFirstAnalysis: isFirstAnalysis,
          ),
        ),
      ).then((_) {
        onRefresh();
      });

    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки: $e'), backgroundColor: AppColors.red),
      );
    }
  }

  /// Показывает шторку выбора (Сканер или Ручной ввод)
  Future<String?> _showAddMealChoiceSheet(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Заголовок
                Text(
                  'Добавить прием пищи',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.neutral900
                  ),
                ),
                const SizedBox(height: 20),

                // Опция 1: Сканировать фото
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, 'scan'),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Сканировать блюдо'),
                  style: ElevatedButton.styleFrom(
                    // Используем градиент!
                    backgroundColor: Colors.transparent, // Важно для градиента
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0, // Убираем тень, т.к. будет в контейнере
                  ).copyWith(
                    // Обертка для градиента
                    backgroundColor: MaterialStateProperty.all(Colors.transparent),
                    elevation: MaterialStateProperty.all(0),
                  ),
                ),
                const SizedBox(height: 12),

                // Опция 2: Ввести вручную
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, 'manual'),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Ввести вручную'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 8), // Отступ снизу
              ],
            ),
          ),
        );
      },
    );
  }

  /// НОВЫЙ ВСПОМОГАТЕЛЬНЫЙ ВИДЖЕТ ВНУТРИ `DashboardPage`
  Widget _buildSubscriptionCard(BuildContext context, bool hasSubscription) {
    if (hasSubscription) {
      // У пользователя ЕСТЬ подписка
      return KiloCard(
          color: AppColors.primary.withOpacity(0.05),
          borderColor: AppColors.primary.withOpacity(0.2),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.star_rounded, color: AppColors.primary, size: 22),
                  SizedBox(width: 8),
                  Text('Sola Pro активна', style: TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                  'Вам доступны все функции, включая AI-тренера и генерацию диет.',
                  style: TextStyle(color: AppColors.neutral600)
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  // Переход на страницу настроек для управления
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: const Text('Управлять подпиской'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                  backgroundColor: AppColors.cardBackground,
                ),
              )
            ],
          )
      );
    } else {
      // У пользователя НЕТ подписки
      return _InfoCallout(
        icon: Icons.workspace_premium_rounded,
        color: AppColors.secondary,
        title: 'Получите Sola Pro',
        subtitle: 'Разблокируйте AI-тренера, визуализацию тела и персональные диеты.',
        buttonText: 'Узнать больше',
        onPressed: () {
          // Переход на нашу новую страницу-заглушку
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const PurchasePage()),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = bottomContentPadding(context);
    final bool hasSubscription = (user['has_subscription'] as bool? ?? false);


    final int consumed = (mealsData['total_calories'] as num? ?? 0).toInt();
    final int bmr = (profileData['latest_analysis']?['metabolism'] as num? ?? 0).toInt();
    final int active = (activityData['active_kcal'] as num? ?? 0).toInt();

    final int caloricDiff = (bmr + active) - consumed;
    // --------------------------------------------------

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              // ... (код AppBar без изменений) ...
              title: const Text('Главная'),
              pinned: true,
              floating: false,
              backgroundColor: AppColors.pageBackground.withOpacity(0.85),
              surfaceTintColor: Colors.transparent,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(color: Colors.transparent),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.emoji_events_rounded, color: AppColors.neutral500),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AchievementsPage()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: AppColors.neutral500),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Экран уведомлений (TODO)')),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: AppColors.neutral500),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),

            SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Передаем активность и дефицит
                      _UserProfileHeaderCard(
                        profileData: profileData,
                        activityData: activityData,
                        caloricDiff: caloricDiff,
                      ),

                      const SizedBox(height: 24),

                      // Используем новый виджет с сердцами
                      _HeartsStreakWidget(
                        streak: currentStreak,
                        last7Days: last7DaysStatus,
                        caloricDiff: caloricDiff,
                      ),
                      const SizedBox(height: 24),

                      _buildSubscriptionCard(context, hasSubscription),
                      const SizedBox(height: 24),

                      const SectionTitle('Ваш Прогресс'),
                      if (fatLossProgress != null)
                        _ProgressGoalCard(
                          progressData: fatLossProgress!,
                          progressCheckpoints: progressCheckpoints, // Используем 'progressCheckpoints'
                        )
                      else
                        _InfoCallout(
                          icon: Icons.analytics_rounded,
                          color: AppColors.primary,
                          title: 'Начните свой путь',
                          subtitle: 'Загрузите свой первый анализ тела, чтобы мы рассчитали ваш прогресс.',
                          buttonText: 'Загрузить анализ',
                          onPressed: () => _uploadAnalysis(context, fatLossProgress == null),
                        ),

                      const SizedBox(height: 24),

                      _WorkoutBlock(
                        upcomingWorkout: upcomingWorkout,
                        onTap: () {
                          context.findAncestorStateOfType<_KiloShellState>()?._animateTo(2);
                        },
                      ),

                      const SizedBox(height: 16),

                      _MealsBlock(
                        mealsData: mealsData, // Используем 'mealsData'

                        onAddMeal: () async {
                          final String? choice = await _showAddMealChoiceSheet(context);

                          if (!context.mounted) return;

                          if (choice == 'manual') {
                            // 2. Выбор "Вручную": открываем _AddMealSheet
                            final bool? mealAdded = await _AddMealSheet.open(context);
                            if (mealAdded == true) onRefresh();

                          } else if (choice == 'scan') {
                            context.findAncestorStateOfType<_KiloShellState>()?.openScanner();
                          }
                        },

                        onTap: () {
                          context.findAncestorStateOfType<_KiloShellState>()?._animateTo(1);
                        },
                      ),

                    ],
                  ),
                ),
                SizedBox(height: bottomPad),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}


/* ------------------------- НОВЫЙ АНИМИРОВАННЫЙ ПРОГРЕСС-БАР (STATEFUL) ------------------------- */
class _ProgressGoalCard extends StatefulWidget {
  final Map<String, dynamic> progressData;
  final List progressCheckpoints;

  const _ProgressGoalCard({
    required this.progressData,
    required this.progressCheckpoints,
  });

  @override
  State<_ProgressGoalCard> createState() => _ProgressGoalCardState();
}

class _ProgressGoalCardState extends State<_ProgressGoalCard> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _progressAnimation = _createAnimation(0.0);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _ProgressGoalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progressData != oldWidget.progressData) {
      _progressAnimation = _createAnimation(_progressAnimation.value);
      _controller.forward(from: 0.0);
    }
  }

  /// Создает новую анимацию до целевого прогресса
  Animation<double> _createAnimation(double begin) {
    final double targetProgress = (widget.progressData['percentage'] as num? ?? 0.0) / 100.0;
    return Tween<double>(begin: begin, end: targetProgress.clamp(0.0, 1.0)).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  /// Ищет следующий невыполненный чек-поинт
  Map<String, dynamic>? _findNextCheckpoint(double userPercentage) {
    try {
      return widget.progressCheckpoints.firstWhere(
            (cp) => (cp['percentage'] as num? ?? 0.0) > userPercentage,
      );
    } catch (e) {
      return null; // Все чек-поинты пройдены
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- 1. Извлекаем данные ---
    final double currentFat = (widget.progressData['current_kg'] as num? ?? 0.0).toDouble();
    final double targetFat = (widget.progressData['goal_kg'] as num? ?? 0.0).toDouble();
    final double initialFat = (widget.progressData['initial_kg'] as num? ?? 0.0).toDouble();
    final double userPercentage = (widget.progressData['percentage'] as num? ?? 0.0).toDouble();

    // Сколько всего нужно сбросить
    final double totalToLose = (initialFat - targetFat).abs();
    // Сколько осталось сбросить
    final double remainingKg = (currentFat - targetFat).clamp(0.0, double.infinity);

    // Находим следующий чек-поинт
    final nextCheckpoint = _findNextCheckpoint(userPercentage);
    final bool goalAchieved = remainingKg == 0.0;

    return KiloCard(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 2. Заголовок карточки ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: const [
                Icon(Icons.flag_rounded, color: AppColors.primary, size: 22),
                SizedBox(width: 8),
                Text('Ваш путь к вашей цели', style: TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // --- 3. "Герой" (Главная цифра) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  remainingKg.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'кг',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  'Осталось',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- 4. Анимированный прогресс-бар ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Container(
                  height: 14, // Высота полосы
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.neutral200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: _progressAnimation.value,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.gradientPrimary,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // --- 5. Подписи (Старт/Цель) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Старт: ${initialFat.toStringAsFixed(1)} кг',
                  style: const TextStyle(fontSize: 12, color: AppColors.neutral600, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Цель: ${targetFat.toStringAsFixed(1)} кг',
                  style: const TextStyle(fontSize: 12, color: AppColors.neutral600, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // --- 6. Разделитель и Следующая цель ---
          const Divider(height: 32, color: AppColors.neutral200),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(
                  goalAchieved
                      ? Icons.check_circle_rounded
                      : Icons.stars_rounded,
                  color: goalAchieved
                      ? AppColors.green
                      : AppColors.primary.withOpacity(0.8),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    goalAchieved
                        ? 'Поздравляем, цель достигнута!'
                        : (nextCheckpoint != null
                        ? 'Следующий этап: Чек-поинт #${nextCheckpoint['number']}'
                        : 'Вы на финишной прямой!'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: goalAchieved ? AppColors.green : AppColors.neutral700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _SmallStatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SmallStatPill({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.neutral500)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: color,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------- PROFILE CARD (SUBSCRIPTION) ------------------------- */
class _ProfileCard extends StatelessWidget {
  final bool hasSubscription;
  const _ProfileCard({required this.hasSubscription});

  @override
  Widget build(BuildContext context) {
    return KiloCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.verified_rounded, color: hasSubscription ? AppColors.green : AppColors.neutral400),
          const SizedBox(width: 8),
          Text(hasSubscription ? 'Подписка активна' : 'Подписка неактивна', style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 4),
        Text(hasSubscription ? 'У вас есть доступ ко всем функциям' : 'Оформите подписку для полного доступа', style: const TextStyle(color: AppColors.neutral500)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _editProfile(context),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Редактировать профиль', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  static void _editProfile(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const Text('Редактирование профиля', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 12),
                const Text('Имя'),
                const SizedBox(height: 6),
                TextField(decoration: kiloInput('Ваше имя')),
                const SizedBox(height: 10),
                const Text('Email'),
                const SizedBox(height: 6),
                TextField(decoration: kiloInput('Ваш email')),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(c), child: const Text('Отмена')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: () => Navigator.pop(c), child: const Text('Сохранить')),
                ])
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class MealsLogPageSkeleton extends StatelessWidget {
  const MealsLogPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      ),
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Скелетон SectionTitle
            const Skeleton(width: 180, height: 24),
            const SizedBox(height: 12),

            // 2. Скелетон _MealsCarousel
            SizedBox(
              height: 230,
              child: PageView(
                controller: PageController(viewportFraction: .86),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: const Skeleton(width: double.infinity, height: 230),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: const Skeleton(width: double.infinity, height: 230),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Скелетон SectionTitle
            const Skeleton(width: 220, height: 24),
            const SizedBox(height: 12),
            const Skeleton(width: double.infinity, height: 160), // _NewDietCard
            const SizedBox(height: 24),

            // 4. Скелетон SectionTitle
            const Skeleton(width: 150, height: 24),
            const SizedBox(height: 12),
            const Skeleton(width: double.infinity, height: 200), // _WeeklyConsumptionChart
          ],
        ),
      ),
    );
  }
}
/* ------------------------- MEALS LOG PAGE (NEW) ------------------------- */
class MealsLogPage extends StatefulWidget {
  final VoidCallback onMealChange;
  final Map<String, dynamic>? diet;

  const MealsLogPage({
    super.key,
    required this.onMealChange,
    this.diet,
  });
  @override
  State<MealsLogPage> createState() => _MealsLogPageState();
}

class _MealsLogPageState extends State<MealsLogPage> {
  final _api = AuthApi();
  late Future<Map<String, dynamic>> _mealsDataFuture;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  void loadData() {
    _mealsDataFuture = _api.getTodayMeals();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = bottomContentPadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Питание'),
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _mealsDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MealsLogPageSkeleton();
            }
            if (snapshot.hasError) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Ошибка загрузки: ${snapshot.error}'),
              ));
            }

            final data = snapshot.data ?? {};
            final meals = (data['meals'] as List? ?? []).cast<Map<String, dynamic>>();

            return RefreshIndicator(
              onRefresh: () async => loadData(),
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
                children: [
                  Row(
                    children: [
                      const Expanded(child: SectionTitle('Приёмы пищи', padding: EdgeInsets.all(0))),
                      TextButton.icon(
                        onPressed: () async {
                          final bool? mealAdded = await _AddMealSheet.open(context);
                          if (mealAdded == true) widget.onMealChange();
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Добавить'),
                      )
                    ],
                  ),
                  _MealsCarousel(
                    meals: meals,
                    onMealChange: () => widget.onMealChange(),
                  ),

                  const SizedBox(height: 24),
                  const SectionTitle('Рацион на сегодня'),
                  if (widget.diet != null) // <-- Используем widget.diet
                    _NewDietCard(diet: widget.diet!)
                  else
                  // Заглушка, если рациона нет
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: _InfoCallout(
                        icon: Icons.restaurant_rounded,
                        color: AppColors.green,
                        title: 'Нет рациона на сегодня',
                        subtitle: 'Вы еще не сгенерировали рацион. Это можно сделать на главной странице.',
                        buttonText: 'Сгенерировать (TODO)',
                        onPressed: () {
                          // TODO: Добавить вызов генерации (он сейчас в DashboardPage)
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                  const SectionTitle('История'),
                  const _WeeklyConsumptionChart(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MealsCarousel extends StatelessWidget {
  final List<Map<String, dynamic>> meals;
  final VoidCallback onMealChange;

  const _MealsCarousel({required this.meals, required this.onMealChange});

  Map<String, dynamic>? _findMeal(String type) {
    try {
      return meals.firstWhere((m) => m['meal_type'] == type);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final breakfast = _findMeal('breakfast');
    final lunch = _findMeal('lunch');
    final dinner = _findMeal('dinner');
    final snack = _findMeal('snack');

    final cards = <Widget>[
      (breakfast != null)
          ? _MealCard(
        title: 'Завтрак', emoji: '☀️',
        calories: '${breakfast['calories']} ккал',
        // <-- ИЗМЕНЕНИЕ: Новый градиент -->
        gradient: AppColors.gradientBreakfast,
        onTap: () async {
          final bool? mealChanged = await _AddMealSheet.open(context, mealType: 'breakfast', initialData: breakfast);
          if (mealChanged == true) onMealChange();
        },
      )
          : _GhostMealCard(
        title: 'Завтрак',
        subtitle: 'Добавьте свой завтрак',
        onAdd: () async {
          final bool? mealAdded = await _AddMealSheet.open(context, mealType: 'breakfast');
          if (mealAdded == true) onMealChange();
        },
      ),

      (lunch != null)
          ? _MealCard(
        title: 'Обед', emoji: '🍱',
        calories: '${lunch['calories']} ккал',
        gradient: AppColors.gradientLunch,
        onTap: () async {
          final bool? mealChanged = await _AddMealSheet.open(context, mealType: 'lunch', initialData: lunch);
          if (mealChanged == true) onMealChange();
        },
      )
          : _GhostMealCard(
        title: 'Обед',
        subtitle: 'Вы ещё не добавили обед.\nДобавим?',
        onAdd: () async {
          final bool? mealAdded = await _AddMealSheet.open(context, mealType: 'lunch');
          if (mealAdded == true) onMealChange();
        },
      ),

      (dinner != null)
          ? _MealCard(
        title: 'Ужин', emoji: '🌙',
        calories: '${dinner['calories']} ккал',
        gradient: AppColors.gradientDinner,
        onTap: () async {
          final bool? mealChanged = await _AddMealSheet.open(context, mealType: 'dinner', initialData: dinner);
          if (mealChanged == true) onMealChange();
        },
      )
          : _GhostMealCard(
        title: 'Ужин',
        subtitle: 'Добавьте свой ужин',
        onAdd: () async {
          final bool? mealAdded = await _AddMealSheet.open(context, mealType: 'dinner');
          if (mealAdded == true) onMealChange();
        },
      ),

      (snack != null)
          ? _MealCard(
        title: 'Перекус', emoji: '🥜',
        calories: '${snack['calories']} ккал',
        gradient: AppColors.gradientSnack,
        onTap: () async {
          final bool? mealChanged = await _AddMealSheet.open(context, mealType: 'snack', initialData: snack);
          if (mealChanged == true) onMealChange();
        },
      )
          : _GhostMealCard(
        title: 'Перекус',
        subtitle: 'Добавьте перекус',
        onAdd: () async {
          final bool? mealAdded = await _AddMealSheet.open(context, mealType: 'snack');
          if (mealAdded == true) onMealChange();
        },
      ),
    ];

    return SizedBox(
      height: 230,
      child: PageView.builder(
        controller: PageController(viewportFraction: .86),
        itemCount: cards.length,
        padEnds: false,
        itemBuilder: (context, i) {
          return AnimatedBuilder(
            animation: (context.findAncestorWidgetOfExactType<PageView>()!.controller as PageController),
            builder: (context, child) {
              final controller = context.findAncestorWidgetOfExactType<PageView>()!.controller as PageController;
              double page = controller.page ?? i.toDouble();
              double delta = (i - page).abs();
              double scale = (1 - (delta * 0.06)).clamp(0.0, 1.0);
              double vMargin = 6 + (delta * 8);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: vMargin),
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              );
            },
            child: cards[i],
          );
        },
      ),
    );
  }
}
class _MealCard extends StatelessWidget {
  final String title;
  final String emoji;
  final String? calories;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _MealCard({
    required this.title,
    required this.emoji,
    required this.calories,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = calories != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: gradient),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxHeight < 168;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: false,
                          applyHeightToLastDescent: false,
                        ),
                      ),
                      if (compact)
                        IconButton(
                          onPressed: onTap,
                          icon: const Icon(Icons.edit_rounded, color: Colors.white),
                          tooltip: 'Изменить',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                          textHeightBehavior: const TextHeightBehavior(
                            applyHeightToFirstAscent: false,
                            applyHeightToLastDescent: false,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasData ? calories! : 'Добавить',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        if (!compact)
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: onTap,
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: hasData ? AppColors.neutral700 : AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                minimumSize: const Size.fromHeight(36),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                '✏️ ${hasData ? "Изменить" : "Добавить"}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
class _GhostMealCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onAdd;

  const _GhostMealCard({
    required this.title,
    required this.subtitle,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, c) {
            final compact = c.maxHeight < 160;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 2),
                const Text('🍽️', style: TextStyle(fontSize: 24)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.neutral900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.neutral600),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text('Добавить $title'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          backgroundColor: AppColors.cardBackground,
                          side: const BorderSide(color: AppColors.neutral200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          minimumSize: const Size.fromHeight(36),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/* ------------------------- SETTINGS ------------------------- */
bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.toLowerCase() == 'true' || value == '1';
  return false;
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _api = AuthApi();
  bool _logoutBusy = false;

  // Состояние загрузки
  bool _isLoading = true;
  bool _healthConnected = false;

  // Переменные настроек
  bool _telegramNotifyEnabled = false;
  bool _notifyTrainings = false;
  bool _notifyMeals = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    // 1. Проверяем Health Connect (быстро)
    try {
      final hasHealth = await HealthService().hasPermissions();
      if (mounted) setState(() => _healthConnected = hasHealth);
    } catch (_) {}

    // 2. Загружаем настройки (сеть)
    try {
      final settings = await _api.getTelegramSettings();
      if (mounted) {
        setState(() {
          _telegramNotifyEnabled = _parseBool(settings['telegram_notify_enabled']);
          _notifyTrainings = _parseBool(settings['notify_trainings']);
          _notifyMeals = _parseBool(settings['notify_meals']);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Можно показать снекбар, но лучше не блокировать UI
      }
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    setState(() {
      if (key == 'telegram_notify_enabled') _telegramNotifyEnabled = value;
      if (key == 'notify_trainings') _notifyTrainings = value;
      if (key == 'notify_meals') _notifyMeals = value;
    });

    try {
      await _api.setTelegramSettings({key: value});
    } catch (e) {
      setState(() {
        if (key == 'telegram_notify_enabled') _telegramNotifyEnabled = !value;
        if (key == 'notify_trainings') _notifyTrainings = !value;
        if (key == 'notify_meals') _notifyMeals = !value;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<void> _logout() async {
    setState(() => _logoutBusy = true);
    try {
      await _api.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
      );
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка выхода: ${e.message}'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _logoutBusy = false);
      }
    }
  }
  Future<void> _confirmResetProgress() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сбросить прогресс?'),
        content: const Text(
          'Это действие удалит ваши текущие цели и отвяжет ваш '
              'первоначальный анализ тела. Вы сможете начать отсчет заново, '
              'загрузив новый анализ.\n\nЭто действие необратимо.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red, // Красный цвет для опасного действия
              foregroundColor: Colors.white,
            ),
            child: const Text('Да, сбросить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return; // Пользователь нажал "Отмена"

    if (!mounted) return;
    // Показываем индикатор (используем ту же переменную блокировки, что и для выхода)
    setState(() => _logoutBusy = true);

    try {
      await _api.resetProgress();
      if (!mounted) return;

      // Показываем сообщение об успехе
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Прогресс успешно сброшен. Вы можете начать заново.'),
          backgroundColor: AppColors.green,
        ),
      );

      // Закрываем настройки, возвращаемся на главный экран
      Navigator.of(context).pop();

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сброса: $e'), backgroundColor: AppColors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _logoutBusy = false);
      }
    }
  }

  /// НОВЫЙ МЕТОД
  Future<void> _manageSubscription(String action) async {
    setState(() => _logoutBusy = true); // Используем существующий индикатор
    try {
      await _api.manageSubscription(action);

      final String message = action == 'freeze'
          ? 'Подписка заморожена. Дни сохранены.'
          : 'Подписка разморожена. Дни восстановлены.';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.green),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _logoutBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = bottomContentPadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
          children: [

            KiloCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Управление подпиской',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.neutral900,
                        fontSize: 16
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Вы можете временно приостановить (заморозить) действие подписки или возобновить ее (разморозить).',
                    style: TextStyle(color: AppColors.neutral700, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.pause_rounded, size: 18),
                          onPressed: _logoutBusy ? null : () => _manageSubscription('freeze'),
                          label: const Text('Заморозить'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.neutral700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          onPressed: _logoutBusy ? null : () => _manageSubscription('unfreeze'),
                          label: const Text('Разморозить'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.green,
                            side: BorderSide(color: AppColors.green.withOpacity(0.5)),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            KiloCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_isLoading) ...[
                    // Красивые скелетоны при загрузке
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Skeleton(height: 40, width: double.infinity)),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Skeleton(height: 40, width: double.infinity)),
                  ] else ...[
                    // Реальные переключатели
                    _SwitchRow(title: 'Получать уведомления', value: _telegramNotifyEnabled, onChanged: (v) => _updateSetting('telegram_notify_enabled', v)),
                    _SwitchRow(title: 'Напоминать о еде', value: _notifyMeals, onChanged: (v) => _updateSetting('notify_meals', v)),
                    _SwitchRow(title: 'Напоминать о тренировках', value: _notifyTrainings, onChanged: (v) => _updateSetting('notify_trainings', v)),
                  ],

                  const Divider(height: 24),

                  // --- HEALTH CONNECT (УМНАЯ КНОПКА) ---
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: (_healthConnected ? AppColors.green : Colors.redAccent).withOpacity(0.1),
                          shape: BoxShape.circle
                      ),
                      child: Icon(
                          Icons.favorite_rounded,
                          color: _healthConnected ? AppColors.green : Colors.redAccent,
                          size: 20
                      ),
                    ),
                    title: const Text('Синхронизация здоровья', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                        _healthConnected ? 'Подключено' : 'Google Fit / Health Connect',
                        style: const TextStyle(fontSize: 12, color: AppColors.neutral500)
                    ),
                    trailing: _healthConnected
                        ? TextButton(
                      onPressed: null, // Уже подключено
                      child: const Text('Активно', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.bold)),
                    )
                        : OutlinedButton(
                      onPressed: () async {
                        final success = await HealthService().requestAuthorization();
                        if (context.mounted && success) {
                          setState(() => _healthConnected = true);
                        }
                      },
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), minimumSize: const Size(0, 32)),
                      child: const Text('Подключить'),
                    ),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logoutBusy ? null : _logout,
                      icon: _logoutBusy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neutral500)) : const Icon(Icons.logout_rounded),
                      label: Text(_logoutBusy ? 'Выходим...' : 'Выйти из аккаунта'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.neutral700,
                          side: const BorderSide(color: AppColors.neutral200)
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            KiloCard(
              padding: const EdgeInsets.all(16),
              color: AppColors.red.withOpacity(0.05),
              borderColor: AppColors.red.withOpacity(0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Опасная зона',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.red,
                        fontSize: 16
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Это действие сбросит ваш прогресс и цели. '
                        'Используйте, если вы хотите начать отслеживание заново.',
                    style: TextStyle(color: AppColors.neutral700, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logoutBusy ? null : _confirmResetProgress,
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text('Сбросить мой прогресс'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.red,
                        side: BorderSide(color: AppColors.red.withOpacity(0.4)),
                        backgroundColor: AppColors.cardBackground,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            KiloCard(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text('О приложении', style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text('Версия 1.0.0 (Dashboard)', style: TextStyle(color: AppColors.neutral500)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}



class SectionTitle extends StatelessWidget {
  final String text;
  final EdgeInsets padding;
  const SectionTitle(this.text, { this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 10) });
  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.neutral900)),
  );
}

class _MacroPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  final Color border;
  const _MacroPill({required this.label, required this.value, required this.color, required this.bg, required this.border});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  final String title;
  const _ChartPlaceholder({required this.title});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.neutral600)),
      const SizedBox(height: 8),
      Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: const Center(child: Icon(Icons.show_chart, color: AppColors.neutral300, size: 44)),
      ),
    ]);
  }
}
class _UserProfileHeaderCard extends StatefulWidget {
  final Map<String, dynamic> profileData;
  final Map<String, dynamic> activityData;
  final int caloricDiff;

  const _UserProfileHeaderCard({
    super.key,
    required this.profileData,
    this.activityData = const {},
    this.caloricDiff = 0,
  });

  @override
  State<_UserProfileHeaderCard> createState() => _UserProfileHeaderCardState();
}

class _UserProfileHeaderCardState extends State<_UserProfileHeaderCard> {
  bool _isExpanded = false;
  final _api = AuthApi(); // Экземпляр API

  // Безопасное получение вложенных данных
  Map<String, dynamic> get _user => widget.profileData['user'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic>? get _analysis => widget.profileData['latest_analysis'] as Map<String, dynamic>?;

  Widget _buildAvatarPlaceholder(Map<String, dynamic> user, double fontSize) {
    return Text(
      (user['name'] ?? "U").substring(0, 1).toUpperCase(),
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: AppColors.primary),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.neutral500, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  // --- Диалог редактирования ---
  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _user['name']);
    final emailController = TextEditingController(text: _user['email']);
    File? tempAvatar; // Временный файл для предпросмотра в диалоге
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        // StatefulBuilder нужен, чтобы обновлять аватарку внутри диалога
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.neutral200, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Редактировать профиль", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 20),

                // Аватар в диалоге (с возможностью смены)
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setModalState(() {
                          tempAvatar = File(image.path);
                        });
                      }
                    },
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.neutral100,
                          // Показываем: либо новое фото, либо с сервера, либо иконку
                          backgroundImage: tempAvatar != null
                              ? FileImage(tempAvatar!)
                              : (_user['avatar_filename'] != null
                              ? NetworkImage('${AuthApi.baseUrl}/files/${_user['avatar_filename']}')
                              : null) as ImageProvider?,
                          child: (tempAvatar == null && _user['avatar_filename'] == null)
                              ? const Icon(Icons.person, size: 50, color: AppColors.neutral400)
                              : null,
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3)
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: nameController,
                  decoration: kiloInput('Ваше имя').copyWith(labelText: 'Имя'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: kiloInput('Email').copyWith(labelText: 'Email'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : () async {
                      setModalState(() => isSaving = true);
                      try {
                        await _api.updateProfile(
                          name: nameController.text,
                          email: emailController.text,
                          avatar: tempAvatar,
                        );

                        if (!mounted) return;
                        Navigator.pop(ctx); // Закрываем диалог

                        // Сообщение об успехе
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Профиль обновлен! Обновите страницу.'),
                              backgroundColor: AppColors.green
                          ),
                        );

                        // В идеале здесь нужно вызвать обновление данных DashboardPage
                      } catch (e) {
                        setModalState(() => isSaving = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.red),
                        );
                      }
                    },
                    child: isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Сохранить изменения"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- ВОТ ЭТОТ МЕТОД БЫЛ ПРОПУЩЕН ---
  Widget _buildExpandedMetrics(Map<String, dynamic> metrics) {
    // Ключи должны совпадать с теми, что приходят из 'latest_analysis'
    final weight = (metrics['weight_kg'] as num? ?? 0.0).toStringAsFixed(1);
    final fatKg = (metrics['fat_mass_kg'] as num? ?? 0.0).toStringAsFixed(1);
    final bmi = (metrics['bmi'] as num? ?? 0.0).toStringAsFixed(1);
    final metabolism = (metrics['metabolism'] as num? ?? 0.0).toInt();
    final visceral = (metrics['visceral_fat_level'] as num? ?? 0);
    final bodyAge = (metrics['body_age'] as num? ?? 0);
    final protein = (metrics['protein_percentage'] as num? ?? 0.0).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        children: [
          const Divider(height: 1, color: AppColors.neutral200),
          const SizedBox(height: 12),
          _DetailMetricRow(icon: Icons.monitor_weight_rounded, label: 'Вес (кг)', value: weight),
          _DetailMetricRow(icon: Icons.local_fire_department_rounded, label: 'Масса жира (кг)', value: fatKg),
          _DetailMetricRow(icon: Icons.egg_rounded, label: 'Протеин (%)', value: protein),
          _DetailMetricRow(icon: Icons.straighten_rounded, label: 'ИМТ', value: bmi),
          _DetailMetricRow(icon: Icons.report_problem_rounded, label: 'Висцеральный жир', value: 'Уровень $visceral'),
          _DetailMetricRow(icon: Icons.bolt_rounded, label: 'Метаболизм (ккал)', value: '$metabolism'),
          _DetailMetricRow(icon: Icons.calendar_today_rounded, label: 'Возраст тела (лет)', value: '$bodyAge'),
        ],
      ),
    );
  }
  // -----------------------------------

  @override
  Widget build(BuildContext context) {
    final String? avatarFilename = _user['avatar_filename'] as String?;
    final String userName = _user['name'] as String? ?? 'Пользователь';
    final String userEmail = _user['email'] as String? ?? '';
    final hasAnalysis = _analysis != null;

    final int steps = (widget.activityData['steps'] as num? ?? 0).toInt();
    final int activeKcal = (widget.activityData['active_kcal'] as num? ?? 0).toInt();
    final int diff = widget.caloricDiff;

    return KiloCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // --- ВЕРХНЯЯ ЧАСТЬ (Профиль) ---
          Stack(
            alignment: Alignment.center,
            children: [
              // Фоновый декоративный элемент
              Positioned(
                top: -50, right: -50,
                child: Container(
                  width: 150, height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // 1. АВАТАР
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: AppColors.gradientPrimary,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(3),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.neutral100,
                          child: avatarFilename != null
                              ? ClipOval(
                            child: Image.network(
                              '${AuthApi.baseUrl}/files/$avatarFilename',
                              fit: BoxFit.cover,
                              width: 100, height: 100,
                              errorBuilder: (context, error, stackTrace) => _buildAvatarPlaceholder(_user, 36),
                            ),
                          )
                              : _buildAvatarPlaceholder(_user, 36),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 2. ИМЯ И EMAIL
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.neutral900,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userEmail,
                      style: const TextStyle(fontSize: 14, color: AppColors.neutral500),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    // 3. КНОПКА РЕДАКТИРОВАНИЯ
                    SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        onPressed: _showEditProfileDialog,
                        icon: const Icon(Icons.edit_rounded, size: 14),
                        label: const Text("Редактировать", style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.neutral700,
                          side: const BorderSide(color: AppColors.neutral200),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 1, color: AppColors.neutral100),

          // --- СТАТИСТИКА (ACTIVITY) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActivityColumn(
                  icon: Icons.directions_walk_rounded,
                  color: Colors.blueAccent,
                  value: '$steps',
                  label: 'Шагов',
                ),
                Container(width: 1, height: 30, color: AppColors.neutral200),
                _buildActivityColumn(
                  icon: Icons.local_fire_department_rounded,
                  color: Colors.orange,
                  value: '$activeKcal',
                  label: 'Сожжено',
                ),
                Container(width: 1, height: 30, color: AppColors.neutral200),
                Column(
                  children: [
                    Icon(diff >= 0 ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                        size: 20,
                        color: diff >= 0 ? AppColors.green : Colors.redAccent
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${diff.abs()}',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: diff >= 0 ? AppColors.green : Colors.redAccent
                      ),
                    ),
                    Text(diff >= 0 ? 'Дефицит' : 'Профицит', style: const TextStyle(fontSize: 10, color: AppColors.neutral500)),
                  ],
                ),
              ],
            ),
          ),

          // --- РАСКРЫВАЮЩИЕСЯ МЕТРИКИ ---
          if (hasAnalysis) ...[
            const Divider(height: 1, color: AppColors.neutral100),

            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                color: AppColors.neutral50.withOpacity(0.5),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatPill(
                                'Жир',
                                '${(_analysis!['body_fat_percentage'] as num? ?? 0.0).toStringAsFixed(1)} %',
                                AppColors.secondary,
                              ),
                              _buildStatPill(
                                'Мышцы',
                                '${(_analysis!['muscle_mass_kg'] as num? ?? 0.0).toStringAsFixed(1)} кг',
                                AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: AppColors.neutral400,
                        ),
                      ],
                    ),

                    // Анимированный список
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _isExpanded
                          ? _buildExpandedMetrics(_analysis!)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Widget _buildActivityColumn({required IconData icon, required Color color, required String value, required String label}) {
  return Column(
    children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.neutral800)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.neutral500)),
    ],
  );
}

/// Вспомогательный виджет: Строка с иконкой для детального списка
class _DetailMetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailMetricRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.neutral700),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.neutral900),
          ),
        ],
      ),
    );
  }
}

class _WorkoutBlock extends StatelessWidget {
  final Map<String, dynamic>? upcomingWorkout; // <-- ПРИНИМАЕМ ДАННЫЕ
  final VoidCallback onTap;

  const _WorkoutBlock({ this.upcomingWorkout, required this.onTap });

  @override
  Widget build(BuildContext context) {
    final bool hasWorkout = upcomingWorkout != null;
    final String title = hasWorkout ? (upcomingWorkout!['title'] ?? 'Тренировка') : 'Тренировки';
    final String time = hasWorkout ? (upcomingWorkout!['start_time'] ?? '00:00') : '';
    final String trainer = hasWorkout ? (upcomingWorkout!['trainer']?['name'] ?? 'Тренер') : '';

    return KiloCard(
      color: AppColors.primary.withOpacity(0.05),
      borderColor: AppColors.primary.withOpacity(0.2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18), // Важно для InkWell
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              // Иконка
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              // Текст
              Expanded(
                child: hasWorkout
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.neutral800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$time, $trainer",
                      style: const TextStyle(fontSize: 14, color: AppColors.neutral600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                )
                    : Text(
                  title, // "Тренировки"
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.neutral800),
                ),
              ),
              const SizedBox(width: 8),
// Иконка "вперед"
              const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}


class _MealsBlock extends StatelessWidget {
  final Map<String, dynamic> mealsData;
  final VoidCallback onTap; // Для перехода на страницу "Питание"
  final VoidCallback onAddMeal; // Для открытия шторки добавления

  const _MealsBlock({
    required this.mealsData,
    required this.onTap,
    required this.onAddMeal,
  });

  // Логика определения текущего приема пищи
  ({String title, String type, IconData icon, Color color}) _getCurrentMealPrompt() {
    final hour = DateTime.now().hour;
    // 5:00 - 8:59
    if (hour >= 5 && hour < 9) {
      return (title: 'Загрузите завтрак', type: 'breakfast', icon: Icons.wb_sunny_rounded, color: AppColors.primary);
    }
    // 9:00 - 12:59
    if (hour >= 9 && hour < 13) {
      return (title: 'Загрузите обед', type: 'lunch', icon: Icons.restaurant_rounded, color: AppColors.green);
    }
    // 13:00 - 17:59
    if (hour >= 13 && hour < 18) {
      return (title: 'Загрузите ужин', type: 'dinner', icon: Icons.nights_stay_rounded, color: AppColors.secondary);
    }
    // Остальное время - перекус
    return (title: 'Загрузите перекус', type: 'snack', icon: Icons.fastfood_rounded, color: AppColors.neutral500);
  }

  @override
  Widget build(BuildContext context) {
    final prompt = _getCurrentMealPrompt();
    final mealsList = (mealsData['meals'] as List? ?? []);
    final bool isLogged = mealsList.any((m) => m['meal_type'] == prompt.type);

    Color color = isLogged ? AppColors.green : prompt.color;
    String title = isLogged ? "Отлично, ${prompt.type} учтен!" : prompt.title;
    IconData icon = isLogged ? Icons.check_circle_rounded : prompt.icon;

    // Спец. сообщение для "Перекуса", если он уже съеден
    if (prompt.type == 'snack' && isLogged) {
      title = "Перекус учтен!";
    }

    return KiloCard(
      color: color.withOpacity(0.05),
      borderColor: color.withOpacity(0.2),
      child: InkWell(
        // Нажатие на карточку:
        // - Если не съедено -> Открыть шторку добавления
        // - Если съедено -> Перейти на страницу "Питание"
        onTap: isLogged ? onTap : onAddMeal,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              // Иконка
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              // Текст
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.neutral800),
                ),
              ),
              const SizedBox(width: 8),
              // Иконка "вперед"
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCallout extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  const _InfoCallout({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return KiloCard(
        color: color.withOpacity(0.05),
        borderColor: color.withOpacity(0.2),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: AppColors.neutral600)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(buttonText),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withOpacity(0.3)),
                backgroundColor: AppColors.cardBackground,
              ),
            )
          ],
        )
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onClose;
  final VoidCallback onAdd;

  const _InlineNotice({
    super.key,
    required this.title,
    this.subtitle,
    required this.onClose,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 44, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.pageBackground, AppColors.cardBackground],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.neutral200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: Offset(0, 6))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.schedule_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: const TextStyle(color: AppColors.neutral600)),
                    ],
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Добавить'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        backgroundColor: AppColors.cardBackground,
                        side: const BorderSide(color: AppColors.neutral200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            onPressed: onClose,
            tooltip: 'Скрыть',
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.neutral400),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.cardBackground.withOpacity(0.5),
              padding: const EdgeInsets.all(6),
              shape: const CircleBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddMealSheet extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final String? mealType;
  final String? defaultMealType;

  const _AddMealSheet({this.initialData, this.mealType, this.defaultMealType});

  static Future<bool?> open(BuildContext context, {Map<String, dynamic>? initialData, String? mealType, String? defaultMealType}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => _AddMealSheet(
        initialData: initialData,
        mealType: mealType,
        defaultMealType: defaultMealType,
      ),
    );
  }

  @override
  State<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends State<_AddMealSheet> {
  final _api = AuthApi();
  late final TextEditingController _nameController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _fatController;
  late final TextEditingController _carbsController;
  String _selectedMealType = 'snack';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _nameController = TextEditingController(text: data?['name']?.toString());
    _caloriesController = TextEditingController(text: data?['calories']?.toString());
    _proteinController = TextEditingController(text: data?['protein']?.toString());
    _fatController = TextEditingController(text: data?['fat']?.toString());
    _carbsController = TextEditingController(text: data?['carbs']?.toString());

    if (widget.mealType != null) {
      _selectedMealType = widget.mealType!;
    } else if (data?['meal_type'] != null) {
      _selectedMealType = data!['meal_type'];
    } else if (widget.defaultMealType != null) {
      _selectedMealType = widget.defaultMealType!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    super.dispose();
  }

  Future<void> _saveMeal() async {
    setState(() => _busy = true);
    try {
      await _api.logMeal(
        mealType: _selectedMealType,
        name: _nameController.text,
        calories: int.tryParse(_caloriesController.text) ?? 0,
        protein: double.tryParse(_proteinController.text) ?? 0.0,
        fat: double.tryParse(_fatController.text) ?? 0.0,
        carbs: double.tryParse(_carbsController.text) ?? 0.0,
      );
      if(mounted) {
        Navigator.pop(context, true);
      }
    } catch(e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if(mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final mealTypes = {
      'breakfast': 'Завтрак',
      'lunch': 'Обед',
      'dinner': 'Ужин',
      'snack': 'Перекус'
    };

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.neutral200, borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                  widget.initialData != null ? 'Редактировать прием пищи' : 'Добавить прием пищи',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _selectedMealType,
                decoration: kiloInput('Тип приёма пищи'),
                items: mealTypes.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedMealType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(controller: _nameController, decoration: kiloInput('Название (напр. Омлет)')),
              const SizedBox(height: 10),
              TextField(controller: _caloriesController, decoration: kiloInput('Калории (ккал)'), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: _proteinController, decoration: kiloInput('Белки (г)'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _fatController, decoration: kiloInput('Жиры (г)'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _carbsController, decoration: kiloInput('Углев. (г)'), keyboardType: TextInputType.number)),
                ],
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _saveMeal,
                  icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cardBackground)) : const Icon(Icons.check_rounded),
                  label: Text(_busy ? 'Сохранение...' : 'Сохранить'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: AppColors.cardBackground,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({required this.title, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.neutral700))),
        Switch(value: value, onChanged: onChanged, activeColor: AppColors.green),
      ]),
    );
  }
}

/* ------------------------- DIET CARD ------------------------- */
class _NewDietCard extends StatelessWidget {
  final Map<String, dynamic> diet;
  const _NewDietCard({required this.diet});

// Новый парсер, который также включает 'recipe'
  List<Map<String, dynamic>> _parseMeals(List<dynamic>? meals) {
    // ИСПРАВЛЕНИЕ: Объединяем проверки, чтобы избежать ошибки .first
    if (meals == null || meals.isEmpty || meals.first is! Map) {
      return [];
    }

    return meals.map((meal) {
      final mealMap = meal as Map<String, dynamic>;
      return {
        'name': mealMap['name'] ?? 'Блюдо',
        'grams': mealMap['grams'] ?? 0,
        'recipe': mealMap['recipe'] ?? 'Рецепт не указан.'
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final meals = (diet['meals'] as Map? ?? {}).cast<String, dynamic>();

    // Парсим все приемы пищи
    final breakfastMeals = _parseMeals(meals['breakfast']);
    final lunchMeals = _parseMeals(meals['lunch']);
    final dinnerMeals = _parseMeals(meals['dinner']);
    final snackMeals = _parseMeals(meals['snack']);

    return KiloCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Ваш рацион', style: TextStyle(fontWeight: FontWeight.w900)),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('TODO: Вызвать API /generate_diet')),
              );
            },
            child: const Text('Пересоздать', style: TextStyle(color: AppColors.red)),
          ),
        ]),
        const SizedBox(height: 10),
        // Блок с Макросами (БЖУ)
        Row(children: [
          Expanded(child: _MacroPill(label: 'Калории', value: '${diet['total_kcal'] ?? 0} ккал', color: AppColors.green, bg: AppColors.green.withOpacity(0.1), border: AppColors.green.withOpacity(0.2))),
          const SizedBox(width: 8),
          Expanded(child: _MacroPill(label: 'Белки', value: '${diet['protein'] ?? 0} г', color: AppColors.primary, bg: AppColors.primary.withOpacity(0.1), border: AppColors.primary.withOpacity(0.2))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _MacroPill(label: 'Жиры', value: '${diet['fat'] ?? 0} г', color: AppColors.secondary, bg: AppColors.secondary.withOpacity(0.1), border: AppColors.secondary.withOpacity(0.2))),
          const SizedBox(width: 8),
          Expanded(child: _MacroPill(label: 'Углеводы', value: '${diet['carbs'] ?? 0} г', color: AppColors.neutral700, bg: AppColors.neutral100, border: AppColors.neutral200)),
        ]),
        const SizedBox(height: 12),
        // Новые раскрывающиеся карточки
        _DietMealExpansionTile(emoji: '🍳', title: 'Завтрак', meals: breakfastMeals),
        const SizedBox(height: 8),
        _DietMealExpansionTile(emoji: '🍲', title: 'Обед', meals: lunchMeals),
        const SizedBox(height: 8),
        _DietMealExpansionTile(emoji: '🍝', title: 'Ужин', meals: dinnerMeals),
        const SizedBox(height: 8),
        _DietMealExpansionTile(emoji: '🥜', title: 'Перекус', meals: snackMeals),
      ]),
    );
  }
}

class _DietMealExpansionTile extends StatelessWidget {
  final String emoji;
  final String title;
  final List<Map<String, dynamic>> meals;

  const _DietMealExpansionTile({
    required this.emoji,
    required this.title,
    required this.meals,
  });

  @override
  Widget build(BuildContext context) {
    // Если для этого приема пищи нет блюд, показываем простой ListTile
    if (meals.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.neutral50, border: Border.all(color: AppColors.neutral200), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.neutral700)),
            const Spacer(),
            const Text('-', style: TextStyle(color: AppColors.neutral400)),
          ],
        ),
      );
    }

    // Если блюда есть, создаем раскрывающийся список
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.neutral50,
          border: Border.all(color: AppColors.neutral200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: PageStorage(
            bucket: PageStorageBucket(),
            child: ExpansionTile(
              key: ValueKey(title),
              expansionAnimationStyle: AnimationStyle(
              curve: Curves.easeOutCubic,
              duration: const Duration(milliseconds: 250),
            ),
            trailing: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.neutral500),
            title: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.neutral700)),
              ],
            ),
            // Содержимое списка
            children: [
              Container(
                color: AppColors.cardBackground, // Фон для дочерних элементов
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: meals.map((meal) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ${meal['name']} (${meal['grams']} г)',
                            style: const TextStyle(color: AppColors.neutral800, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            meal['recipe'],
                            style: const TextStyle(color: AppColors.neutral600, fontSize: 13),
                          ),
                          if (meals.length > 1 && meal != meals.last)
                            const Divider(height: 20),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              )
            ],
            ),
          ), // <-- ❗️ Закрывающая скобка для PageStorage
        ),
      ),
    );
  }
}

/* ------------------------- WEEKLY CARD (placeholder) ------------------------- */
class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({super.key});
  @override
  Widget build(BuildContext context) {
    return KiloCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Динамика недели', style: TextStyle(fontWeight: FontWeight.w900)),
          SizedBox(height: 12),
          _ChartPlaceholder(title: 'Вес, кг'),
          SizedBox(height: 12),
          _ChartPlaceholder(title: 'Потреблено, ккал'),
          SizedBox(height: 12),
          _ChartPlaceholder(title: 'Сожжено, ккал'),
        ],
      ),
    );
  }
}


class DashboardPageSkeleton extends StatelessWidget {
  const DashboardPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold, чтобы соответствовать структуре страницы
    return Scaffold(
      appBar: AppBar(
        title: const Text('Главная'),
      ),
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Скелетон _UserProfileHeaderCard
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Skeleton(width: 84, height: 84, radius: 42),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Skeleton(width: 120, height: 16),
                      const SizedBox(height: 12),
                      const Skeleton(width: 160, height: 20),
                      const SizedBox(height: 12),
                      const Skeleton(width: 100, height: 28),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 2. Скелетон SectionTitle + Card
            const Skeleton(width: 180, height: 24),
            const SizedBox(height: 12),
            const Skeleton(width: double.infinity, height: 180), // _ProgressGoalCard
            const SizedBox(height: 24),

            // 3. Скелетон _WorkoutBlock
            const Skeleton(width: double.infinity, height: 90),
            const SizedBox(height: 16),

            // 4. Скелетон _MealsBlock
            const Skeleton(width: double.infinity, height: 90),
          ],
        ),
      ),
    );
  }
}


class _WeeklyConsumptionChart extends StatefulWidget {
  const _WeeklyConsumptionChart();

  @override
  State<_WeeklyConsumptionChart> createState() => _WeeklyConsumptionChartState();
}


class _HeartsStreakWidget extends StatelessWidget {
  final int streak;
  final List<bool> last7Days;
  final int? caloricDiff;

  const _HeartsStreakWidget({
    super.key, // Используем super.key
    required this.streak,
    required this.last7Days,
    this.caloricDiff,
  });

  @override
  Widget build(BuildContext context) {
    final safeHistory = List<bool>.filled(7, false);
    for (int i = 0; i < last7Days.length && i < 7; i++) {
      int targetIndex = 7 - last7Days.length + i;
      safeHistory[targetIndex] = last7Days[i];
    }

    // Логика отображения дефицита (используем локальную переменную)
    final int diff = caloricDiff ?? 0;
    final bool hasDiff = diff != 0;

    final bool isDeficit = diff >= 0;
    final String diffText = isDeficit
        ? 'Дефицит: $diff ккал'
        : 'Профицит: ${diff.abs()} ккал';

    final Color diffColor = isDeficit ? AppColors.green : const Color(0xFFFF9800);
    final IconData diffIcon = isDeficit ? Icons.local_fire_department_rounded : Icons.cookie_rounded;

    return KiloCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => _StreakShareDialog(streak: streak),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              // Заголовок
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF5722), size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '$streak дн. подряд',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.neutral900),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.ios_share_rounded, color: AppColors.neutral400, size: 16),
                ],
              ),
              const SizedBox(height: 16),

              // Ряд сердец
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  final bool isActive = safeHistory[index];
                  final bool isToday = index == 6;

                  return Expanded(
                    child: Column(
                      children: [
                        _buildHeartIcon(isActive),
                        const SizedBox(height: 6),
                        Text(
                          isToday ? 'Сегодня' : '${index - 6} д.',
                          style: TextStyle(
                            fontSize: 10,
                            color: isToday ? AppColors.neutral800 : AppColors.neutral400,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),

              if (hasDiff) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: diffColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: diffColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(diffIcon, size: 16, color: diffColor),
                      const SizedBox(width: 6),
                      Text(
                        diffText,
                        style: TextStyle(
                            color: diffColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeartIcon(bool isActive) {
    if (isActive) {
      return Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.favorite_rounded, color: AppColors.secondary, size: 36),
          Positioned(
            bottom: 4,
            child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFCC80), size: 18),
          ),
        ],
      );
    } else {
      return const Icon(Icons.heart_broken_rounded, color: AppColors.neutral300, size: 36);
    }
  }
}


class _SubscriptionSuccessDialog extends StatefulWidget {
  @override
  State<_SubscriptionSuccessDialog> createState() => _SubscriptionSuccessDialogState();
}

class _SubscriptionSuccessDialogState extends State<_SubscriptionSuccessDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Иконка
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF0FDF4), // Светло-зеленый
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium_rounded, size: 64, color: AppColors.green),
              ),
              const SizedBox(height: 24),
              const Text(
                'Поздравляем!\nSola Pro активирована',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.neutral900),
              ),
              const SizedBox(height: 12),
              const Text(
                'Вам открыт доступ ко всем функциям: AI-тренеру, генерации диет и умному сканеру еды.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.neutral600, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Закрываем диалог
                    // Открываем инструкции
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiInstructionsPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Узнать возможности', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Перейти к профилю', style: TextStyle(color: AppColors.neutral500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------------------- STREAK SHARING LOGIC ------------------------- */

class _StreakShareDialog extends StatefulWidget {
  final int streak;
  const _StreakShareDialog({required this.streak});

  @override
  State<_StreakShareDialog> createState() => _StreakShareDialogState();
}

class _StreakShareDialogState extends State<_StreakShareDialog> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  Future<void> _shareImage() async {
    setState(() => _isSharing = true);
    try {
      // 1. Рендерим виджет в картинку (независимо от экрана)
      final Uint8List imageBytes = await _screenshotController.captureFromWidget(
        _StreakBadgeCard(streak: widget.streak, forExport: true),
        pixelRatio: 3.0, // Высокое качество
        delay: const Duration(milliseconds: 10),
      );

      // 2. Сохраняем во временный файл
      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/kilo_streak.png').create();
      await imagePath.writeAsBytes(imageBytes);

      // 3. Шарим файл
      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: 'Я держу стрик дефицита каллорий ${widget.streak} дней в Sola! 🔥 Присоединяйся!',
      );
    } catch (e) {
      debugPrint('Error sharing: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Кнопка закрыть
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.white24),
            ),
          ),
          const SizedBox(height: 12),

          // Карточка (Визуализация)
          _StreakBadgeCard(streak: widget.streak, forExport: false),

          const SizedBox(height: 24),

          // Кнопка действия
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSharing ? null : _shareImage,
              icon: _isSharing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                  : const Icon(Icons.share_rounded, color: AppColors.primary),
              label: Text(_isSharing ? 'Подготовка...' : 'Поделиться в Stories'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Сама карточка, которая будет отрендерена в картинку
class _StreakBadgeCard extends StatelessWidget {
  final int streak;
  final bool forExport; // Если true - убираем тени, которые могут обрезаться при экспорте

  const _StreakBadgeCard({required this.streak, this.forExport = false});

  @override
  Widget build(BuildContext context) {
    // Размеры для Instagram Stories (примерно 9:16, но мы делаем компактную карточку)
    // Если forExport - задаем фиксированный размер для красивого экспорта
    return Container(
      width: forExport ? 400 : null,
      height: forExport ? 600 : 450, // Пропорция карточки
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF512F), Color(0xFFDD2476)], // Яркий оранжево-розовый градиент
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: forExport ? [] : [
          const BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10))
        ],
      ),
      child: Stack(
        children: [
          // Фоновые паттерны (круги)
          Positioned(
            top: -50, right: -50,
            child: Container(width: 200, height: 200, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle)),
          ),
          Positioned(
            bottom: -80, left: -20,
            child: Container(width: 250, height: 250, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle)),
          ),

          // Контент
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Логотип / Название
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text('Sola', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ],
                ),
                const Spacer(),

                // Иконка Огня
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: const Icon(Icons.local_fire_department_rounded, size: 80, color: Color(0xFFFF512F)),
                ),
                const SizedBox(height: 32),

                // Текст стрика
                Text(
                  '$streak',
                  style: const TextStyle(
                      fontSize: 96,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0
                  ),
                ),
                const Text(
                  'ДНЕЙ ПОДРЯД',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70,
                      letterSpacing: 1.5
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Не сбавляй темп! 🔥',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),

                const Spacer(),
                const Text(
                  'Присоединяйся к челленджу',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------- ACHIEVEMENT DIALOG (AUTO-ICON) ------------------------- */

class _AchievementUnlockedDialog extends StatefulWidget {
  final Map<String, dynamic> achievement;
  const _AchievementUnlockedDialog({required this.achievement});

  @override
  State<_AchievementUnlockedDialog> createState() => _AchievementUnlockedDialogState();
}

class _AchievementUnlockedDialogState extends State<_AchievementUnlockedDialog> with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _exitController;

  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;
  bool _showSuccessIcon = false; // Флаг для превращения иконки

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _exitController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    // 1. Запускаем появление
    _entryController.forward();

    // 2. АВТОМАТИЧЕСКАЯ СМЕНА ИКОНКИ
    // Ждем завершения анимации входа (800мс) + 500мс паузы
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) {
        setState(() => _showSuccessIcon = true);
      }
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  /// Анимация улетания -> Закрытие
  Future<void> _handleClose() async {
    await _exitController.forward();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _shareAchievement() async {
    setState(() => _isSharing = true);
    try {
      final Uint8List imageBytes = await _screenshotController.capture(
          pixelRatio: 3.0,
          delay: const Duration(milliseconds: 10)
      ) ?? Uint8List(0);

      if (imageBytes.isEmpty) return;

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/achievement.png').create();
      await imagePath.writeAsBytes(imageBytes);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: 'Мое новое достижение "${widget.achievement['title']}" в Sola! 🏆',
      );
    } catch (e) {
      debugPrint('Share error: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.achievement;

    // Маппинг иконок
    IconData iconData = Icons.star_rounded;
    if (item['icon'] == 'restaurant') iconData = Icons.restaurant_menu_rounded;
    if (item['icon'] == 'fitness_center') iconData = Icons.fitness_center_rounded;
    if (item['icon'] == 'fire') iconData = Icons.local_fire_department_rounded;
    if (item['icon'] == 'bolt') iconData = Icons.flash_on_rounded;
    if (item['icon'] == 'whatshot') iconData = Icons.whatshot_rounded;

    final entryScale = CurvedAnimation(parent: _entryController, curve: Curves.elasticOut);
    final exitCurve = CurvedAnimation(parent: _exitController, curve: Curves.easeInOutBack);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero, // На весь экран
      child: SizedBox.expand(
        child: Stack(
          children: [
            // 1. Фон
            FadeTransition(
              opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_exitController),
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

            // 2. Контент
            AnimatedBuilder(
              animation: Listenable.merge([_entryController, _exitController]),
              builder: (context, child) {
                double scale = entryScale.value;
                Alignment alignment = Alignment.center;

                if (_exitController.value > 0) {
                  scale = (1.0 - exitCurve.value).clamp(0.0, 1.0);
                  alignment = Alignment.lerp(Alignment.center, const Alignment(0.9, -0.9), exitCurve.value)!;
                }

                return Align(
                  alignment: alignment,
                  child: Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- КАРТОЧКА ---
                  Screenshot(
                    controller: _screenshotController,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 20))
                          ]
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              "SOLA AWARDS",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.neutral400, letterSpacing: 2.0)
                          ),
                          const SizedBox(height: 32),

                          // Иконка (AnimatedSwitcher)
                          SizedBox(
                            width: 100, height: 100,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 600),
                              switchInCurve: Curves.elasticOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                              child: _showSuccessIcon
                                  ? Container(
                                key: const ValueKey('success'),
                                decoration: const BoxDecoration(
                                    color: AppColors.green,
                                    shape: BoxShape.circle
                                ),
                                child: const Center(child: Icon(Icons.check_rounded, color: Colors.white, size: 56)),
                              )
                                  : Container(
                                key: const ValueKey('achievement'),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFFFF9C4),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFFBC02D), width: 2)
                                ),
                                child: Center(child: Icon(iconData, color: const Color(0xFFFBC02D), size: 48)),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          Text(
                            item['title'] ?? 'Награда',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.neutral900, height: 1.2),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item['description'] ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15, color: AppColors.neutral600, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // --- КНОПКИ ---
                  if (!_isSharing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _DialogButton(
                          icon: Icons.ios_share_rounded,
                          onPressed: _shareAchievement,
                          color: Colors.white,
                          iconColor: AppColors.neutral900,
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _handleClose, // Просто закрываем
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            elevation: 0,
                          ),
                          child: const Text("СУПЕР", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                        ),
                      ],
                    )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final Color iconColor;

  const _DialogButton({required this.icon, required this.onPressed, required this.color, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56, height: 56,
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor),
        ),
      ),
    );
  }
}

class _WeeklyConsumptionChartState extends State<_WeeklyConsumptionChart> {
  final _api = AuthApi();
  late Future<Map<String, dynamic>> _summaryFuture;

  @override
  void initState() {
    super.initState();
    // Запускаем загрузку данных при создании виджета
    _summaryFuture = _api.getWeeklySummary();
  }

  @override
  Widget build(BuildContext context) {
    // Используем FutureBuilder для отображения данных по мере загрузки
    return FutureBuilder<Map<String, dynamic>>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        // 1. Пока ждем - показываем старую заглушку
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ChartPlaceholder(title: 'Потребление за неделю (Загрузка...)');
        }

        // 2. Если ошибка или нет данных
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          // print(snapshot.error); // Для отладки
          return const _ChartPlaceholder(title: 'Потребление за неделю (Ошибка)');
        }

        // 3. Данные получены, парсим их
        final data = snapshot.data!;
        final labels = (data['labels'] as List? ?? []).cast<String>();
        // Бэкенд возвращает 'consumed_kcal'
        // Безопасно парсим числа, заменяя null на 0.0
        final values = (data['datasets']?['consumed_kcal'] as List? ?? []).map((v) => (v as num?) ?? 0.0).toList();

        if (labels.isEmpty || values.isEmpty || labels.length != values.length) {
          return const _ChartPlaceholder(title: 'Потребление за неделю (Нет данных)');
        }

        // 4. Рендерим настоящий график
        return _buildChart(labels, values);
      },
    );
  }

  /// Виджет, который рендерит сам чарт (простая версия)
  Widget _buildChart(List<String> labels, List<num> values) {
    // Находим максимальное значение для масштабирования
    final double maxValue = values.fold(0.0, (prev, e) => e > prev ? e.toDouble() : prev);
    final double maxHeight = 150.0; // Макс. высота столбца

    return KiloCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Потребление за неделю (ккал)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.neutral600),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: maxHeight + 50, // Высота + место для подписей
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(labels.length, (index) {
                final value = values[index].toDouble();
                // Рассчитываем высоту столбца относительно максимума
                final barHeight = (value / (maxValue > 0 ? maxValue : 1.0)) * maxHeight;

                return Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Текст (значение)
                      Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10, color: AppColors.neutral500, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Столбец
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        width: 30, // Ширина столбца
                        height: barHeight.clamp(4.0, maxHeight), // Мин. высота, чтобы было видно
                        decoration: BoxDecoration(
                          // Используем градиент для красоты
                          gradient: const LinearGradient(
                            colors: AppColors.gradientPrimary,
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Подпись (день недели)
                      Text(
                        labels[index],
                        style: const TextStyle(fontSize: 11, color: AppColors.neutral600, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

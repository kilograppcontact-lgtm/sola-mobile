import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:ui' show Shader;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import 'app_theme.dart';
import 'auth_api.dart';
import 'main.dart';
import 'purchase_page.dart';


class OnboardingFlowPage extends StatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  State<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

/// Модель для хранения данных онбординга (Новый флоу)
class _OnboardingData {
  // --- Шаг 1 ---
  bool? hasSmartScales;

  // --- Шаг 2 (Путь А) ---
  File? scalesPhoto;
  // (Путь Б)
  double? height;
  double? weight;
  double? estimatedFatPercentage;

  // --- Шаг 3 (Общий) ---
  File? fullBodyPhoto;

  // --- Данные для API ---
  // Карта с метриками, полученная ЛИБО из analyzeScalesPhoto (Путь А),
  // ЛИБО собранная вручную (Путь Б).
  Map<String, dynamic>? metrics;

  // --- Шаг 5 (Результат) ---
  String? afterPhotoUrl; // URL фото "После" от бэкенда
  String? beforePhotoUrl; // URL фото "До" от бэкенда
}

class _OnboardingFlowPageState extends State<OnboardingFlowPage>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  final _api = AuthApi();
  final _data = _OnboardingData();

  // Контроллеры для "Точки А" (Ручной ввод ИЛИ Дозаполнение)
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _fatMassController = TextEditingController(); // НОВЫЙ (для дозаполнения)
  final _manualFormKey = GlobalKey<FormState>(); // Для ручного
  final _manualFillFormKey = GlobalKey<FormState>(); // Для дозаполнения

  bool _isLoading = false;
  String _errorMessage = '';

  // Индекс текущей страницы
  int _pageIndex = 0;
  // Динамический подсчет шагов
  int _totalSteps = 6;
  int _currentStep = 1;

  // --- НОВЫЕ ПОЛЯ ДЛЯ АНИМАЦИЙ ---
  late final AnimationController _contentAnimController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final AnimationController _loaderRotationController;

  // --- НОВОЕ: Поля для анимации текста загрузки ---
  late final List<String> _loadingTexts;
  int _currentLoadingTextIndex = 0;
  Timer? _loadingTextTimer;
  // ---

  @override
  void initState() {
    super.initState();

    // --- ИНИЦИАЛИЗАЦИЯ АНИМАЦИЙ КОНТЕНТА ---
    _contentAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Длительность появления
    );

    _fadeAnimation = CurvedAnimation(
      parent: _contentAnimController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.1), // Появление снизу (10% от высоты)
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentAnimController,
      curve: Curves.easeOutCubic,
    ));

    // --- ИНИЦИАЛИЗАЦИЯ АНИМАЦИИ ЗАГРУЗЧИКА ---
    _loaderRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Полный оборот за 2 сек
    )..repeat(); // Бесконечное повторение

    // --- НОВОЕ: Инициализация текстов загрузки ---
    _loadingTexts = [
      'AI создает вашу "Точку Б"...',
      'Анализируем пропорции...',
      'Рассчитываем состав тела...',
      'Применяем магию Gemini...',
      'Генерируем визуализацию...',
      'Почти готово...',
    ];
    _currentLoadingTextIndex = 0;
    // ---

    // Запускаем анимацию для первой страницы
    _contentAnimController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _fatMassController.dispose();
    // --- ОЧИСТКА КОНТРОЛЛЕРОВ АНИМАЦИИ ---
    _contentAnimController.dispose();
    _loaderRotationController.dispose();
    _loadingTextTimer?.cancel(); // <-- НОВОЕ: Остановка таймера
    super.dispose();
  }

  // --- НОВОЕ: Хелперы для запуска/остановки таймера текста ---
  void _startLoadingTextAnimation() {
    // Сбрасываем таймер, если он уже был
    _loadingTextTimer?.cancel();
    // Запускаем новый
    _loadingTextTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentLoadingTextIndex = (_currentLoadingTextIndex + 1) % _loadingTexts.length;
      });
    });
  }

  void _stopLoadingTextAnimation() {
    _loadingTextTimer?.cancel();
    // Сбрасываем на 0 для следующего раза
    _currentLoadingTextIndex = 0;
  }
  // ---

  /// Обновляет счетчик шагов
  void _updatePage(int newIndex) {
    setState(() {
      _pageIndex = newIndex;

      if (_data.hasSmartScales == true) {
        // Путь "Да" (Весы): 0 -> 4 -> (5) -> 6 -> 7 -> 8 (6 шагов)
        _totalSteps = 6;
        if (newIndex == 0) _currentStep = 1;
        if (newIndex == 4) _currentStep = 2; // (Загрузка весов)
        if (newIndex == 5) _currentStep = 3; // (Дозаполнение)
        if (newIndex == 6) _currentStep = 4; // (Фото в рост)
        if (newIndex == 7) _currentStep = 5; // (Загрузка)
        if (newIndex == 8) _currentStep = 6; // (Пейволл)
      } else if (_data.hasSmartScales == false) {
        // Путь "Нет" (Ручной): 0 -> 1 -> 2 -> 3 -> 6 -> 7 -> 8 (7 шагов)
        _totalSteps = 7;
        if (newIndex == 0) _currentStep = 1;
        if (newIndex == 1) _currentStep = 2; // (Ручной ввод)
        if (newIndex == 2) _currentStep = 3; // (ИМТ)
        if (newIndex == 3) _currentStep = 4; // (% жира)
        if (newIndex == 6) _currentStep = 5; // (Фото в рост)
        if (newIndex == 7) _currentStep = 6; // (Загрузка)
        if (newIndex == 8) _currentStep = 7; // (Пейволл)
      } else {
        // Выбор еще не сделан
        _totalSteps = 6;
        _currentStep = 1;
      }
    });
    _contentAnimController.forward(from: 0.0);
  }

  /// Главная навигация
  void _nextPage() {
    if (_isLoading) return;
    setState(() => _errorMessage = '');

    // --- Шаг 0 (Выбор) ---
    if (_pageIndex == 0) {
      if (_data.hasSmartScales == null) {
        setState(() => _errorMessage = 'Пожалуйста, сделайте выбор');
        return;
      }
      if (_data.hasSmartScales == true) {
        _goToPage(4); // Переход на "Загрузку фото весов"
      } else {
        _goToPage(1); // Переход на "Ручной ввод"
      }
      return;
    }

    // --- Шаг 1 (Ручной ввод) ---
    if (_pageIndex == 1) {
      if (!_manualFormKey.currentState!.validate()) return;
      _data.height = double.tryParse(_heightController.text);
      _data.weight = double.tryParse(_weightController.text);
      _goToPage(2); // Переход на "ИМТ"
      return;
    }

    // --- Шаг 2 (ИМТ) ---
    if (_pageIndex == 2) {
      _goToPage(3); // Переход на "% Жира"
      return;
    }

    // --- Шаг 3 (% Жира) ---
    if (_pageIndex == 3) {
      if (_data.estimatedFatPercentage == null) {
        setState(() => _errorMessage = 'Пожалуйста, выберите наиболее похожее фото');
        return;
      }
      // Собираем ручные метрики
      _data.metrics = {
        "height": _data.height,
        "weight": _data.weight,
        "fat_mass": (_data.weight ?? 0.0) * ((_data.estimatedFatPercentage ?? 0.0) / 100.0),
        "muscle_mass": null,
        "bmi": null,
        "metabolism": null,
        "visceral_fat_rating": null,
        "body_age": null,
        "body_water": null,
        "protein_percentage": null,
      };
      _goToPage(6); // Переход на "Фото в полный рост"
      return;
    }

    // --- Шаг 4 (Загрузка Весов) ---
    if (_pageIndex == 4) {
      if (_data.scalesPhoto == null) {
        setState(() => _errorMessage = 'Пожалуйста, загрузите скриншот');
        return;
      }
      // Запускаем анализ весов, он сам переведет
      _runScalesAnalysis();
      return;
    }

    // --- Шаг 5 (Дозаполнение) ---
    if (_pageIndex == 5) {
      if (!_manualFillFormKey.currentState!.validate()) return;
      // Дополняем _data.metrics
      _data.metrics ??= {}; // На всякий случай
      _data.metrics!['height'] ??= double.tryParse(_heightController.text);
      _data.metrics!['weight'] ??= double.tryParse(_weightController.text);
      _data.metrics!['fat_mass'] ??= double.tryParse(_fatMassController.text);
      _goToPage(6); // Переход на "Фото в полный рост"
      return;
    }


    // --- Шаг 6 (Фото в полный рост) ---
    if (_pageIndex == 6) {
      if (_data.fullBodyPhoto == null) {
        setState(() => _errorMessage = 'Пожалуйста, загрузите фото в полный рост');
        return;
      }
      // Запускаем "Nano Banana", он сам переведет
      _runNanoBananaVisualization();
      return;
    }
  }

  void _previousPage() {
    if (_isLoading) return;

    // С экрана Загрузки (7) или Пейволла (8) назад нельзя
    if (_pageIndex == 7 || _pageIndex == 8) return;

    int targetPage = _pageIndex - 1;

    // --- Шаг 1 (Ручной) или Шаг 4 (Весы) ---
    if (_pageIndex == 1 || _pageIndex == 4) {
      targetPage = 0; // Назад на Выбор
    }

    // --- Шаг 2 (ИМТ) ---
    if (_pageIndex == 2) {
      targetPage = 1; // Назад на Ручной ввод
    }

    // --- Шаг 3 (% Жира) ---
    if (_pageIndex == 3) {
      targetPage = 2; // Назад на ИМТ
    }

    // --- Шаг 5 (Дозаполнение) ---
    if (_pageIndex == 5) {
      targetPage = 4; // Назад на Загрузку весов
    }

    // --- Шаг 6 (Фото в рост) ---
    if (_pageIndex == 6) {
      if (_data.hasSmartScales == true) {
        // Если пришли с дозаполнения (5) или напрямую (4)
        targetPage = _data.metrics?['height'] == null || _data.metrics?['weight'] == null || _data.metrics?['fat_mass'] == null
            ? 5 // Назад на Дозаполнение
            : 4; // Назад на Загрузку весов
      } else {
        targetPage = 3; // Назад на % Жира
      }
    }

    _goToPage(targetPage);
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 600), // Увеличено
      curve: Curves.easeOutBack,
    );
  }

  // --- Методы выбора медиа ---
  Future<void> _pickFullBodyPhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _data.fullBodyPhoto = File(image.path);
        _errorMessage = '';
      });
    }
  }

  Future<void> _pickScalesPhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _data.scalesPhoto = File(image.path);
        _errorMessage = '';
      });
    }
  }

  // --- API ВЫЗОВЫ ---

  /// ЭТАП 2 (Путь А): Анализ скриншота весов
  Future<void> _runScalesAnalysis() async {
    setState(() => _isLoading = true);
    _goToPage(7); // Сразу переходим на экран загрузки (индекс 7)
    _startLoadingTextAnimation(); // <-- НОВОЕ: Запускаем таймер текста

    try {
      // 1. Вызываем API
      final Map<String, dynamic> metrics =
      await _api.analyzeScalesPhoto(_data.scalesPhoto!);

      _stopLoadingTextAnimation(); // <-- НОВОЕ: Останавливаем таймер (успех)

      // 2. Сохраняем метрики
      _data.metrics = metrics;

      // 3. ПРОВЕРКА (Успех, но данные могут быть частичными)
      //    (Эта логика ловит случай, когда API вернул 200 OK, но не все поля)
      if (metrics['height'] == null ||
          metrics['weight'] == null ||
          metrics['fat_mass'] == null) {
        // Данные отсутствуют, переходим на дозаполнение
        _heightController.text = metrics['height']?.toString() ?? '';
        _weightController.text = metrics['weight']?.toString() ?? '';
        _fatMassController.text = metrics['fat_mass']?.toString() ?? '';

        _goToPage(5); // Переход на "Дозаполнение" (индекс 5)
      } else {
        // Все данные есть, переходим к фото в рост
        _goToPage(6); // Переход на "Фото в полный рост" (индекс 6)
      }
    } catch (e) {
      if (!mounted) return;
      _stopLoadingTextAnimation(); // <-- НОВОЕ: Останавливаем таймер (ошибка)

      // --- НОВАЯ ЛОГИКА ОБРАБОТКИ ОШИБОК ---
      String errorMessage = 'Неизвестная ошибка: $e';
      bool needsManualFill = false;

      if (e is DioException && e.error != null) {
        errorMessage = e.error.toString();
        // ПРОВЕРЯЕМ ТЕКСТ ОШИБКИ ОТ БЭКЕНДА
        if (errorMessage.contains("Не удалось распознать Рост")) {
          // Бэкенд сигнализирует, что Рост не найден
          // Переводим на ручное дозаполнение
          needsManualFill = true;
        }
      }

      if (needsManualFill) {
        // Переходим на "Дозаполнение" (индекс 5)
        // Поля будут пустыми, т.к. ИИ ничего не вернул
        _heightController.text = '';
        _weightController.text = '';
        _fatMassController.text = '';
        _goToPage(5);
      } else {
        // Обычная ошибка (сеть, 500 и т.д.)
        // Возвращаем на экран загрузки весов (индекс 4)
        _goToPage(4);
        setState(() => _errorMessage = errorMessage);
      }
      // --- КОНЕЦ НОВОЙ ЛОГИКИ ---

    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ЭТАП 2 (Общий шаг): Запускает "nano banana" (Gemini)
  Future<void> _runNanoBananaVisualization() async {
    setState(() => _isLoading = true);
    _goToPage(7); // Переходим на экран загрузки (индекс 7)
    _startLoadingTextAnimation(); // <-- НОВОЕ: Запускаем таймер текста

    try {
      // 1. Вызываем API
      final result = await _api.generateVisualization(
        metrics: _data.metrics!,
        fullBodyPhoto: _data.fullBodyPhoto!,
      );

      _stopLoadingTextAnimation(); // <-- НОВОЕ: Останавливаем таймер (успех)

      // 2. Сохраняем URL
      setState(() {
        _data.beforePhotoUrl = result['before_photo_url'];
        _data.afterPhotoUrl = result['after_photo_url'];
      });

      // 3. Переходим на Пейволл
      if (mounted) _goToPage(8); // Индекс 8
    } catch (e) {
      _stopLoadingTextAnimation(); // <-- НОВОЕ: Останавливаем таймер (ошибка)
      if (mounted) {
        // Ошибка, возвращаем на "Фото в полный рост"
        _goToPage(6);
        setState(() => _errorMessage = 'Ошибка AI-генерации: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  /// ЭТАП 2 (Конец): Завершение
  Future<void> _completeOnboarding() async {
    await _api.completeOnboardingFlow();
    if (!mounted) return;
    // Переходим в KiloShell
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => const KiloShell(startOnboarding: true)),
            (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        leading: (_pageIndex > 0 && _pageIndex != 7 && _pageIndex != 8)
            ? IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _previousPage,
        )
            : null,
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: AppColors.gradientPrimary,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            'Шаг $_currentStep из $_totalSteps',
            style: const TextStyle(
              fontWeight: FontWeight.w900, // Жирный шрифт
              fontSize: 20, // Немного крупнее
              color: Colors.white, // Обязательно для ShaderMask
            ),
          ),
        ),
      ),
      // ---
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: _updatePage,
        children: [
          _buildSmartScalesChoicePage(), // 0: Выбор "Весы"
          _buildManualEntryPage(), // 1: (Анкета "Ручной")
          _buildBmiResultPage(), // 2: (ИМТ "Ручной")
          _buildFatPercentagePage(), // 3: (План Б "Ручной")
          _buildScalesUploadPage(), // 4: (Загрузка "Весы")
          _buildManualFillPage(), // 5: НОВЫЙ (Дозаполнение)
          _buildFullBodyPhotoPage(), // 6: (Фото в рост "Общий")
          _buildLoadingPage(), // 7: (Генерация "Общий")
          _buildPaywallPage(), // 8: (Пейволл "Общий")
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    // Не показываем кнопки на экране загрузки (7) и пейволле (8)
    if (_pageIndex == 7 || _pageIndex == 8) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                _errorMessage,
                style: const TextStyle(
                    color: AppColors.red, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextPage,
              child: Text(
                // Меняем текст на последнем шаге
                _pageIndex == 6
                    ? 'Сгенерировать мою "Точку Б" ✨'
                    : 'Продолжить',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Страница 0: Выбор "Умные весы"
  Widget _buildSmartScalesChoicePage() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text('Сбор данных',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            const Text(
                'Для точного анализа нам нужны ваши метрики. У вас есть умные весы (например, Picooc, Xiaomi), которые показывают % жира и мышечную массу?',
                style: TextStyle(fontSize: 16, color: AppColors.neutral600)),
            const SizedBox(height: 24),
            KiloCard(
              borderColor: _data.hasSmartScales == true
                  ? AppColors.primary
                  : AppColors.neutral200,
              color: _data.hasSmartScales == true
                  ? AppColors.primary.withOpacity(0.05)
                  : AppColors.cardBackground,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => setState(() {
                  _data.hasSmartScales = true;
                  _errorMessage = '';
                }),
                borderRadius: BorderRadius.circular(18),
                child: const ListTile(
                  title: Text('Да, у меня есть весы',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Я загружу скриншот из приложения'),
                  trailing: Icon(Icons.monitor_weight_rounded,
                      color: AppColors.primary, size: 28),
                ),
              ),
            ),
            const SizedBox(height: 16),
            KiloCard(
              borderColor: _data.hasSmartScales == false
                  ? AppColors.secondary
                  : AppColors.neutral200,
              color: _data.hasSmartScales == false
                  ? AppColors.secondary.withOpacity(0.05)
                  : AppColors.cardBackground,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => setState(() {
                  _data.hasSmartScales = false;
                  _errorMessage = '';
                }),
                borderRadius: BorderRadius.circular(18),
                child: const ListTile(
                  title: Text('Нет, у меня обычные весы',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Я введу данные вручную'),
                  trailing: Icon(Icons.edit_note_rounded,
                      color: AppColors.secondary, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Страница 1: Ручной ввод (Путь Б)
  Widget _buildManualEntryPage() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Form(
          key: _manualFormKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const Text('Ваши "Точка А"',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              const Text(
                  'Введите ваши текущие показатели. (Пол и возраст мы уже знаем из вашего профиля).',
                  style: TextStyle(fontSize: 16, color: AppColors.neutral600)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _heightController,
                decoration: kiloInput('Ваш рост (см)'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.isEmpty) ? 'Введите рост' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _weightController,
                decoration: kiloInput('Ваш вес (кг)'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.isEmpty) ? 'Введите вес' : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Страница 2: Оценка % жира (Путь Б)
  Widget _buildFatPercentagePage() {
    // (Пол пользователя должен быть получен из User.sex,
    // но для простоты мы оставим заглушку. В идеале -
    // нужно было бы в AuthCheckPage передать User)
    const String userSex = 'male'; // ЗАГЛУШКА

    final List<Map<String, dynamic>> options = userSex == 'male'
        ? [
      {'image': 'assets/fat/male_15.png', 'value': 15.0, 'label': '15% жира'},
      {'image': 'assets/fat/male_25.png', 'value': 25.0, 'label': '25% жира'},
      {'image': 'assets/fat/male_35.png', 'value': 35.0, 'label': '35% жира'},
      {'image': 'assets/fat/male_45.png', 'value': 45.0, 'label': '45% жира'},
    ]
        : [
      {'image': 'assets/fat/female_20.png', 'value': 20.0, 'label': '20% жира'},
      {'image': 'assets/fat/female_30.png', 'value': 30.0, 'label': '30% жира'},
      {'image': 'assets/fat/female_40.png', 'value': 40.0, 'label': '40% жира'},
      {'image': 'assets/fat/female_50.png', 'value': 50.0, 'label': '50% жира'},
    ];

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text('Оцените ваш % жира',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            const Text(
                'Какое фото наиболее похоже на вас? Это поможет AI точнее определить цель.',
                style: TextStyle(fontSize: 16, color: AppColors.neutral600)),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 3 / 4,
              ),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final bool isSelected =
                    _data.estimatedFatPercentage == option['value'];
                return GestureDetector(
                  onTap: () => setState(() {
                    _data.estimatedFatPercentage = option['value'];
                    _errorMessage = '';
                  }),
                  child: KiloCard(
                    borderColor:
                    isSelected ? AppColors.primary : AppColors.neutral200,
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.05)
                        : AppColors.cardBackground,
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            color: AppColors.neutral100,
                            // ЗАГЛУШКА: Здесь должно быть Image.asset(option['image'])
                            child: Center(
                                child: Icon(Icons.person,
                                    size: 80, color: AppColors.neutral300)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(option['label'],
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.neutral800)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Страница 3: Загрузка фото "Умных весов" (Путь А)
  Widget _buildScalesUploadPage() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text('Анализ "Точки А"',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            const Text(
                'Отлично! Пожалуйста, сделайте замер и загрузите скриншот из приложения ваших весов (например, Picooc), где видны все показатели.',
                style: TextStyle(fontSize: 16, color: AppColors.neutral600)),
            const SizedBox(height: 24),
            KiloCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: _pickScalesPhoto,
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: _data.scalesPhoto != null
                      ? Image.file(_data.scalesPhoto!, fit: BoxFit.cover)
                      : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_rounded,
                          size: 60, color: AppColors.neutral400),
                      SizedBox(height: 16),
                      Text('Нажмите, чтобы загрузить скриншот',
                          style: TextStyle(
                              fontSize: 16, color: AppColors.neutral600)),
                      Text('(экран весов)',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.neutral400)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Страница 4: НОВЫЙ ЭКРАН (Дозаполнение)
  Widget _buildManualFillPage() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Form(
          key: _manualFillFormKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const Text('Уточним данные',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              const Text(
                  'AI не смог распознать некоторые поля. Пожалуйста, проверьте и заполните их вручную.',
                  style: TextStyle(fontSize: 16, color: AppColors.neutral600)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _heightController,
                decoration: kiloInput('Ваш рост (см)'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.isEmpty) ? 'Введите рост' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _weightController,
                decoration: kiloInput('Ваш вес (кг)'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.isEmpty) ? 'Введите вес' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fatMassController,
                decoration: kiloInput('Масса жира (кг)'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.isEmpty) ? 'Введите массу жира' : null,
              ),
            ],
          ),
        ),
      ),
    );
  }


  /// Страница 5: Фото "До" (Общий шаг)
  Widget _buildFullBodyPhotoPage() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text('Фото в полный рост',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            const Text(
                'Последний шаг. Загрузите ваше фото в полный рост. AI использует его для создания "Точки Б", не меняя фон и одежду.',
                style: TextStyle(fontSize: 16, color: AppColors.neutral600)),
            const SizedBox(height: 24),
            KiloCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: _pickFullBodyPhoto,
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: _data.fullBodyPhoto != null
                      ? Image.file(_data.fullBodyPhoto!, fit: BoxFit.cover)
                      : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_rounded,
                          size: 60, color: AppColors.neutral400),
                      SizedBox(height: 16),
                      Text('Нажмите, чтобы загрузить фото',
                          style: TextStyle(
                              fontSize: 16, color: AppColors.neutral600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Страница 6: Генерация "Точки Б" (Общий шаг)
  Widget _buildLoadingPage() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: KiloCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- "ЖИВОЙ" ЛОАДЕР ---
                RotationTransition(
                  turns: _loaderRotationController,
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: AppColors.gradientPrimary,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
                    child: const Icon(
                      Icons.sync_rounded, // Иконка "синхронизации"
                      size: 44,
                      color: Colors.white, // Обязательно для ShaderMask
                    ),
                  ),
                ),
                // ---
                const SizedBox(height: 20),

                // --- НОВОЕ: Анимированный текст ---
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.2), // Снизу
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    _loadingTexts[_currentLoadingTextIndex],
                    key: ValueKey<int>(_currentLoadingTextIndex),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neutral800),
                  ),
                ),
                // ---

                const SizedBox(height: 8),
                const Text(
                  'Это может занять до минуты. (Nano Banana)',
                  style: TextStyle(fontSize: 14, color: AppColors.neutral600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// --- НОВЫЙ ВСПОМОГАТЕЛЬНЫЙ ВИДЖЕТ: СТАТИСТИКА ВРЕМЕНИ ---
  Widget _buildTimeStat(String value, String unit, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 42, // Крупный шрифт
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            unit,
            style: TextStyle(
              fontSize: 20, // Шрифт поменьше
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// --- НОВЫЙ ВСПОМОГАТЕЛЬНЫЙ ВИДЖЕТ: СТРОКА ФУНКЦИИ (ДЛЯ СРАВНЕНИЯ) ---
  Widget _buildFeatureRow(IconData icon, String text, {bool enabled = true}) {
    final color = enabled ? AppColors.neutral800 : AppColors.neutral400;
    final iconColor = enabled ? AppColors.primary : AppColors.neutral400;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
              // Зачеркиваем, если функция отключена
              decoration: enabled ? TextDecoration.none : TextDecoration.lineThrough,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBmiResultPage() {
    // Расчет ИМТ
    final double h = (double.tryParse(_heightController.text) ?? 160) / 100; // переводим см в м
    final double w = double.tryParse(_weightController.text) ?? 60;

    double bmi = 0;
    if (h > 0) {
      bmi = w / (h * h);
    }

    String status;
    Color color;
    String description;

    if (bmi < 18.5) {
      status = "Дефицит массы";
      color = Colors.blueAccent;
      description = "Ваш вес ниже нормы. Нам стоит сфокусироваться на наборе качественной мышечной массы.";
    } else if (bmi < 25) {
      status = "Норма";
      color = AppColors.green;
      description = "Отличный результат! Ваш вес в здоровом диапазоне. Будем работать над рельефом и тонусом.";
    } else if (bmi < 30) {
      status = "Избыточный вес";
      color = Colors.orange;
      description = "Ваш ИМТ немного выше нормы. Мы поможем вам плавно прийти в идеальную форму без стресса.";
    } else {
      status = "Ожирение";
      color = AppColors.red;
      description = "Важно заняться здоровьем. Мы составим для вас щадящий план питания и тренировок.";
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Ваш ИМТ',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neutral600
                ),
              ),
              const SizedBox(height: 16),
              KiloCard(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                borderColor: color.withOpacity(0.3),
                color: color.withOpacity(0.05),
                child: Column(
                  children: [
                    Text(
                      bmi.toStringAsFixed(1),
                      style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          color: color
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(20)
                      ),
                      child: Text(
                          status,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16
                          )
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.neutral800,
                    height: 1.4,
                    fontWeight: FontWeight.w500
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildPaywallPage() {
    final beforeUrl = _data.beforePhotoUrl;
    final afterUrl = _data.afterPhotoUrl;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text(
              'Ваша трансформация',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Коллаж "До" / "После"
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('Точка А (Сейчас)',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.neutral500)),
                      const SizedBox(height: 8),
                      KiloCard(
                        padding: EdgeInsets.zero,
                        child: AspectRatio(
                          aspectRatio: 3 / 4,
                          child: (beforeUrl != null)
                              ? Image.network('${AuthApi.baseUrl}$beforeUrl',
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) =>
                              progress == null
                                  ? child
                                  : const Skeleton(
                                  width: double.infinity,
                                  height: double.infinity,
                                  radius: 0),
                              errorBuilder: (c, e, s) =>
                              const Center(child: Icon(Icons.error)))
                              : const Skeleton(
                              width: double.infinity,
                              height: double.infinity,
                              radius: 0),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      const Text('Точка Б (Цель)',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.green)),
                      const SizedBox(height: 8),
                      KiloCard(
                        borderColor: AppColors.green,
                        padding: EdgeInsets.zero,
                        child: AspectRatio(
                          aspectRatio: 3 / 4,
                          child: (afterUrl != null)
                              ? Image.network('${AuthApi.baseUrl}$afterUrl',
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) =>
                              progress == null
                                  ? child
                                  : const Skeleton(
                                  width: double.infinity,
                                  height: double.infinity,
                                  radius: 0),
                              errorBuilder: (c, e, s) =>
                              const Center(child: Icon(Icons.error)))
                              : const Skeleton(
                              width: double.infinity,
                              height: double.infinity,
                              radius: 0),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // --- НОВЫЙ БЛОК: Путь 2 (Sola Pro) ---
            KiloCard(
              borderColor: AppColors.primary,
              color: AppColors.primary.withOpacity(0.05),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Путь c Sola Pro',
                      style: TextStyle(
                          fontSize: 20, // Крупнее
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                  // Визуализация времени
                  _buildTimeStat("3-6", "мес.", AppColors.primary),
                  const Divider(height: 16, color: AppColors.primary),
                  // Список функций (включено)
                  _buildFeatureRow(Icons.auto_awesome_rounded, "Персональный AI-коуч", enabled: true),
                  _buildFeatureRow(Icons.restaurant_menu_rounded, "Генерация диет", enabled: true),
                  _buildFeatureRow(Icons.analytics_rounded, "AI-визуализация тела", enabled: true),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      // Сначала на Пейволл
                      final result = await Navigator.of(context).push<bool?>(
                        MaterialPageRoute(
                            builder: (context) => const PurchasePage()),
                      );
                      // Если с пейволла вернулись с успехом (true)
                      if (result == true) {
                        _completeOnboarding();
                      }
                    },
                    child: const Text('Выбрать Sola Pro'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- НОВЫЙ БЛОК: Путь 1 (Базовый) ---
            KiloCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Базовый путь',
                      style: TextStyle(
                          fontSize: 20, // Крупнее
                          fontWeight: FontWeight.w800,
                          color: AppColors.neutral800)),
                  // Визуализация времени
                  _buildTimeStat("6-9", "мес.", AppColors.neutral500),
                  const Divider(height: 16, color: AppColors.neutral200),
                  // Список функций (выключено)
                  _buildFeatureRow(Icons.auto_awesome_rounded, "Персональный AI-коуч", enabled: false),
                  _buildFeatureRow(Icons.restaurant_menu_rounded, "Генерация диет", enabled: false),
                  _buildFeatureRow(Icons.analytics_rounded, "AI-визуализация тела", enabled: false),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      // Сразу завершаем онбординг
                      _completeOnboarding();
                    },
                    child: const Text('Начать бесплатно'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16), // Доп. отступ
          ],
        ),
      ),
    );
  }
}

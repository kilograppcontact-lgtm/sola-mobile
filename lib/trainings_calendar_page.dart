import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Для форматирования дат
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart'; // ОБЯЗАТЕЛЬНО ДОБАВИТЬ В pubspec.yaml
import 'ai_workout_page.dart'; // <-- ИМПОРТ СТРАНИЦЫ С КАМЕРОЙ
import 'auth_api.dart';
import 'index.dart'; // Для AppColors, KiloCard и т.д.
import 'app_theme.dart'; // Для AppColors
import 'purchase_page.dart';

class TrainingsCalendarPage extends StatefulWidget {
  final VoidCallback? onTrainingChanged;
  final bool hasSubscription;

  const TrainingsCalendarPage({
    super.key,
    this.onTrainingChanged,
    this.hasSubscription = false,
  });

  @override
  State<TrainingsCalendarPage> createState() => TrainingsCalendarPageState();
}

class TrainingsCalendarPageState extends State<TrainingsCalendarPage> {
  final _api = AuthApi();

  // Состояние календаря
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Состояние загрузки
  bool _isLoading = true;

  // Данные
  String _currentMonthKey = '';
  Set<DateTime> _mealDates = {};
  Set<DateTime> _streakDates = {};
  int _currentStreak = 0;

  // События (Тренировки)
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  List<Map<String, dynamic>> _selectedEvents = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _currentMonthKey = DateFormat('yyyy-MM').format(_focusedDay);
    _fetchCalendarData(_currentMonthKey);
  }

  void _calculateStreakDates() {
    _streakDates.clear();
    if (_currentStreak <= 0 || _mealDates.isEmpty) return;

    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final yesterdayNorm = todayNorm.subtract(const Duration(days: 1));

    DateTime? endDate;

    if (_mealDates.any((d) => isSameDay(d, todayNorm))) {
      endDate = todayNorm;
    } else if (_mealDates.any((d) => isSameDay(d, yesterdayNorm))) {
      endDate = yesterdayNorm;
    }

    if (endDate != null) {
      for (int i = 0; i < _currentStreak; i++) {
        _streakDates.add(endDate.subtract(Duration(days: i)));
      }
    }
  }

  Future<void> _fetchCalendarData(String monthKey) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _api.getCalendarData(monthKey),
        _api.getTrainings(monthKey),
      ]);

      final calendarResult = results[0] as Map<String, dynamic>;
      final trainingsList = results[1] as List<Map<String, dynamic>>;

      final List<dynamic> mealDatesRaw = calendarResult['meal_dates'] ?? [];
      final Set<DateTime> meals = {};
      for (var d in mealDatesRaw) {
        try {
          meals.add(DateTime.parse(d));
        } catch (_) {}
      }

      final Map<DateTime, List<Map<String, dynamic>>> eventsMap = {};
      for (final training in trainingsList) {
        try {
          final date = DateTime.parse(training['date']);
          final dateOnly = DateTime(date.year, date.month, date.day);
          if (eventsMap[dateOnly] == null) eventsMap[dateOnly] = [];
          eventsMap[dateOnly]!.add(training);
        } catch (e) {
          debugPrint('Invalid date: $e');
        }
      }

      if (mounted) {
        setState(() {
          _mealDates = meals;
          _currentStreak = (calendarResult['current_streak'] as int?) ?? 0;
          _calculateStreakDates();
          _events = eventsMap;
          final targetDay = _selectedDay ?? _focusedDay;
          _selectedEvents = _getEventsForDay(targetDay);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final dateOnly = DateTime(day.year, day.month, day.day);
    return _events[dateOnly] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedEvents = _getEventsForDay(selectedDay);
      });
    }
  }

  void _onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    final monthKey = DateFormat('yyyy-MM').format(focusedDay);
    if (monthKey != _currentMonthKey) {
      _currentMonthKey = monthKey;
      _fetchCalendarData(monthKey);
    }
  }

  Future<void> _handleSignUp(int trainingId) async {
    try {
      await _api.signupTraining(trainingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вы успешно записаны!'), backgroundColor: AppColors.green),
        );
      }
      await _fetchCalendarData(_currentMonthKey);
      widget.onTrainingChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка записи: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<void> _handleCancel(int trainingId) async {
    try {
      await _api.cancelSignup(trainingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ваша запись отменена.'), backgroundColor: AppColors.neutral700),
        );
      }
      await _fetchCalendarData(_currentMonthKey);
      widget.onTrainingChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отмены: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  /// Открывает ссылку
  Future<void> _launchLink(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось открыть ссылку'), backgroundColor: AppColors.red),
          );
        }
      }
    } catch (e) {
      print("Link launch error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = bottomContentPadding(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: _isLoading
            ? const Skeleton(width: 140, height: 24)
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Календарь'),
            if (_currentStreak > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFFF5722).withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ]),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text('$_currentStreak',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                  ],
                ),
              )
            ]
          ],
        ),
      ),
      body: !widget.hasSubscription
          ? _buildLockedView()
          : _isLoading
          ? _buildSkeletonLoader()
          : ListView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPad),
        children: [
          // --- НОВАЯ КНОПКА AI ТРЕНИРОВКИ (СЧЕТЧИК) ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)], // Индиго градиент
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // Открываем камеру без привязки к тренировке
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AiWorkoutPage(exerciseName: 'Приседания')));
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_front_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'AI Тренировка',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Счетчик приседаний (Камера)',
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // --- КАЛЕНДАРЬ ---
          KiloCard(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: TableCalendar(
              locale: 'ru_RU',
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  final dateOnly = DateTime(day.year, day.month, day.day);
                  if (_streakDates.any((d) => isSameDay(d, dateOnly))) {
                    return Container(
                      margin: const EdgeInsets.all(6.0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFCCBC)),
                      ),
                      child: Text('${day.day}',
                          style: const TextStyle(
                              color: Color(0xFFD84315), fontWeight: FontWeight.bold)),
                    );
                  }
                  if (_mealDates.any((d) => isSameDay(d, dateOnly))) {
                    return Container(
                      margin: const EdgeInsets.all(6.0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text('${day.day}',
                          style: const TextStyle(
                              color: AppColors.green, fontWeight: FontWeight.w600)),
                    );
                  }
                  return null;
                },
                markerBuilder: (context, date, events) {
                  if (events.isEmpty) return null;
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
                    ),
                  );
                },
              ),
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 1,
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              onDaySelected: _onDaySelected,
              onFormatChanged: (format) {
                if (_calendarFormat != format) setState(() => _calendarFormat = format);
              },
              onPageChanged: _onPageChanged,
            ),
          ),

          // --- Легенда ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: AppColors.green.withOpacity(0.2), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('Питание',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.neutral600,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        border: Border.all(color: const Color(0xFFFFCCBC)),
                        shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('Стрик 🔥',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.neutral600,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('Тренировка',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.neutral600,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          // --- Список событий ---
          if (_selectedEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.event_busy_rounded, size: 48, color: AppColors.neutral300),
                    SizedBox(height: 12),
                    Text('Нет тренировок в этот день',
                        style: TextStyle(color: AppColors.neutral500)),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selectedEvents.length,
              itemBuilder: (context, index) {
                final event = _selectedEvents[index];
                return _WorkoutCard(
                  event: event,
                  onSignUp: () => _handleSignUp(event['id']),
                  onCancel: () => _handleCancel(event['id']),
                  onLinkTap: (url) => _launchLink(url),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Skeleton(height: 380, width: double.infinity, radius: 18),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Skeleton(width: 60, height: 12),
              SizedBox(width: 24),
              Skeleton(width: 80, height: 12),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) =>
              const Skeleton(height: 140, width: double.infinity, radius: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fitness_center_rounded, size: 64, color: AppColors.secondary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Онлайн Тренировки',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.neutral900),
            ),
            const SizedBox(height: 12),
            const Text(
              'Доступ к групповым онлайн-тренировкам с профессиональными тренерами открыт только для пользователей Sola Pro.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.neutral600, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const PurchasePage()));
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.secondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Оформить подписку',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// КАРТОЧКА ТРЕНИРОВКИ (Финальная)
class _WorkoutCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onSignUp;
  final VoidCallback onCancel;
  final Function(String) onLinkTap;

  const _WorkoutCard({
    required this.event,
    required this.onSignUp,
    required this.onCancel,
    required this.onLinkTap,
  });

  String? _getYoutubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtube.com')) {
      return uri.queryParameters['v'];
    }
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.firstOrNull;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final String title = event['title'] ?? 'Тренировка';
    final String trainerName = event['trainer']?['name'] ?? 'Тренер';
    final String startTimeStr = event['start_time'] ?? '00:00';
    final String endTimeStr = event['end_time'] ?? '00:00';
    final String meetingLink = event['meeting_link'] ?? '';
    final String dateStr = event['date'] ?? '';

    // Данные о местах
    final int? capacityRaw = event['capacity'];
    final bool isUnlimited = capacityRaw == null || capacityRaw == 0;
    final int capacity = capacityRaw ?? 0;
    final int signups = (event['signups'] as List? ?? []).length;
    final bool isFull = !isUnlimited && (signups >= capacity);

    final bool isSignedUp = event['is_signed_up_by_me'] ?? false;

    // Логика Времени
    bool isLive = false;
    bool isFinished = false;

    try {
      final now = DateTime.now();
      final dateParts = dateStr.split('-');
      final startParts = startTimeStr.split(':');
      final endParts = endTimeStr.split(':');

      final startDt = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(startParts[0]),
        int.parse(startParts[1]),
      );

      final endDt = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(endParts[0]),
        int.parse(endParts[1]),
      );

      // Активна за 15 минут до начала и до конца
      if (now.isAfter(startDt.subtract(const Duration(minutes: 15))) &&
          now.isBefore(endDt)) {
        isLive = true;
      }
      if (now.isAfter(endDt)) {
        isFinished = true;
      }
    } catch (e) {
      print("Date parse error: $e");
    }

    final youtubeId = _getYoutubeId(meetingLink);
    final hasLink = meetingLink.isNotEmpty;

    return KiloCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 1. Заголовок и Статус ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.circle, size: 8, color: Colors.white),
                            SizedBox(width: 4),
                            Text('LIVE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    else if (isFinished)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.neutral200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('ЗАВЕРШЕНО',
                            style: TextStyle(
                                color: AppColors.neutral600,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    if (isSignedUp && !isFinished)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('ВЫ ЗАПИСАНЫ',
                            style: TextStyle(
                                color: AppColors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('$startTimeStr - $endTimeStr • $trainerName',
                    style: const TextStyle(fontSize: 14, color: AppColors.neutral600)),
              ],
            ),
          ),

          // --- 2. ПРЕВЬЮ (Если YouTube) ---
          if (youtubeId != null)
            GestureDetector(
              onTap: () => onLinkTap(meetingLink),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.network(
                    'https://img.youtube.com/vi/$youtubeId/mqdefault.jpg',
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, _, __) => Container(
                      height: 180,
                      color: Colors.black12,
                      child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.black26)),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    height: 180,
                    color: Colors.black.withOpacity(0.2),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)
                      ],
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 32),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // --- 3. КНОПКИ ДЕЙСТВИЯ ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Информация о местах
                if (!isFinished && !isLive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.groups_rounded,
                            size: 16, color: AppColors.neutral500),
                        const SizedBox(width: 8),
                        Text(
                          isUnlimited
                              ? 'Участников: $signups (Места не ограничены)'
                              : 'Места: $signups / $capacity',
                          style: const TextStyle(fontSize: 14, color: AppColors.neutral600),
                        ),
                      ],
                    ),
                  ),

                // Кнопки
                if (isFinished)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: null,
                      child: const Text('Тренировка завершена'),
                    ),
                  )
                else if (isSignedUp)
                  Column(
                    children: [
                      if (isLive && hasLink)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.videocam_rounded),
                            label: const Text('ПОДКЛЮЧИТЬСЯ'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => onLinkTap(meetingLink),
                          ),
                        ),
                      if (isLive && hasLink) const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: onCancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.red,
                            side: BorderSide(color: AppColors.red.withOpacity(0.3)),
                          ),
                          child: const Text('Отменить запись'),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isFull ? null : onSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        isFull ? AppColors.neutral300 : AppColors.primary,
                      ),
                      child: Text(isFull ? 'Нет мест' : 'Записаться'),
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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Для TextInputFormatters
import 'auth_api.dart';
import 'index.dart'; // Для KiloCard, SectionTitle и т.д.
import 'app_theme.dart'; // Для AppColors, kiloInput


class ConfirmAnalysisPage extends StatefulWidget {
  final Map<String, dynamic> initialData;

  final bool isFirstAnalysis;

  const ConfirmAnalysisPage({
    super.key,
    required this.initialData,
    required this.isFirstAnalysis,
  });

  @override
  State<ConfirmAnalysisPage> createState() => _ConfirmAnalysisPageState();
}

class _ConfirmAnalysisPageState extends State<ConfirmAnalysisPage> {
  final _api = AuthApi();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _heightController;
  late final TextEditingController _muscleGoalController;
  late final TextEditingController _fatGoalController;

  bool _isLoading = false;

  // Состояния для "магии" и результатов
  String? _aiComment;
  Map<String, dynamic>? _visualizationData; // "image_current_path", "image_target_path"

  late double _currentWeight;
  late double _currentMuscle;
  late double _currentFat;

  @override
  void initState() {
    super.initState();

    _currentWeight = widget.initialData['weight']?.toDouble() ?? 0.0;
    _currentMuscle = widget.initialData['muscle_mass']?.toDouble() ?? 0.0;
    _currentFat = widget.initialData['fat_mass']?.toDouble() ?? 0.0;

    _heightController = TextEditingController(text: widget.initialData['height']?.toString() ?? '0');
    _muscleGoalController = TextEditingController(text: widget.initialData['muscle_mass_goal']?.toStringAsFixed(1) ?? '0.0');
    _fatGoalController = TextEditingController(text: widget.initialData['fat_mass_goal']?.toStringAsFixed(1) ?? '0.0');
  }

  @override
  void dispose() {
    _heightController.dispose();
    _muscleGoalController.dispose();
    _fatGoalController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final height = double.tryParse(_heightController.text) ?? 0.0;
      final muscleGoal = double.tryParse(_muscleGoalController.text);
      final fatGoal = double.tryParse(_fatGoalController.text);

      final Map<String, dynamic> saveResponse = await _api.confirmBodyAnalysis(
        height: height,
        muscleMassGoal: widget.isFirstAnalysis ? muscleGoal : null,
        fatMassGoal: widget.isFirstAnalysis ? fatGoal : null,
      );

      if (widget.isFirstAnalysis) {
        final Map<String, dynamic> vizData = await _api.runVisualization();
        setState(() {
          _visualizationData = vizData;
          _isLoading = false;
        });
      } else {
        final String? comment = saveResponse['ai_comment'] as String?;
        setState(() {
          _aiComment = comment ?? "Ваш новый замер тела успешно сохранен!";
          _isLoading = false;
        });
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.red),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildPreloader();
    }
    if (_visualizationData != null) {
      return _buildVisualizationResult();
    }
    if (_aiComment != null) {
      return _buildAiCommentResult();
    }
    return _buildConfirmationForm();
  }

  Widget _buildConfirmationForm() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFirstAnalysis ? 'Ваш анализ готов!' : 'Новый замер тела'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
                widget.isFirstAnalysis
                    ? 'Проверьте показатели и установите ваши цели.'
                    : 'Проверьте новые показатели. Они будут сохранены в вашу историю прогресса.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: AppColors.neutral600)
            ),

            const SizedBox(height: 24),

            // Карточки Веса и Роста
            Row(
              children: [
                Expanded(child: _buildMetricCard('⚖️ Вес', _currentWeight, 'кг')),
                const SizedBox(width: 16),
                Expanded(
                  child: KiloCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('📏 Рост', style: TextStyle(color: AppColors.neutral500)),
                        TextFormField(
                          controller: _heightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]+'))],
                          decoration: const InputDecoration(
                            suffixText: 'см',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.neutral800),
                          validator: (v) => (v == null || v.isEmpty || double.tryParse(v) == null) ? '!' : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Показываем блок с целями, только если это первый анализ
            if (widget.isFirstAnalysis) ...[
              const SizedBox(height: 24),
              // ----- ИСПРАВЛЕНИЕ ЗДЕСЬ -----
              const SectionTitle('Ваши цели', padding: EdgeInsets.zero),
              const SizedBox(height: 12),
              _buildGoalCard(
                title: '💪 Мышечная масса',
                controller: _muscleGoalController,
                currentValue: _currentMuscle,
                color: AppColors.green,
              ),
              const SizedBox(height: 16),
              _buildGoalCard(
                title: '🧈 Жировая масса',
                controller: _fatGoalController,
                currentValue: _currentFat,
                color: AppColors.secondary,
              ),
            ],

            const SizedBox(height: 24),
            // ----- И ИСПРАВЛЕНИЕ ЗДЕСЬ -----
            const SectionTitle('Дополнительные показатели', padding: EdgeInsets.zero),
            const SizedBox(height: 12),

            // Доп. метрики
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildMetricCard('📐 ИМТ', widget.initialData['bmi']?.toDouble() ?? 0.0, ''),
                _buildMetricCard('🧬 Возраст тела', widget.initialData['body_age']?.toDouble() ?? 0.0, 'лет'),
                _buildMetricCard('⚡ Базовый обмен', widget.initialData['metabolism']?.toDouble() ?? 0.0, 'ккал'),
              ],
            ),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submitForm,
              child: Text(
                  widget.isFirstAnalysis ? 'Сохранить и увидеть магию ✨' : 'Сохранить новый замер'
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ЭКРАН 2: ПРЕЛОАДЕР (во время "магии")
  Widget _buildPreloader() {
    // Этот UI соответствует #fullscreen-preloader
    return Scaffold(
      backgroundColor: AppColors.pageBackground.withOpacity(0.8),
      body: const Center(
        child: KiloCard(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'AI создает вашу визуализацию...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.neutral800),
              ),
              SizedBox(height: 8),
              Text(
                'Это может занять до минуты.',
                style: TextStyle(fontSize: 14, color: AppColors.neutral600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisualizationResult() {
    final currentImg = _visualizationData!['image_current_path'] as String?;
    final targetImg = _visualizationData!['image_target_path'] as String?;

    final targetWeight = (_currentWeight - (_currentFat - double.parse(_fatGoalController.text)) + (double.parse(_muscleGoalController.text) - _currentMuscle)).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(title: const Text('Ваша трансформация!')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Вот как вы можете выглядить у вашей цели', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: AppColors.neutral600)),
          const SizedBox(height: 24),

          // Карточка "До"
          const Text('Текущая форма', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.neutral500)),
          const SizedBox(height: 8),
          KiloCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (currentImg != null)
                  Image.network('${AuthApi.baseUrl}$currentImg', fit: BoxFit.cover),
                const SizedBox(height: 16),
                _buildResultMetric('⚖️ Вес:', _currentWeight.toStringAsFixed(1), 'кг'),
                _buildResultMetric('💪 Мышцы:', _currentMuscle.toStringAsFixed(1), 'кг'),
                _buildResultMetric('🧈 Жир:', _currentFat.toStringAsFixed(1), 'кг'),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Карточка "После"
          const Text('Целевая форма', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.green)),
          const SizedBox(height: 8),
          KiloCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (targetImg != null)
                  Image.network('${AuthApi.baseUrl}$targetImg', fit: BoxFit.cover),
                const SizedBox(height: 16),
                _buildResultMetric('⚖️ Вес:', targetWeight, 'кг'),
                _buildResultMetric('💪 Мышцы:', _muscleGoalController.text, 'кг', color: AppColors.green),
                _buildResultMetric('🧈 Жир:', _fatGoalController.text, 'кг', color: AppColors.secondary),
              ],
            ),
          ),

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отлично! Вернуться в профиль'),
          ),
        ],
      ),
    );
  }

  Widget _buildAiCommentResult() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Промежуточный итог!'),
        automaticallyImplyLeading: false, // Убираем кнопку "назад"
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Ваш новый замер сохранен, а ИИ-тренер подготовил анализ.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.neutral600),
          ),
          const SizedBox(height: 24),
          // Карточка с комментарием
          KiloCard(
            color: AppColors.primary.withOpacity(0.05),
            borderColor: AppColors.primary.withOpacity(0.2),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Анализ вашего прогресса',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _aiComment!,
                    style: const TextStyle(fontSize: 15, color: AppColors.neutral700, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отлично! Вернуться в профиль'),
          ),
        ],
      ),
    );
  }

  // --- Вспомогательные виджеты ---

  Widget _buildMetricCard(String title, double value, String unit) {
    return KiloCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.neutral500)),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              text: value.toStringAsFixed(unit.isEmpty ? 1 : 0),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.neutral800),
              children: [
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(fontSize: 16, color: AppColors.neutral500, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard({
    required String title,
    required TextEditingController controller,
    required double currentValue,
    required Color color,
  }) {
    return KiloCard(
      padding: const EdgeInsets.all(16),
      color: color.withOpacity(0.05),
      borderColor: color.withOpacity(0.2),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    text: 'Сейчас: ',
                    style: const TextStyle(color: AppColors.neutral600, fontSize: 13),
                    children: [
                      TextSpan(
                        text: '${currentValue.toStringAsFixed(1)} кг',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.neutral800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]+'))],
              decoration: kiloInput('Ваша цель (кг)').copyWith(
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: color, width: 2)
                ),
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
              validator: (v) => (v == null || v.isEmpty || double.tryParse(v) == null) ? '!' : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultMetric(String label, String value, String unit, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: AppColors.neutral600)),
          Text.rich(
            TextSpan(
                text: value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color ?? AppColors.neutral800),
                children: [
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(fontSize: 14, color: AppColors.neutral500, fontWeight: FontWeight.w500),
                  ),
                ]
            ),
          ),
        ],
      ),
    );
  }
}
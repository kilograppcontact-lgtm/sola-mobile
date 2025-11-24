import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'auth_api.dart';
import 'app_theme.dart';

/* ------------------------- SCAN SHEET (SAFE & FIXED) ------------------------- */

class ScanSheet extends StatefulWidget {
  final String defaultMealType;

  const ScanSheet({
    super.key,
    required this.defaultMealType,
  });

  @override
  State<ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<ScanSheet> with WidgetsBindingObserver {
  final _api = AuthApi();
  CameraController? _controller;
  Future<void>? _initFuture;
  bool _busy = false;

  XFile? _frozenPicture;
  Map<String, dynamic>? _analysisResult;
  String? _analysisError;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Запускаем инициализацию после построения первого кадра
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _initFuture = _initCamera();
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Пытаемся освободить, если вдруг еще жив
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // Приложение уходит в фон (или шторка уведомлений)
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (cameraController != null && cameraController.value.isInitialized) {
        // 1. Сначала отвязываем контроллер от UI, чтобы не было обращений к мертвой ссылке
        if (mounted) {
          setState(() {
            _controller = null;
          });
        }
        // 2. Асинхронно освобождаем ресурсы
        cameraController.dispose();
      }
    }
    // Приложение возвращается
    else if (state == AppLifecycleState.resumed) {
      // Если мы на экране камеры (не на результате) и контроллера нет — создаем
      if (_frozenPicture == null) {
        _initCamera();
      }
    }
  }

  Future<void> _closeSheet() async {
    if (!mounted) return;

    // Блокируем UI
    setState(() {
      _busy = true;
    });

    // Сохраняем ссылку локально и зануляем глобально
    final controllerToDispose = _controller;
    _controller = null;

    if (controllerToDispose != null) {
      try {
        await controllerToDispose.dispose();
      } catch (e) {
        debugPrint("Ошибка при dispose() камеры: $e");
      }
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _initCamera() async {
    // Если контроллер уже есть или идет процесс — выходим
    if (_controller != null || _busy) return;

    if (mounted) setState(() => _busy = true);

    try {
      final cams = await availableCameras();
      // Ищем заднюю камеру, или берем первую попавшуюся
      final back = cams.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );

      final ctrl = CameraController(
          back,
          ResolutionPreset.medium,
          imageFormatGroup: ImageFormatGroup.yuv420,
          enableAudio: false
      );

      await ctrl.initialize();

      if (!mounted) {
        // Если виджет умер пока мы инициализировали — убиваем контроллер
        await ctrl.dispose();
        return;
      }

      // Успех
      setState(() => _controller = ctrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка камеры: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _takePictureAndAnalyze() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _busy) return;

    try {
      setState(() => _busy = true);

      // Делаем снимок
      final file = await ctrl.takePicture();

      setState(() {
        _frozenPicture = file;
        _isAnalyzing = true;
        _analysisError = null;
        _busy = false;
        // Камеру на паузу не ставим, просто перекрываем UI
      });

      try {
        final result = await _api.analyzeMealPhoto(File(file.path));
        if (mounted) {
          setState(() {
            _analysisResult = result;
            _isAnalyzing = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _analysisError = e.toString();
            _isAnalyzing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось сделать снимок: $e')));
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _handleSave(String mealType, Map<String, dynamic> analysisData) async {
    setState(() => _busy = true);
    try {
      await _api.logMeal(
        mealType: mealType,
        name: analysisData['name']?.toString() ?? 'Блюдо',
        calories: (analysisData['calories'] as num?)?.toInt() ?? 0,
        protein: (analysisData['protein'] as num?)?.toDouble() ?? 0.0,
        fat: (analysisData['fat'] as num?)?.toDouble() ?? 0.0,
        carbs: (analysisData['carbs'] as num?)?.toDouble() ?? 0.0,
        analysis: analysisData['analysis']?.toString(),
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _resetScanner() {
    setState(() {
      _frozenPicture = null;
      _analysisResult = null;
      _isAnalyzing = false;
      _analysisError = null;
    });
    // Если контроллер был уничтожен (например, уходили в фон), инициализируем заново
    if (_controller == null) {
      _initFuture = _initCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).padding;
    return Column(
      children: [
        SizedBox(height: safe.top),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              IconButton(
                  onPressed: _busy ? null : () {
                    if (_frozenPicture != null) {
                      _resetScanner();
                    } else {
                      _closeSheet();
                    }
                  },
                  icon: Icon(_frozenPicture != null ? Icons.arrow_back_rounded : Icons.close_rounded, color: Colors.white)),
              const SizedBox(width: 8),
              Text(
                _frozenPicture == null ? 'Сканирование блюда' : 'Результат анализа',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const Spacer(),
              // Фонарик только если камера активна и мы не на экране результата
              if (_frozenPicture == null && _controller != null && _controller!.value.isInitialized)
                IconButton(
                    onPressed: () {
                      try {
                        final mode = _controller!.value.flashMode == FlashMode.torch ? FlashMode.off : FlashMode.torch;
                        _controller!.setFlashMode(mode);
                        setState(() {}); // Обновляем иконку
                      } catch (_) {}
                    },
                    icon: Icon(
                        _controller!.value.flashMode == FlashMode.torch ? Icons.flashlight_off_rounded : Icons.flashlight_on_rounded,
                        color: Colors.white
                    ),
                    tooltip: 'Фонарик'
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: _initFuture,
            builder: (context, snapshot) {
              // Если инициализация еще идет или контроллера нет
              if (_controller == null || !_controller!.value.isInitialized) {
                // Если есть замороженная картинка - показываем её, иначе лоадер
                if (_frozenPicture != null) return _buildAnalysisView();
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _frozenPicture == null
                    ? _buildCameraView()
                    : _buildAnalysisView(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCameraView() {
    // Доп. защита: если контроллер null, не рендерим Preview
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Stack(
      key: const ValueKey('camera_view'),
      fit: StackFit.expand,
      children: [
        Container(
          color: Colors.black,
          width: double.infinity,
          height: double.infinity,
          child: CameraPreview(_controller!),
        ),
        const IgnorePointer(child: CustomPaint(painter: _OverlayPainter())),
        _buildShutterButton(),
      ],
    );
  }

  Widget _buildAnalysisView() {
    if (_frozenPicture == null) return const SizedBox.shrink();

    return Stack(
      key: const ValueKey('analysis_view'),
      fit: StackFit.expand,
      children: [
        Image.file(File(_frozenPicture!.path), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.black.withOpacity(0.5)),
        ),
        _AnalysisResultOverlay(
          isAnalyzing: _isAnalyzing,
          analysisResult: _analysisResult,
          error: _analysisError,
          defaultMealType: widget.defaultMealType,
          isLoading: _busy,
          onSave: (selectedMealType) {
            if (_analysisResult != null) {
              _handleSave(selectedMealType, _analysisResult!);
            }
          },
          onCancel: _resetScanner,
        ),
      ],
    );
  }

  Widget _buildShutterButton() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).padding.bottom),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _busy || _controller == null || !_controller!.value.isInitialized
                    ? null
                    : _takePictureAndAnalyze,
                icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.camera_alt_rounded),
                label: Text(_busy ? 'Обработка...' : 'Сканировать'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisResultOverlay extends StatefulWidget {
  final bool isAnalyzing;
  final Map<String, dynamic>? analysisResult;
  final String? error;
  final String defaultMealType;
  final bool isLoading;
  final Function(String mealType) onSave;
  final VoidCallback onCancel;

  const _AnalysisResultOverlay({
    required this.isAnalyzing,
    required this.analysisResult,
    required this.error,
    required this.defaultMealType,
    required this.isLoading,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_AnalysisResultOverlay> createState() => _AnalysisResultOverlayState();
}

class _AnalysisResultOverlayState extends State<_AnalysisResultOverlay> with SingleTickerProviderStateMixin {
  late String _selectedMealType;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  final Map<String, String> _mealTypes = const {
    'breakfast': 'Завтрак',
    'lunch': 'Обед',
    'dinner': 'Ужин',
    'snack': 'Перекус',
  };

  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.defaultMealType;
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic);
    _scaleAnimation = CurvedAnimation(parent: _animationController, curve: Curves.elasticOut);
    Timer(const Duration(milliseconds: 100), () {
      if (mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.1),
              _buildCentralContent(),
              const SizedBox(height: 24),
              _buildActionButtons(),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCentralContent() {
    if (widget.isAnalyzing) {
      return KiloCard(
        child: Column(
          children: [
            const Skeleton(height: 40, width: double.infinity, radius: 0),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  const Skeleton(height: 36, width: 120, radius: 18),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      Skeleton(height: 40, width: 60, radius: 8),
                      Skeleton(height: 40, width: 60, radius: 8),
                      Skeleton(height: 40, width: 60, radius: 8),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Skeleton(height: 16, width: double.infinity, radius: 4),
                  const SizedBox(height: 8),
                  const Skeleton(height: 16, width: 180, radius: 4),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (widget.error != null) {
      return KiloCard(
        color: AppColors.red.withOpacity(0.1),
        borderColor: AppColors.red.withOpacity(0.3),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: const [
            Icon(Icons.error_outline_rounded, color: AppColors.red, size: 56),
            SizedBox(height: 16),
            Text('Ошибка анализа', style: TextStyle(color: AppColors.neutral900, fontSize: 20, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text('Не удалось распознать блюдо. Попробуйте фото с лучшим освещением или другим ракурсом.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.neutral600, fontSize: 14)),
          ],
        ),
      );
    }
    if (widget.analysisResult != null) {
      final data = widget.analysisResult!;
      final name = data['name']?.toString() ?? 'Блюдо';
      final calories = data['calories']?.toString() ?? '0';
      final protein = data['protein']?.toStringAsFixed(1) ?? '0.0';
      final fat = data['fat']?.toStringAsFixed(1) ?? '0.0';
      final carbs = data['carbs']?.toStringAsFixed(1) ?? '0.0';
      final String gptAnalysis = data['analysis']?.toString() ?? 'Анализ не предоставлен.';
      final String gptVerdict = data['verdict']?.toString() ?? 'Вердикт не предоставлен.';

      return KiloCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                children: [
                  Text(name, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.neutral900, fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  Text('$calories ккал', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.primary, fontSize: 36, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.neutral200),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMacroStat('Белки', protein, AppColors.primary),
                  _buildMacroStat('Жиры', fat, AppColors.secondary),
                  _buildMacroStat('Углеводы', carbs, AppColors.neutral500),
                ],
              ),
            ),
            Container(
              color: AppColors.neutral50,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Анализ Sola AI:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.neutral700)),
                  const SizedBox(height: 8),
                  Text(gptAnalysis, style: const TextStyle(color: AppColors.neutral600, height: 1.4)),
                  const SizedBox(height: 12),
                  const Text('Вердикт:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.neutral700)),
                  const SizedBox(height: 8),
                  Text(gptVerdict, style: const TextStyle(color: AppColors.neutral600, height: 1.4, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.neutral200),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Сохранить как:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.neutral700)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ToggleButtons(
                      isSelected: _mealTypes.keys.map((key) => key == _selectedMealType).toList(),
                      onPressed: (index) {
                        setState(() {
                          _selectedMealType = _mealTypes.keys.elementAt(index);
                        });
                      },
                      borderRadius: BorderRadius.circular(12.0),
                      selectedBorderColor: AppColors.primary,
                      selectedColor: Colors.white,
                      fillColor: AppColors.primary,
                      color: AppColors.primary,
                      constraints: const BoxConstraints(minHeight: 40.0),
                      children: _mealTypes.values.map((label) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Container();
  }

  Widget _buildActionButtons() {
    if (widget.isAnalyzing || widget.error != null) {
      if (widget.error != null) {
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.onCancel,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Попробовать снова'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: widget.isLoading ? null : widget.onCancel,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Отмена'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: widget.isLoading ? null : () => widget.onSave(_selectedMealType),
            icon: widget.isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded),
            label: Text(widget.isLoading ? 'Сохраняю...' : 'Сохранить'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMacroStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.neutral600, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text('${value}г', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withOpacity(0.45);
    final clear = Paint()..blendMode = BlendMode.clear;
    final stroke = Paint()
      ..color = Colors.white.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final width = size.width * 0.8;
    final height = width;
    final left = (size.width - width) / 2;
    final top = (size.height - height) / 2 - 24;
    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, width, height), const Radius.circular(16));
    final layerBounds = Offset.zero & size;
    canvas.saveLayer(layerBounds, Paint());
    canvas.drawRect(layerBounds, overlay);
    canvas.drawRRect(rrect, clear);
    canvas.restore();
    canvas.drawRRect(rrect, stroke);
    final mark = Paint()..color = Colors.white..strokeWidth = 4..style = PaintingStyle.stroke;
    const len = 18.0;
    canvas.drawLine(Offset(left, top), Offset(left + len, top), mark);
    canvas.drawLine(Offset(left, top), Offset(left, top + len), mark);
    canvas.drawLine(Offset(left + width, top), Offset(left + width - len, top), mark);
    canvas.drawLine(Offset(left + width, top), Offset(left + width, top + len), mark);
    canvas.drawLine(Offset(left, top + height), Offset(left + len, top + height), mark);
    canvas.drawLine(Offset(left, top + height), Offset(left, top + height - len), mark);
    canvas.drawLine(Offset(left + width, top + height), Offset(left + width - len, top + height), mark);
    canvas.drawLine(Offset(left + width, top + height), Offset(left + width, top + height - len), mark);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
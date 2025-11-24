import 'dart:async';
import 'dart:ui' show Shader;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'auth_api.dart';
import 'ai_instructions_page.dart';
import 'app_theme.dart';
import 'purchase_page.dart';

/* ------------------------- НОВАЯ СТРАНИЦА: SOLA AI (ЧАТ) ------------------------- */
class SolaAiPage extends StatefulWidget {
  final bool hasSubscription;

  const SolaAiPage({
    super.key,
    this.hasSubscription = false,
  });

  @override
  State<SolaAiPage> createState() => _SolaAiPageState();
}

class _SolaAiPageState extends State<SolaAiPage> with TickerProviderStateMixin {
  final _api = AuthApi();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  // --- НОВОЕ: FocusNode для клавиатуры ---
  final _focusNode = FocusNode();

  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false; // true, когда ждем ответ от API

  // Определение ролей
  static const String _roleUser = 'user';
  static const String _roleAi = 'ai';
  static const String _roleError = 'error';
  static const String _roleAiThinking = 'ai_thinking';

  @override
  void initState() {
    super.initState();
    // Чат всегда начинается только с приветственного сообщения.
    _messages.add({
      'role': _roleAi,
      'content': 'Привет, Sola на связи, чем могу вам помочь? 😊'
    });

    // --- НОВОЕ: Автоматически открываем клавиатуру при входе ---
    // (Небольшая задержка, чтобы страница успела построиться)
    Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }


  /// Отправка быстрого ответа
  void _sendQuickReply(String text) {
    if (_isLoading) return;
    _controller.text = text;
    _sendMessage();
  }

  /// Отправка сообщения
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    final userMessage = {'role': _roleUser, 'content': text};
    final thinkingMessage = {'role': _roleAiThinking};

    setState(() {
      _messages.insert(0, userMessage);
      _messages.insert(0, thinkingMessage); // Скелетон будет на 0-й позиции
      _isLoading = true;
    });

    _controller.clear();
    _scrollToBottom(); // Скроллим в "низ" (т.е. к 0-му индексу)

    try {
      final aiReply = await _api.sendAiChatMessage(text);

      setState(() {
        _messages.removeAt(0);
        _messages.insert(0, aiReply);
      });

    } catch (e) {
      setState(() {
        _messages.removeAt(0); // Убираем скелетон
        _messages.insert(0, { // Добавляем ошибку
          'role': _roleError,
          'content': 'Ошибка ответа AI: $e'
        });
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    // При reverse: true, maxScrollExtent - это "верх" чата,
    // а "низ" (новые сообщения) находится в 0.0
    Timer(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose(); // --- НОВОЕ: Очищаем FocusNode ---
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // super.build(context); // <-- Больше не нужно
    final bool isInputDisabled = _isLoading;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        centerTitle: true,
        // --- НОВОЕ: Кнопка "Назад" ---
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.neutral500),
          onPressed: () => Navigator.pop(context),
        ),
        // ---
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: AppColors.gradientPrimary,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Text(
            'Sola AI',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: AppColors.neutral500),
            onPressed: () {
              // Переход на страницу инструкций
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiInstructionsPage()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      // --- НОВОЕ: Оборачиваем в GestureDetector для скрытия клавиатуры ---
      body: !widget.hasSubscription
          ? _buildLockedView() // <-- ПОКАЗЫВАЕМ ЗАГЛУШКУ
          : GestureDetector(
        onTap: () => _focusNode.unfocus(),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                reverse: true,
                // ---
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final role = msg['role'] ?? _roleAi;
                  final content = msg['content']?.toString() ?? '...';

                  Widget bubble;
                  switch (role) {
                    case _roleUser:
                      bubble = _UserMessageBubble(content: content);
                      break;
                    case _roleError:
                      bubble = _AiMessageBubble(content: content, isError: true);
                      break;
                    case _roleAiThinking:
                      bubble = const _SkeletonMessageBubble();
                      break;
                    case _roleAi:
                    default:
                      bubble = _AiMessageBubble(content: content);
                      break;
                  }

                  // Анимация остается
                  return _AnimatedMessageBubble(
                    key: ValueKey('$role $index'),
                    child: bubble,
                  );
                },
              ),
            ),
            _buildQuickReplies(isInputDisabled),
            _buildTextInput(isInputDisabled),
          ],
        ),
      ),
    );
  }

  /// Экран-заглушка для пользователей без подписки
  Widget _buildLockedView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 64, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sola AI Coach',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.neutral900),
          ),
          const SizedBox(height: 12),
          const Text(
            'Ваш персональный AI-тренер и диетолог доступен в подписке Sola Pro. Получите персональные советы, рецепты и мотивацию 24/7.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.neutral600, height: 1.5),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchasePage()));
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Разблокировать Sola AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReplies(bool isDisabled) {
    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _QuickReplyButton(
              text: 'Какая у меня сейчас диета?',
              icon: Icons.restaurant_menu_rounded,
              onPressed: isDisabled ? null : () => _sendQuickReply('Какая у меня сейчас диета?'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickReplyButton(
              text: 'Как ты оценишь мой прогресс?',
              icon: Icons.trending_up_rounded,
              onPressed: isDisabled ? null : () => _sendQuickReply('Как ты оценишь мой прогресс?'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput(bool isDisabled) {
    return Container(
      // Отступ для клавиатуры (viewInsets) обрабатывается SafeArea ниже
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: AppColors.neutral200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                // --- НОВОЕ: Привязываем FocusNode ---
                focusNode: _focusNode,
                // ---
                enabled: !isDisabled,
                decoration: kiloInput('Спросите Sola AI...').copyWith(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: isDisabled ? null : _sendMessage,
              icon: isDisabled
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                fixedSize: const Size(54, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _QuickReplyButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;

  const _QuickReplyButton({required this.text, required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.neutral700,
        side: const BorderSide(color: AppColors.neutral200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _AnimatedMessageBubble extends StatefulWidget {
  final Widget child;
  const _AnimatedMessageBubble({required this.child, super.key});

  @override
  State<_AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<_AnimatedMessageBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween(begin: const Offset(0.0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}


class _SkeletonMessageBubble extends StatefulWidget {
  const _SkeletonMessageBubble();

  @override
  State<_SkeletonMessageBubble> createState() => _SkeletonMessageBubbleState();
}

class _SkeletonMessageBubbleState extends State<_SkeletonMessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _animation = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, right: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.neutral100,
            borderRadius: BorderRadius.circular(20).copyWith(
              bottomLeft: const Radius.circular(6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 150,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.neutral300.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 100,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.neutral300.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserMessageBubble extends StatelessWidget {
  final String content;
  const _UserMessageBubble({required this.content});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: const Radius.circular(6),
          ),
        ),
        child: MarkdownBody(
          data: content,
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
            strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _AiMessageBubble extends StatelessWidget {
  final String content;
  final bool isLoading;
  final bool isError;

  const _AiMessageBubble({
    required this.content,
    this.isLoading = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.red : AppColors.neutral100;
    final textColor = isError ? Colors.white : AppColors.neutral800;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomLeft: const Radius.circular(6),
          ),
        ),
        child: MarkdownBody(
          data: content,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(color: textColor, fontSize: 15, height: 1.4),
            strong: TextStyle(color: textColor, fontWeight: FontWeight.w900),
            em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
            listBullet: TextStyle(color: textColor, fontSize: 15, height: 1.4),
          ),
        ),
      ),
    );
  }
}
// lib/login.dart
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart'; // <-- ДОБАВЛЕНО
import 'index.dart';
import 'app_theme.dart';
import 'auth_api.dart';
import 'package:dio/dio.dart';

// 1. ПЕРЕИМЕНОВАНО
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

// 2. ПЕРЕИМЕНОВАНО
class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _api = AuthApi();
  final _pageController = PageController();

  // --- Контроллеры и ключи ---
  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(); // Имя будет введено
  final _regPasswordController = TextEditingController();
  final _dobController = TextEditingController();

  File? _avatarFile;
  bool _faceConsent = false;
  bool _termsConsent = false;
  String _registerError = ''; // Отдельная ошибка для регистрации

  late final AnimationController _shakeController;

  // --- Состояние ---
  bool _isEmailLoading = false;
  bool _isLoggingIn = false;
  bool _isRegistering = false;
  Map<String, dynamic>? _fetchedUserData;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    _nameController.dispose();
    _regPasswordController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  /// Анимированный переход к следующей странице
  void _goToPage(int page) {
    FocusScope.of(context).unfocus();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  /// Запускает анимацию "встряхивания"
  void _triggerShakeAnimation() {
    _shakeController.forward(from: 0.0);
  }

  /// Шаг 1: Нажата кнопка "Начать" на первом экране
  void _onShowLogin() {
    _goToPage(1);
  }

  /// Шаг 3: Нажата кнопка "Продолжить" с email
  Future<void> _onEmailContinue() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() {
      _isEmailLoading = true;
      _errorMessage = '';
    });

    try {
      final email = _emailController.text.trim();
      final userData = await _api.checkUserEmail(email);

      // Пользователь НАЙДЕН - переход на экран пароля
      setState(() {
        _fetchedUserData = userData;
        _isEmailLoading = false;
      });

      _goToPage(2); // Переход на экран ВХОДА (с паролем)
    } on DioException catch (e) {
      final error = e.response?.data?['error']?.toString() ?? 'UNKNOWN_ERROR';

      if (error == 'USER_NOT_FOUND') {
        // Пользователь НЕ НАЙДЕН - переход на экран РЕГИСТРАЦИИ (Шаг 1: Имя)
        setState(() {
          _isEmailLoading = false;
          _errorMessage = '';
          _registerError = '';
          // Сбрасываем все поля регистрации
          _nameController.text = '';
          _regPasswordController.text = '';
          _dobController.text = '';
          _avatarFile = null;
          _faceConsent = false;
          _termsConsent = false;
        });
        _goToPage(3);
      } else {
        // ... (обработка других ошибок)
        setState(() {
          _isEmailLoading = false;
          _errorMessage = 'Ошибка: $e';
        });
      }
    } catch (e) {
      // ... (обработка других ошибок)
      setState(() {
        _isEmailLoading = false;
        _errorMessage = 'Неизвестная ошибка: $e';
      });
    }
  }

  /// Шаг 4: Нажата кнопка "Войти" с паролем
  Future<void> _onPasswordLogin() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() {
      _isLoggingIn = true;
      _errorMessage = '';
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      await _api.login(email, password);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthCheckPage()),
      );
    } on DioException catch (e) {
      // ... (обработка ошибок)
      setState(() {
        _isLoggingIn = false;
        _errorMessage = e.response?.data?['error']?.toString() ?? 'Ошибка входа';
      });
    } catch (e) {
      // ... (обработка ошибок)
      setState(() {
        _isLoggingIn = false;
        _errorMessage = 'Неизвестная ошибка: $e';
      });
    }
  }

  /// Шаг 5: Нажата кнопка "Войти с Google"
  Future<void> _onGoogleLogin() async {
    try {
      final GoogleSignIn _googleSignIn = GoogleSignIn(
        serverClientId: '443774867929-9cufg6glc1utanp6vsa96cuevu2tbdfe.apps.googleusercontent.com',
      );
      // 1. Запускаем нативный флоу входа
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // Пользователь отменил вход
        return;
      }

      // 2. Получаем токены (idToken и accessToken)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Не удалось получить ID Token от Google');
      }

      setState(() => _isLoggingIn = true);

      // 3. Отправляем токен на наш бэкенд
      await _api.loginWithGoogle(idToken);

      if (!mounted) return;

      // 4. Успех — переходим на проверку (она сама решит, пускать в профиль или на онбординг)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthCheckPage()),
      );

    } catch (e) {
      setState(() {
        _isLoggingIn = false;
        _errorMessage = 'Ошибка входа через Google: $e';
      });
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 600,
    );
    if (image != null) {
      setState(() {
        _avatarFile = File(image.path);
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  /// Регистрация (ПОЛНОСТЬЮ ПЕРЕДЕЛАНА)
  Future<void> _onRegister() async {
    // 1. Валидируем последнюю форму (соглашения)
    if (!_registerFormKey.currentState!.validate()) {
      _triggerShakeAnimation();
      return;
    }

    // 2. Дополнительно валидируем остальные данные
    if (_nameController.text.trim().isEmpty) {
      _goToPage(3); // На экран имени
      setState(() => _registerError = 'Пожалуйста, введите ваше имя');
      return;
    }
    if (_regPasswordController.text.length < 6) {
      _goToPage(4); // На экран пароля
      setState(() => _registerError = 'Пароль должен быть минимум 6 символов');
      return;
    }
    if (_dobController.text.isEmpty) {
      _goToPage(5); // На экран ДР
      setState(() => _registerError = 'Пожалуйста, выберите дату рождения');
      return;
    }
    if (_avatarFile == null) {
      _goToPage(6); // На экран аватара
      setState(() => _registerError = 'Пожалуйста, загрузите ваш аватар');
      return;
    }

    setState(() {
      _isRegistering = true;
      _registerError = '';
    });

    try {
      await _api.registerV2(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _regPasswordController.text,
        dateOfBirth: _dobController.text,
        avatar: _avatarFile!,
        faceConsent: _faceConsent,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthCheckPage()),
      );
    } on DioException catch (e) {
      // ... (обработка ошибок)
      setState(() {
        _isRegistering = false;
        _registerError = e.message ?? 'Ошибка регистрации';
      });
    } catch (e) {
      // ... (обработка ошибок)
      setState(() {
        _isRegistering = false;
        _registerError = 'Неизвестная ошибка: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildWelcomeScreen(), // 0
            _buildEmailScreen(), // 1
            _buildPasswordScreen(), // 2
            _buildRegisterNameScreen(), //
            _buildRegisterPasswordScreen(),
            _buildRegisterDobScreen(),
            _buildRegisterAvatarScreen(),
            _buildRegisterConsentsScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.pageBackground,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            clipBehavior: Clip.hardEdge,
            alignment: Alignment.center,
            child: Transform.scale(
              scale: 1.15,
              child: Image.asset(
                'assets/sola_visualization.png', // Убедитесь, что этот ассет есть
              ),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Добро пожаловать в Sola',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.neutral900,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ваш помощник для здоровой жизни без лишних трудностей',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.neutral600,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _onShowLogin,
                    child: const Text('Начать'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _onGoogleLogin,
                    icon: Image.asset('assets/google_logo.png', // Убедитесь, что этот ассет есть
                        height: 20, width: 20),
                    label: const Text('Войти через Google'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.neutral700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildEmailScreen() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          final double offset =
              math.sin(_shakeController.value * math.pi * 6.0) * 12.0;
          return Transform.translate(
            offset: Offset(offset, 0),
            child: child,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.neutral500),
              onPressed: () => _goToPage(0),
            ),
            const SizedBox(height: 16),
            const Text(
              'Вход или Регистрация',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.neutral900,
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _emailFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Email',
                      style: TextStyle(
                          color: AppColors.neutral600,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    decoration: kiloInput('you@example.com'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Введите email';
                      final ok =
                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
                      if (!ok) return 'Некорректный email';
                      return null;
                    },
                    onFieldSubmitted: (_) => _onEmailContinue(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isEmailLoading ? null : _onEmailContinue,
                child: _isEmailLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 3, color: Colors.white),
                )
                    : const Text('Продолжить'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(child: Divider(color: AppColors.neutral200)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text('ИЛИ',
                      style: TextStyle(
                          color: AppColors.neutral400,
                          fontWeight: FontWeight.w600)),
                ),
                Expanded(child: Divider(color: AppColors.neutral200)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _onGoogleLogin,
                icon: Image.asset('assets/google_logo.png',
                    height: 20, width: 20),
                label: const Text('Войти с Google'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.neutral700,
                ),
              ),
            ),
            const Spacer(),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: Center(
                child: _errorMessage.isNotEmpty
                    ? Text(_errorMessage,
                    style: const TextStyle(
                        color: AppColors.red, fontWeight: FontWeight.w600))
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordScreen() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.neutral500),
            onPressed: () {
              setState(() => _errorMessage = '');
              _goToPage(1);
            },
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _shakeController,
            builder: (context, child) {
              final double offset =
                  math.sin(_shakeController.value * math.pi * 6.0) * 12.0;
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: _buildPasswordForm(),
          ),
          const Spacer(),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: Center(
              child: _errorMessage.isNotEmpty
                  ? Text(_errorMessage,
                  style: const TextStyle(
                      color: AppColors.red, fontWeight: FontWeight.w600))
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordForm() {
    final String avatarFilename = _fetchedUserData?['avatar_filename'] ?? '';
    final String userName = _fetchedUserData?['name'] ?? 'Пользователь';
    final String placeholder =
    (userName.isNotEmpty ? userName[0] : 'U').toUpperCase();

    return Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: double.infinity),
        CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.neutral100,
          child: avatarFilename.isNotEmpty
              ? ClipOval(
            child: Image.network(
              '${AuthApi.baseUrl}/files/$avatarFilename',
              fit: BoxFit.cover,
              width: 80,
              height: 80,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Skeleton(width: 80, height: 80, radius: 40);
              },
              errorBuilder: (context, _, __) => Text(placeholder,
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
            ),
          )
              : Text(placeholder,
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
        ),
        const SizedBox(height: 16),
        Text(
          'С возвращением, $userName!',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.neutral900,
          ),
        ),
        const SizedBox(height: 32),
        Form(
          key: _passwordFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Пароль',
                  style: TextStyle(
                      color: AppColors.neutral600,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                autofocus: true,
                decoration: kiloInput('Ваш пароль'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите пароль';
                  return null;
                },
                onFieldSubmitted: (_) => _onPasswordLogin(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoggingIn ? null : _onPasswordLogin,
            child: _isLoggingIn
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 3, color: Colors.white),
            )
                : const Text('Войти'),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Функция "Забыл пароль" еще не реализована.')),
              );
            },
            child: const Text('Забыл пароль?'),
          ),
        ),
      ],
    );
  }


  // --- ЭКРАН 3: Ввод Имени (Регистрация) ---
  Widget _buildRegisterNameScreen() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.neutral500),
            onPressed: () => _goToPage(1), // Назад на Email
          ),
          const SizedBox(height: 16),
          ListView(
            shrinkWrap: true,
            children: [
              const Text(
                'Давайте знакомиться! 😊',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.neutral900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Кажется, вы у нас впервые. Как вас зовут?',
                style: TextStyle(fontSize: 16, color: AppColors.neutral600),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                decoration: kiloInput('Ваше имя'),
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                onFieldSubmitted: (_) => _goToPage(4),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_nameController.text.trim().isEmpty) {
                    setState(() => _registerError = 'Пожалуйста, введите ваше имя');
                    _triggerShakeAnimation();
                  } else {
                    setState(() => _registerError = '');
                    _goToPage(4);
                  }
                },
                child: const Text('Продолжить'),
              ),
            ],
          ),
          const Spacer(),
          _buildRegisterError(),
        ],
      ),
    );
  }

  Widget _buildRegisterPasswordScreen() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.neutral500),
            onPressed: () => _goToPage(3), // Назад на Имя
          ),
          const SizedBox(height: 16),
          ListView(
            shrinkWrap: true,
            children: [
              Text(
                'Отлично, ${_nameController.text.split(' ')[0]}!',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.neutral900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Теперь придумайте пароль для входа в ваш аккаунт.',
                style: TextStyle(fontSize: 16, color: AppColors.neutral600),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _regPasswordController,
                obscureText: true,
                decoration: kiloInput('Пароль (мин. 6 символов)'),
                autofocus: true,
                onFieldSubmitted: (_) => _goToPage(5),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_regPasswordController.text.length < 6) {
                    setState(() => _registerError =
                    'Пароль должен быть минимум 6 символов');
                    _triggerShakeAnimation();
                  } else {
                    setState(() => _registerError = '');
                    _goToPage(5);
                  }
                },
                child: const Text('Продолжить'),
              ),
            ],
          ),
          const Spacer(),
          _buildRegisterError(),
        ],
      ),
    );
  }

  Widget _buildRegisterDobScreen() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.neutral500),
            onPressed: () => _goToPage(4), // Назад на Пароль
          ),
          const SizedBox(height: 16),
          ListView(
            shrinkWrap: true,
            children: [
              const Text(
                'Укажите ваш возраст',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.neutral900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Это нужно для более точных расчетов вашей нормы калорий и ИМТ.',
                style: TextStyle(fontSize: 16, color: AppColors.neutral600),
              ),
              const SizedBox(height: 32),
              InkWell(
                onTap: () async {
                  await _selectDate(context);
                  // Авто-переход при выборе
                  if (_dobController.text.isNotEmpty) {
                    setState(() => _registerError = '');
                    _goToPage(6);
                  }
                },
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _dobController,
                    decoration: kiloInput('Дата рождения').copyWith(
                      suffixIcon: const Icon(Icons.calendar_today_rounded),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_dobController.text.isEmpty) {
                    setState(
                            () => _registerError = 'Пожалуйста, выберите дату рождения');
                    _triggerShakeAnimation();
                  } else {
                    setState(() => _registerError = '');
                    _goToPage(6);
                  }
                },
                child: const Text('Продолжить'),
              ),
            ],
          ),
          const Spacer(),
          _buildRegisterError(),
        ],
      ),
    );
  }

  Widget _buildRegisterAvatarScreen() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.neutral500),
            onPressed: () => _goToPage(5), // Назад на ДР
          ),
          const SizedBox(height: 16),
          ListView(
            shrinkWrap: true,
            children: [
              const Text(
                'Загрузите ваш аватар',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.neutral900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Это поможет вашему AI-тренеру и команде обращаться к вам.',
                style: TextStyle(fontSize: 16, color: AppColors.neutral600),
              ),
              const SizedBox(height: 32),
              Center(
                child: KiloCard(
                  padding: EdgeInsets.zero,
                  child: InkWell(
                    onTap: () async {
                      await _pickAvatar();
                      if (_avatarFile != null) {
                        setState(() => _registerError = '');
                        _goToPage(7); // Авто-переход
                      }
                    },
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: _avatarFile != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.file(_avatarFile!, fit: BoxFit.cover),
                      )
                          : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_rounded,
                              size: 60, color: AppColors.neutral400),
                          SizedBox(height: 16),
                          Text('Нажмите для загрузки',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.neutral600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  if (_avatarFile == null) {
                    setState(() => _registerError = 'Пожалуйста, загрузите аватар');
                    _triggerShakeAnimation();
                  } else {
                    setState(() => _registerError = '');
                    _goToPage(7);
                  }
                },
                child: const Text('Продолжить'),
              ),
            ],
          ),
          const Spacer(),
          _buildRegisterError(),
        ],
      ),
    );
  }

  Widget _buildRegisterConsentsScreen() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.neutral500),
            onPressed: () => _goToPage(6), // Назад на Аватар
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _shakeController,
            builder: (context, child) {
              final double offset =
                  math.sin(_shakeController.value * math.pi * 6.0) * 12.0;
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: Form(
              key: _registerFormKey, // Главный ключ формы здесь
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Text(
                    'Последний шаг',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.neutral900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Нам нужны ваши согласия для полноценной работы AI-функций.',
                    style: TextStyle(fontSize: 16, color: AppColors.neutral600),
                  ),
                  const SizedBox(height: 32),
                  // Согласие на лицо
                  KiloCard(
                    padding: const EdgeInsets.all(4),
                    child: CheckboxListTile(
                      value: _faceConsent,
                      onChanged: (v) =>
                          setState(() => _faceConsent = v ?? false),
                      title: const Text('Разрешение на обработку фото',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                          'Я даю согласие на использование моего аватара для AI-визуализации "Точки Б".'),
                      activeColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Согласие на условия
                  KiloCard(
                    padding: const EdgeInsets.all(4),
                    child: FormField<bool>(
                      key: const ValueKey('terms_consent_key'), // Ключ для Form
                      initialValue: _termsConsent,
                      validator: (value) {
                        if (value == false) {
                          // Ошибка, которую _onRegister "увидит"
                          // Текст не будет показан, но validate() вернет false
                          return 'Необходимо принять условия';
                        }
                        return null;
                      },
                      builder: (formFieldState) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CheckboxListTile(
                              value: _termsConsent,
                              onChanged: (v) {
                                setState(() => _termsConsent = v ?? false);
                                formFieldState.didChange(v);
                              },
                              title: const Text('Пользовательское соглашение',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: const Text(
                                  'Я принимаю условия использования и политику конфиденциальности.'),
                              activeColor: AppColors.primary,
                              // Выравниваем чекбокс слева
                              controlAffinity: ListTileControlAffinity.leading,
                              // Показываем красную рамку, если есть ошибка
                              tileColor: formFieldState.hasError
                                  ? AppColors.red.withOpacity(0.05)
                                  : null,
                            ),
                            // Вы можете раскомментировать этот блок,
                            // если хотите показывать текст ошибки под чекбоксом
                            // if (formFieldState.hasError)
                            //   Padding(
                            //     padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                            //     child: Text(
                            //       'Необходимо принять условия',
                            //       style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                            //     ),
                            //   ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isRegistering ? null : _onRegister,
                    child: _isRegistering
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: Colors.white),
                    )
                        : const Text('Завершить регистрацию'),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          _buildRegisterError(),
        ],
      ),
    );
  }

  Widget _buildRegisterError() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: Center(
        child: _registerError.isNotEmpty
            ? Text(
          _registerError,
          style: const TextStyle(
              color: AppColors.red, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        )
            : const SizedBox.shrink(),
      ),
    );
  }
}
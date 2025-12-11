import 'package:flutter/material.dart';

class TranslationService extends ChangeNotifier {
  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  final Map<String, Map<String, Map<String, String>>> _translations = {
    'en': {
      'common': {
        'search': 'Search',
        'cancel': 'Cancel',
        'save': 'Save',
        'login': 'Login',
        'signup': 'Sign Up',
        'email': 'University Email',
        'password': 'Password',
        'full_name': 'Full Name',
        'university': 'University',
        'sign_in': 'Sign In',
        'create_account': 'Create Account',
        'forgot_password': 'Forgot Password?',
        'get_started': 'Get Started',
        'dark_mode': 'Dark Mode',
        'welcome': 'Welcome Back',
      },
      'home': {
        'welcome': 'Welcome back',
        'welcome_message': 'Join a community of students sharing skills through workshops.',
        'quickActions': 'Quick Actions',
        'upcomingWorkshops': 'Upcoming Workshops',
        'recommendedForYou': 'Recommended for You',
      },
      'navigation': {
        'home': 'Home',
        'search': 'Explore',
        'create': 'Create',
        'chat': 'Chat',
        'profile': 'Profile',
      },
      'workshop': {
        'join': 'Join',
        'joined': 'Joined',
      },
    },
    'es': {
      'common': {
        'search': 'Buscar',
        'cancel': 'Cancelar',
        'save': 'Guardar',
        'login': 'Iniciar Sesión',
        'signup': 'Registrarse',
        'email': 'Correo Universitario',
        'password': 'Contraseña',
        'full_name': 'Nombre Completo',
        'university': 'Universidad',
        'sign_in': 'Iniciar Sesión',
        'create_account': 'Crear Cuenta',
        'forgot_password': '¿Olvidaste tu contraseña?',
        'get_started': 'Comenzar',
        'dark_mode': 'Modo Oscuro',
        'welcome': 'Bienvenido de vuelta',
      },
      'home': {
        'welcome': 'Bienvenido de vuelta',
        'welcome_message': 'Únete a una comunidad de estudiantes que comparten habilidades a través de talleres.',
        'quickActions': 'Acciones Rápidas',
        'upcomingWorkshops': 'Próximos Talleres',
        'recommendedForYou': 'Recomendado para Ti',
      },
      'navigation': {
        'home': 'Inicio',
        'search': 'Buscar',
        'create': 'Crear',
        'chat': 'Chat',
        'profile': 'Perfil',
      },
      'workshop': {
        'join': 'Unirse al Taller',
        'joined': 'Unido',
      },
    },
    'zh': {
      'common': {
        'search': '搜索',
        'cancel': '取消',
        'save': '保存',
        'login': '登录',
        'signup': '注册',
        'email': '大学邮箱',
        'password': '密码',
        'full_name': '全名',
        'university': '大学',
        'sign_in': '登录',
        'create_account': '创建账户',
        'forgot_password': '忘记密码？',
        'get_started': '开始',
        'dark_mode': '暗模式',
        'welcome': '欢迎回来',
      },
      'home': {
        'welcome': '欢迎回来',
        'welcome_message': '加入一个通过工作坊分享技能的学生社区。',
        'quickActions': '快速操作',
        'upcomingWorkshops': '即将举行的工作坊',
        'recommendedForYou': '为您推荐',
      },
      'navigation': {
        'home': '首页',
        'search': '搜索',
        'create': '创建',
        'chat': '聊天',
        'profile': '个人资料',
      },
      'workshop': {
        'join': '加入工作坊',
        'joined': '已加入',
      },
    },
  };

  List<Locale> get supportedLocales => const [
    Locale('en'),
    Locale('es'),
    Locale('zh'),
  ];

  LocalizationsDelegate<TranslationService> get delegate => _TranslationServiceDelegate(this);

  String t(String key) {
    final keys = key.split('.');
    Map<String, dynamic> current = _translations[_locale.languageCode] ?? _translations['en']!;
    for (var i = 0; i < keys.length; i++) {
      if (i == keys.length - 1) {
        return current[keys[i]]?.toString() ?? _translations['en']![keys[0]]![keys[1]] ?? key;
      }
      current = current[keys[i]] as Map<String, dynamic>? ?? _translations['en']![keys[0]]!;
    }
    return key; // Fallback to key if no translation found
  }

  void setLocale(String languageCode) {
    if (_translations.containsKey(languageCode)) {
      _locale = Locale(languageCode);
      notifyListeners();
    }
  }
}

class _TranslationServiceDelegate extends LocalizationsDelegate<TranslationService> {
  final TranslationService _service;

  _TranslationServiceDelegate(this._service);

  @override
  bool isSupported(Locale locale) => ['en', 'es', 'zh'].contains(locale.languageCode);

  @override
  Future<TranslationService> load(Locale locale) async {
    _service.setLocale(locale.languageCode);
    return _service;
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<TranslationService> old) => false;
}
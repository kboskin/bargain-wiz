// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Bargain Wiz';

  @override
  String get welcome => 'Bienvenido';

  @override
  String get goBack => 'Volver';

  @override
  String get skip => 'Omitir';

  @override
  String get next => 'Siguiente';

  @override
  String get getStarted => 'Comenzar';

  @override
  String get pleaseSelectOption => 'Por favor selecciona una opción';

  @override
  String get pleaseSelectValue => 'Por favor selecciona un valor';

  @override
  String get invalidScreenIndex => 'Índice de pantalla inválido';

  @override
  String get noOnboardingConfig =>
      'No hay configuración de onboarding disponible';

  @override
  String get termsAndConditions => 'Términos y Condiciones';

  @override
  String get privacyPolicy => 'Política de Privacidad';

  @override
  String agreeToTerms(String appName) {
    return 'Al continuar, aceptas los $appName';
  }

  @override
  String get and => ' y ';

  @override
  String get error => 'Error';

  @override
  String get loading => 'Cargando...';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signInWithGoogle => 'Iniciar sesión con Google';

  @override
  String get signInWithApple => 'Iniciar sesión con Apple';

  @override
  String get dontHaveAccount => '¿No tienes una cuenta?';

  @override
  String get alreadyHaveAccount => '¿Ya tienes una cuenta?';

  @override
  String get continueButton => 'Continuar';

  @override
  String get restorePurchases => 'Restaurar Compras';

  @override
  String get terms => 'Términos';

  @override
  String get privacy => 'Privacidad';

  @override
  String get productNotAvailable =>
      'Producto no disponible. Por favor intenta de nuevo.';

  @override
  String get subscriptionActivated => '¡Suscripción activada!';

  @override
  String get skipForNow => 'Omitir por ahora';

  @override
  String get homeEmptyTitle => 'Sube una captura de un chat o biografía';

  @override
  String get uploadScreenshot => 'Subir captura';

  @override
  String get enterTextManually => 'Escribir texto manualmente';

  @override
  String get getPickupLines => 'Obtener frases de ligue';

  @override
  String get startNewNegotiation => 'Nueva negociación';

  @override
  String get profile => 'Perfil';

  @override
  String get bargainsHistory => 'Historial de ofertas';
}

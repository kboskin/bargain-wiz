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
  String get homeEmptyTitle => 'Tu oferta, mejorada.';

  @override
  String get homeModeChooserTitle => 'Elige tu magia';

  @override
  String get simpleModeTitle => 'Express Dealmaker';

  @override
  String get simpleModeSubtitle =>
      'Suelta una captura y recibe líneas de la IA';

  @override
  String get chatModeTitle => 'Pro Cierra Ofertas';

  @override
  String get chatModeSubtitle => 'Chatea con el mago';

  @override
  String get simpleModeDropHint => 'Suelta una captura';

  @override
  String get simpleModeAddScreenshot => 'Añadir captura';

  @override
  String get tapReplyToCopy => 'toca una respuesta para copiar';

  @override
  String get simpleModeSeeing => 'Viendo';

  @override
  String get getDealReply => 'Obtener respuesta';

  @override
  String get expressDealmakerKeywordHint =>
      'Dinos una o dos palabras para enfocar';

  @override
  String get expressDealmakerKeywordHintShort => 'Palabras clave (opcional)';

  @override
  String get holdReplyForMore => 'mantén una respuesta para más';

  @override
  String get getMore => 'Obtener más';

  @override
  String get retry => 'Reintentar';

  @override
  String get linesSectionTitle => 'Frases para empezar e ideas de negociación';

  @override
  String get linesSectionSubtitle =>
      'Toca una línea para copiar y usar en tu chat';

  @override
  String get linesPlaceholder =>
      'Obtén frases para empezar conversaciones e ideas de negociación';

  @override
  String get uploadScreenshot => 'Express Dealmaker';

  @override
  String get enterTextManually => 'Pro Cierra Ofertas';

  @override
  String get getPickupLines => 'Líneas que cierran';

  @override
  String get startNewNegotiation => 'Nueva negociación';

  @override
  String get share => 'Compartir';

  @override
  String get profile => 'Perfil';

  @override
  String get bargainsHistory => 'Historial de ofertas';

  @override
  String get logOut => 'Cerrar sesión';

  @override
  String get rateUs => 'Valóranos';

  @override
  String get areYouSatisfied => '¿Estás satisfecho?';

  @override
  String get yes => 'Sí';

  @override
  String get no => 'No';

  @override
  String get signInError => 'Algo salió mal. Por favor intenta de nuevo.';

  @override
  String get refer => 'Referir';

  @override
  String get referModalTitle => 'Invita amigos y gana';

  @override
  String get referBenefit1 =>
      'Dale a tus amigos acceso a Bargain Wiz: ofertas y negociación más inteligentes.';

  @override
  String get referBenefit2 =>
      'Gana recompensas cuando tus amigos se unan con tu enlace.';

  @override
  String get referBenefit3 => 'Cuanto más compartas, más puedes ganar.';

  @override
  String get referShareInvite => 'Compartir enlace de invitación';

  @override
  String get proRemoveScreenshot => 'Quitar captura';

  @override
  String proScreenshotLimit(int count) {
    return 'Hasta $count capturas por mensaje';
  }
}

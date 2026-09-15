import 'package:flutter/widgets.dart';

import 'package:appwizard/core/utils/template_text.dart';

/// EN/ES copy of the Bargains History screen (no remote-config key exists for it).
class HistoryCopy {
  HistoryCopy._();

  static const Map<String, String> title = {'en': 'Bargains History', 'es': 'Historial de ofertas'};
  static const Map<String, String> searchHint = {
    'en': 'Search deals, sellers, items',
    'es': 'Busca tratos, vendedores, artículos',
  };
  static const Map<String, String> filterAll = {'en': 'All', 'es': 'Todos'};
  static const Map<String, String> emptyTitle = {'en': 'No deals yet', 'es': 'Aún no hay tratos'};
  static const Map<String, String> emptyBody = {
    'en': 'Your saved negotiations will show up here.',
    'es': 'Tus negociaciones guardadas aparecerán aquí.',
  };
  static const Map<String, String> nothingMatchesTitle = {'en': 'Nothing matches', 'es': 'Sin coincidencias'};
  static const Map<String, String> nothingMatchesBody = {
    'en': 'Try another search or filter.',
    'es': 'Prueba otra búsqueda u otro filtro.',
  };
  static const Map<String, String> dealRemoved = {'en': 'Deal removed', 'es': 'Trato eliminado'};
  static const Map<String, String> deleteAction = {'en': 'Delete', 'es': 'Eliminar'};
  static const Map<String, String> statusSheetTitle = {'en': 'Deal status', 'es': 'Estado del trato'};
  static const Map<String, String> finalPrice = {'en': 'Final price', 'es': 'Precio final'};
  static const Map<String, String> finalPriceHint = {'en': r'e.g. $365', 'es': r'p. ej. $365'};
  static const Map<String, String> save = {'en': 'Save', 'es': 'Guardar'};

  static String of(BuildContext context, Map<String, String> text) =>
      TemplateText.textOf(context, text, fallback: text['en'] ?? '');
}

// ============================================================================
//  RECOMENDACIONES POR ENFERMEDAD
//  Edita los textos aquí. La clave es la etiqueta de etiquetas.txt.
//  - prevention: siempre se muestra (monitoreo y prevención).
//  - chemical:   control químico. En Leve se muestra como "solo si avanza";
//                en Moderada/Severa se muestra primero como recomendado.
// ============================================================================

import '../model/leaf_diagnosis.dart';

class DiseaseRecommendations {
  final List<String> prevention;
  final List<String> chemical;

  const DiseaseRecommendations({
    required this.prevention,
    required this.chemical,
  });
}

class Recommendations {
  Recommendations._();

  static const byLabel = <String, DiseaseRecommendations>{
    'Roya_del_Maíz': DiseaseRecommendations(
      prevention: [
        'Sembrar híbridos resistentes a la roya en las próximas campañas.',
        'Monitorear el cultivo cada semana, revisando el haz y el envés de las hojas.',
        'Evitar el exceso de humedad: no regar por aspersión al final de la tarde.',
        'Evitar siembras muy densas para mejorar la ventilación entre plantas.',
      ],
      chemical: [
        'Si la infección es temprana y severa, aplicar fungicidas con triazoles o estrobilurinas.',
        'Repetir la evaluación 7 a 10 días después de aplicar para confirmar el control.',
      ],
    ),
    'Mancha_Gris_de_la_Hoja': DiseaseRecommendations(
      prevention: [
        'Rotar cultivos: no sembrar maíz sobre maíz en el mismo lote.',
        'Manejar o incorporar el rastrojo, donde el hongo sobrevive entre campañas.',
        'Usar híbridos tolerantes a la mancha gris.',
        'Favorecer la buena aireación del cultivo (densidad y orientación de surcos adecuadas).',
      ],
      chemical: [
        'Aplicar fungicida con mezcla de estrobilurina + triazol en las etapas previas a la floración.',
        'Priorizar la protección de las hojas por encima de la mazorca.',
      ],
    ),
    'Mancha_de_Asfalto': DiseaseRecommendations(
      prevention: [
        'Rotar cultivos para cortar el ciclo del hongo.',
        'Manejar los residuos de cosecha infectados.',
        'Usar híbridos tolerantes a la mancha de asfalto.',
        'Monitorear con frecuencia: la enfermedad puede avanzar muy rápido.',
      ],
      chemical: [
        'Aplicar a tiempo un fungicida con estrobilurina + triazol, antes de que la enfermedad avance a las hojas superiores.',
      ],
    ),
  };

  /// Advertencias que se muestran SIEMPRE.
  static const warnings = <String>[
    'Se mencionan ingredientes activos, no marcas comerciales.',
    'Sigue la dosis y el período de carencia indicados en la etiqueta del producto.',
    'Usa equipo de protección personal al preparar y aplicar productos.',
    'Consulta a un ingeniero agrónomo antes de aplicar cualquier producto.',
    'Estas recomendaciones son orientativas y no reemplazan una evaluación en campo.',
  ];

  /// Frase de énfasis según la severidad.
  static String emphasisFor(Severity? severity) => switch (severity) {
    Severity.leve =>
      'Afectación leve: prioriza el monitoreo y la prevención. El control químico solo si la enfermedad avanza.',
    Severity.moderada =>
      'Afectación moderada: se recomienda control químico, junto con las medidas de prevención.',
    Severity.severa =>
      'Afectación severa: se recomienda control químico cuanto antes y consultar a un agrónomo.',
    null =>
      'No se pudo medir el área afectada: revisa la planta en campo antes de decidir un tratamiento.',
  };

  /// true si el control químico debe mostrarse como recomendado.
  static bool chemicalRecommended(Severity? severity) =>
      severity == Severity.moderada || severity == Severity.severa;
}

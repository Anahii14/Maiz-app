// ============================================================================
//  DECISIÓN DEL DIAGNÓSTICO
//  Une las probabilidades del modelo con el % de área afectada (HSV).
//
//  IMPORTANTE: las probabilidades dicen qué tan seguro está el modelo de cada
//  clase. NO son el porcentaje de la hoja afectado; ese porcentaje sale
//  SIEMPRE de la segmentación HSV.
// ============================================================================

/// Si la probabilidad más alta es menor a esto → "No reconocido".
const double umbralNoReconocido = 0.45;

/// Si la enfermedad ganadora tiene menos que esto → se muestra el aviso de
/// "confianza media" (el diagnóstico se muestra igual).
const double umbralConfianzaAlta = 0.70;

/// Si el modelo dice "sana" pero alguna enfermedad tiene al menos esta
/// probabilidad → se informa esa enfermedad como zona afectada (parcial).
const double umbralEnfermedadMin = 0.15;

/// Si el modelo dice "sana" pero la segmentación mide al menos este % de la
/// hoja afectado → se informa la enfermedad más probable (parcial).
const double areaMinPct = 5.0;

/// Nombres de clase especiales (deben coincidir con etiquetas.txt).
const String claseSana = 'Hoja_sana';
const String claseNoEsHoja = 'No_es_hoja';

/// Muestra en la consola el detalle de cada decisión (para ajustar umbrales).
/// TEMPORAL: poner en false cuando los umbrales estén calibrados.
const bool logsDeDecision = true;

enum EstadoDiagnostico { sana, enferma, noReconocido, noEsHoja }

/// Una clase con su probabilidad.
class ClaseProbable {
  final String etiqueta;
  final double probabilidad;

  const ClaseProbable(this.etiqueta, this.probabilidad);

  @override
  String toString() => '$etiqueta=${(probabilidad * 100).toStringAsFixed(1)}%';
}

class Decision {
  final EstadoDiagnostico estado;

  /// Etiqueta de la enfermedad mostrada (solo si estado == enferma).
  final String? enfermedad;

  /// true: el modelo dijo "sana" pero se detectó una zona afectada.
  final bool parcial;

  /// true: la enfermedad ganó con menos de [umbralConfianzaAlta].
  final bool confianzaMedia;

  /// Probabilidad de la clase mostrada (enfermedad o sana).
  final double confianza;

  /// Las dos clases más probables, de mayor a menor.
  final List<ClaseProbable> top2;

  /// Qué regla se aplicó (para los logs y la tesis).
  final String regla;

  const Decision({
    required this.estado,
    required this.confianza,
    required this.top2,
    required this.regla,
    this.enfermedad,
    this.parcial = false,
    this.confianzaMedia = false,
  });
}

/// Decide el diagnóstico final.
///
/// [probabilidades]: etiqueta → probabilidad (salida del modelo).
/// [areaAfectadaPct]: % de hoja afectado por HSV (null o 0 si no se midió).
Decision decidir(Map<String, double> probabilidades, double? areaAfectadaPct) {
  if (probabilidades.isEmpty) {
    throw ArgumentError('No hay probabilidades.');
  }
  final ordenadas =
      probabilidades.entries.map((e) => ClaseProbable(e.key, e.value)).toList()
        ..sort((a, b) => b.probabilidad.compareTo(a.probabilidad));
  final top2 = ordenadas.take(2).toList();
  final ganadora = ordenadas.first;
  final area = areaAfectadaPct ?? 0;

  // Regla 1: existe la clase "No_es_hoja" y gana.
  if (ganadora.etiqueta == claseNoEsHoja) {
    return Decision(
      estado: EstadoDiagnostico.noEsHoja,
      confianza: ganadora.probabilidad,
      top2: top2,
      regla: '1: gana $claseNoEsHoja',
    );
  }

  // Regla 2: ninguna clase es suficientemente probable.
  if (ganadora.probabilidad < umbralNoReconocido) {
    return Decision(
      estado: EstadoDiagnostico.noReconocido,
      confianza: ganadora.probabilidad,
      top2: top2,
      regla:
          '2: máx ${ganadora.probabilidad.toStringAsFixed(2)} '
          '< $umbralNoReconocido',
    );
  }

  // Regla 3: gana una enfermedad → se muestra esa (la de mayor probabilidad).
  if (ganadora.etiqueta != claseSana) {
    final media = ganadora.probabilidad < umbralConfianzaAlta;
    return Decision(
      estado: EstadoDiagnostico.enferma,
      enfermedad: ganadora.etiqueta,
      confianza: ganadora.probabilidad,
      confianzaMedia: media,
      top2: top2,
      regla: '3: gana enfermedad${media ? ' (confianza media)' : ''}',
    );
  }

  // Regla 4: gana "sana", pero puede haber una zona afectada.
  final enfermedades = ordenadas
      .where((c) => c.etiqueta != claseSana && c.etiqueta != claseNoEsHoja)
      .toList();
  final mejorEnf = enfermedades.isEmpty ? null : enfermedades.first;
  if (mejorEnf != null) {
    final porProbabilidad = mejorEnf.probabilidad >= umbralEnfermedadMin;
    final porArea = area >= areaMinPct;
    if (porProbabilidad || porArea) {
      return Decision(
        estado: EstadoDiagnostico.enferma,
        enfermedad: mejorEnf.etiqueta,
        parcial: true,
        confianza: mejorEnf.probabilidad,
        top2: top2,
        regla:
            '4: sana pero ${[if (porProbabilidad) 'prob ${mejorEnf.probabilidad.toStringAsFixed(2)} >= $umbralEnfermedadMin', if (porArea) 'área ${area.toStringAsFixed(1)} % >= $areaMinPct %'].join(' y ')} → parcial',
      );
    }
  }
  return Decision(
    estado: EstadoDiagnostico.sana,
    confianza: ganadora.probabilidad,
    top2: top2,
    regla: '4: sana (sin señales de enfermedad)',
  );
}

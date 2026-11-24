// ============================================================================
//  CONFIGURACIÓN DEL ANÁLISIS DE HOJAS DE MAÍZ
//  Todos los umbrales y rangos de color están AQUÍ para ajustarlos fácilmente.
// ============================================================================
//
//  Sobre el formato HSV usado (igual que OpenCV, para poder comparar con
//  tutoriales y con pruebas hechas en Python):
//    H (tono)        : 0 – 179   (el círculo de color de 360° dividido entre 2)
//                      0 ≈ rojo, 15 ≈ naranja, 30 ≈ amarillo, 60 ≈ verde,
//                      90 ≈ cian, 120 ≈ azul, 150 ≈ magenta, 179 ≈ rojo.
//    S (saturación)  : 0 – 255   (0 = gris/blanco/negro, 255 = color puro)
//    V (brillo)      : 0 – 255   (0 = negro, 255 = máximo brillo)
// ============================================================================

/// Rango de color HSV (formato OpenCV). Los límites son inclusivos.
class HsvRange {
  final int hMin, hMax, sMin, sMax, vMin, vMax;

  const HsvRange({
    this.hMin = 0,
    this.hMax = 179,
    this.sMin = 0,
    this.sMax = 255,
    this.vMin = 0,
    this.vMax = 255,
  });

  bool contains(int h, int s, int v) =>
      h >= hMin &&
      h <= hMax &&
      s >= sMin &&
      s <= sMax &&
      v >= vMin &&
      v <= vMax;
}

class AnalysisConfig {
  AnalysisConfig._();

  // --------------------------------------------------------------------------
  //  ARCHIVOS DEL MODELO
  //  El tamaño de entrada, el orden de color, la escala y los nombres de los
  //  archivos NO se fijan aquí: se leen de modelo_config.json.
  // --------------------------------------------------------------------------

  static const modelsFolder = 'assets/models';
  static const modelConfigAsset = '$modelsFolder/modelo_config.json';
  static const recommendationsAsset = '$modelsFolder/recomendaciones.json';

  /// Núcleos del procesador que usa el modelo. 4 funciona bien en la
  /// mayoría de celulares (más núcleos = más rápido, hasta cierto punto).
  static const cpuThreads = 4;

  // --------------------------------------------------------------------------
  //  SEVERIDAD (solo cuando el estado final es ENFERMA)
  // --------------------------------------------------------------------------

  /// Menor a 10 %  → Leve.
  static const severityModerateFrom = 10.0;

  /// De 10 % a 30 % → Moderada.   Mayor a 30 % → Severa.
  static const severitySevereAbove = 30.0;

  // --------------------------------------------------------------------------
  //  SEGMENTACIÓN HSV DE LA HOJA
  //  El % afectado se calcula SIEMPRE (salvo "no reconocido" / "no es hoja"),
  //  también cuando el modelo dice "sana", porque la decisión lo usa.
  // --------------------------------------------------------------------------

  /// Lado máximo (en píxeles) de la imagen usada para medir el área.
  /// Más grande = más preciso pero más lento.
  static const segmentationMaxSide = 512;

  /// Tejido de hoja SANO: verdes y amarillo-verdosos.
  static const leafRanges = <HsvRange>[
    // Verde de la hoja (de verde amarillento a verde azulado).
    HsvRange(hMin: 30, hMax: 90, sMin: 40, vMin: 35),
    // Amarillo-verdoso (hoja algo clara o con poca clorofila, aún sana).
    // Empieza en H 27: de H 20 a 26 están las pústulas de roya (medido en
    // fotos reales), que NO deben contarse como hoja sana.
    HsvRange(hMin: 27, hMax: 29, sMin: 60, vMin: 70),
  ];

  /// Radio (en % del lado de la imagen) para "cerrar" la silueta de la hoja:
  /// une las manchas del borde con el resto de la hoja. 0 = sin cierre.
  static const leafClosingRadiusPercent = 2.0;

  /// Si la hoja ocupa menos de este % de la imagen, no se mide el área
  /// (la foto está muy lejos o la hoja no se distingue del fondo).
  static const minLeafAreaPercent = 5.0;

  /// Un hueco dentro de la silueta verde se considera parte de la hoja (una
  /// mancha) solo si mide como máximo este % de la imagen. Huecos más grandes
  /// suelen ser tierra o fondo entre hojas y NO se cuentan.
  static const maxLesionHolePercent = 10.0;

  /// Colores que cuentan como ZONA AFECTADA (con color). Pueden estar también
  /// en el borde de la hoja.
  static const lesionRanges = <HsvRange>[
    // Marrón / tejido muerto, de oscuro a marrón claro (beige seco).
    // En fotos reales el tejido muerto mide H 16–24, S 50–125, V 160–240.
    // S ≥ 45 evita contar reflejos de luz o el fondo blanco.
    HsvRange(hMin: 5, hMax: 26, sMin: 45, vMin: 40, vMax: 240),
    // Naranja / marrón rojizo intenso: pústulas de roya.
    // En fotos reales las pústulas miden H 20–25, S 150–225, V 80–160.
    HsvRange(hMin: 0, hMax: 26, sMin: 100, vMin: 50, vMax: 235),
    HsvRange(hMin: 170, hMax: 179, sMin: 90, vMin: 60, vMax: 235),
    // Amarillo intenso (clorosis fuerte).
    HsvRange(hMin: 18, hMax: 26, sMin: 150, vMin: 150),
  ];

  /// Colores NEUTROS que cuentan como zona afectada SOLO si están rodeados
  /// por la hoja (nunca en el borde), porque el fondo (sombras, tierra,
  /// papel) también suele ser gris o negro.
  static const neutralLesionRanges = <HsvRange>[
    // Gris (lesiones de mancha gris). Brillo limitado para no contar
    // reflejos de luz sobre la hoja.
    HsvRange(sMax: 40, vMin: 80, vMax: 200),
    // Negro / muy oscuro (puntos de mancha de asfalto).
    HsvRange(vMax: 60),
  ];

  // --------------------------------------------------------------------------
  //  FOTO GUARDADA EN EL HISTORIAL (Firestore)
  // --------------------------------------------------------------------------

  /// Lado máximo y calidad JPEG de la foto que se guarda con cada análisis.
  /// Firestore admite 1 MB por documento; se apunta a menos de 600 KB.
  static const storedPhotoMaxSide = 1024;
  static const storedPhotoQuality = 80;
  static const storedPhotoMaxBytes = 600 * 1024;
}

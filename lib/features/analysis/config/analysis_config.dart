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
  //  MODELO
  // --------------------------------------------------------------------------

  /// Archivos del modelo dentro de la carpeta assets/.
  static const modelAsset = 'assets/models/modelo_plantas.tflite';
  static const labelsAsset = 'assets/models/etiquetas.txt';

  /// Tamaño de entrada del modelo (224 x 224 píxeles, 3 canales RGB).
  /// Los valores se entregan en 0–255 como float32 SIN dividir entre 255
  /// (el modelo normaliza por dentro).
  static const inputSize = 224;

  /// Etiqueta de la clase "hoja sana" tal como aparece en etiquetas.txt.
  static const healthyLabel = 'Hoja_sana';

  /// Confianza mínima para aceptar el resultado del modelo (0.70 = 70 %).
  /// Por debajo de esto se muestra "No reconocido".
  static const minConfidence = 0.70;

  // --------------------------------------------------------------------------
  //  SEVERIDAD (según el % de área afectada de la hoja)
  // --------------------------------------------------------------------------

  /// Menor a 10 %  → Leve.
  static const severityModerateFrom = 10.0;

  /// De 10 % a 30 % → Moderada.   Mayor a 30 % → Severa.
  static const severitySevereAbove = 30.0;

  // --------------------------------------------------------------------------
  //  SEGMENTACIÓN DE LA HOJA
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

  /// Manchas comunes a todas las enfermedades: marrón (tejido muerto)
  /// y amarillo intenso (clorosis fuerte).
  static const commonLesionRanges = <HsvRange>[
    // Marrón / tejido necrótico, de oscuro a marrón claro (beige seco).
    // En fotos reales el tejido muerto mide H 16–24, S 50–125, V 160–240.
    // S ≥ 45 evita contar reflejos de luz o el fondo blanco.
    HsvRange(hMin: 5, hMax: 26, sMin: 45, vMin: 40, vMax: 240),
    // Amarillo intenso.
    HsvRange(hMin: 18, hMax: 23, sMin: 150, vMin: 150),
  ];

  /// Manchas específicas de cada enfermedad (clave = etiqueta del modelo).
  static const lesionRangesByLabel = <String, List<HsvRange>>{
    // Roya del maíz: pústulas naranja / marrón rojizo.
    // En fotos reales las pústulas miden H 20–25, S 150–225, V 80–160.
    'Roya_del_Maíz': [
      HsvRange(hMin: 0, hMax: 26, sMin: 100, vMin: 50, vMax: 235),
      HsvRange(hMin: 170, hMax: 179, sMin: 90, vMin: 60, vMax: 235),
    ],
    // Mancha gris: lesiones gris / marrón claro (poca saturación).
    'Mancha_Gris_de_la_Hoja': [
      // Gris (sin color). Se limita el brillo para no contar reflejos de luz.
      HsvRange(sMax: 55, vMin: 80, vMax: 210),
      // Marrón claro / beige. En fotos reales: H 16–24, S 50–125, V 160–240.
      HsvRange(hMin: 8, hMax: 26, sMin: 30, sMax: 130, vMin: 110, vMax: 240),
    ],
    // Mancha de asfalto: puntos negros brillantes.
    'Mancha_de_Asfalto': [
      // Negro / muy oscuro (cualquier tono).
      HsvRange(vMax: 70),
      // Marrón muy oscuro alrededor de las manchas.
      HsvRange(hMin: 0, hMax: 30, sMin: 40, vMax: 95),
    ],
  };

  // --------------------------------------------------------------------------
  //  FOTO GUARDADA EN EL HISTORIAL (Firestore)
  // --------------------------------------------------------------------------

  /// Lado máximo y calidad JPEG de la foto que se guarda con cada análisis.
  /// Firestore admite 1 MB por documento; se apunta a menos de 600 KB.
  static const storedPhotoMaxSide = 1024;
  static const storedPhotoQuality = 80;
  static const storedPhotoMaxBytes = 600 * 1024;
}

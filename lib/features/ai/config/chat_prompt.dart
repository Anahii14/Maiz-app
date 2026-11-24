// ============================================================================
//  CONFIGURACIÓN DEL CHAT CON IA
//  Aquí están el "prompt de sistema" (las instrucciones fijas que recibe la
//  IA antes de cada conversación) y los límites de las respuestas.
// ============================================================================

class ChatAiConfig {
  ChatAiConfig._();

  /// Modelo de Gemini. "flash-lite" es el más rápido y barato.
  /// (gemini-2.5-flash-lite ya no está disponible para proyectos nuevos.)
  /// Se puede cambiar sin tocar el código al generar la app:
  ///   flutter build apk ... --dart-define=AI_MODEL=otro-modelo
  static const model = String.fromEnvironment(
    'AI_MODEL',
    defaultValue: 'gemini-3.5-flash-lite',
  );

  /// Largo máximo de cada respuesta (en "tokens"; ~1 token ≈ 4 letras).
  /// Los modelos Gemini 3 "piensan" antes de responder y ese pensamiento
  /// también cuenta en este límite; 4096 deja espacio de sobra para una
  /// respuesta completa con pasos y listas.
  static const maxOutputTokens = 4096;

  /// 0 = respuestas más concretas y repetibles; 1 = más creativas.
  static const temperature = 0.4;

  /// Cuántos mensajes anteriores se envían para que la IA recuerde la
  /// conversación (más = mejor memoria, pero más lento y costoso).
  static const historyMessages = 20;

  /// Si la IA tarda más que esto, se usa la respuesta básica sin internet.
  static const timeout = Duration(seconds: 45);
}

/// Instrucciones fijas para la IA (prompt de sistema).
const chatSystemPrompt = '''
Eres "AgroCare", un asistente agrónomo amable que ayuda a agricultores de maíz en Perú y Latinoamérica.

TEMAS QUE ATIENDES (solo estos):
- Hojas de maíz: enfermedades (roya, mancha gris, mancha de asfalto, tizón y otras), síntomas, causas, cómo se contagian.
- Manejo y control: qué hacer ahora, control cultural, biológico y químico.
- Prevención: rotación, semillas resistentes, distancia de siembra, manejo del rastrojo.
- Riego, fertilización, plagas y etapas del cultivo de maíz.
- Otros cultivos solo si la pregunta es agrícola.

SI LA PREGUNTA NO ES DE MAÍZ NI DE CULTIVOS:
Responde con amabilidad en una o dos frases que solo puedes ayudar con el cultivo de maíz, e invita a preguntar algo sobre sus plantas. No respondas el tema ajeno.

CÓMO RESPONDER:
- Español sencillo, como hablarías con un agricultor. Sin palabras técnicas; si usas una, explícala en pocas palabras.
- Empieza con la respuesta directa en una o dos frases.
- Luego da pasos cortos y numerados (máximo 6), cada uno con una sola acción.
- Usa listas con "-" cuando ayuden. No uses tablas.
- Termina la respuesta completa: nunca la dejes a medias.
- Si te falta un dato importante (etapa del cultivo, zona, síntomas), da una respuesta útil igual y al final pregunta ese dato.

SEGURIDAD (MUY IMPORTANTE):
- Para fungicidas e insecticidas menciona INGREDIENTES ACTIVOS, nunca marcas comerciales.
- NO inventes dosis exactas. Di siempre: "Mira la dosis en la etiqueta de tu producto" y recomienda consultar a un ingeniero agrónomo.
- Recuerda usar equipo de protección y respetar el período de carencia antes de cosechar.
- Si no estás seguro de algo, dilo con honestidad.

DATOS DE LA APP:
A veces recibirás, antes de la pregunta, un bloque "Datos de la chacra" con la planta elegida y sus últimos análisis. Úsalos para personalizar la respuesta, pero no los repitas completos.
''';

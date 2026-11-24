import '../../analysis/model/analysis_dto.dart';
import '../../analysis/model/leaf_diagnosis.dart';
import '../../analysis/recommendations/recommendations_data.dart';
import '../../plants/model/plant_dto.dart';
import '../../plants/model/plant_status.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

/// Respuestas BÁSICAS sin internet (reglas fijas por palabras clave).
///
/// El chat usa la IA real (Gemini, ver chat_ai_client.dart). Este servicio
/// solo se usa: (1) para armar los "Datos de la chacra" que se envían a la
/// IA y (2) como respaldo cuando no hay internet o la IA falla.
class AiChatService {
  AiChatService({this.repository});

  /// Recomendaciones de recomendaciones.json (si ya están cargadas).
  final RecommendationsRepository? repository;

  RecommendationsData? get recommendations => repository?.cached;

  /// Resumen de la planta elegida y sus últimos análisis, para la IA.
  String buildContext({
    PlantDto? plant,
    List<AnalysisDto> recentAnalyses = const [],
  }) {
    if (plant == null) return '';
    final b = StringBuffer('Datos de la chacra (de la app):\n')
      ..writeln('- Nombre: ${plant.name}')
      ..writeln(
        '- Variedad: ${plant.variety.isNotEmpty ? plant.variety : "no registrada"}',
      )
      ..writeln('- Estado: ${plant.status.label}')
      ..writeln(
        '- Sembrada el ${_formatDate(plant.plantedDate)} '
        '(${DateTime.now().difference(plant.plantedDate).inDays} días)',
      )
      ..writeln('- Último riego: ${_formatDate(plant.lastWateringDate)}');
    if (plant.areaHectares > 0) b.writeln('- Área: ${plant.areaHectares} ha');
    final own = recentAnalyses.where((a) => a.plantName == plant.name).take(3);
    for (final a in own) {
      b.writeln('- Análisis del ${_formatDate(a.date)}: ${a.summary}');
    }
    return b.toString();
  }

  String generateResponse({
    required String userMessage,
    PlantDto? plant,
    List<AnalysisDto> recentAnalyses = const [],
  }) {
    final query = userMessage.toLowerCase().trim();

    if (query.contains('cómo está') ||
        query.contains('como esta') ||
        query.contains('estado')) {
      return _plantStatusResponse(plant, recentAnalyses);
    }
    if (query.contains('tratamiento') || query.contains('recomienda')) {
      return _treatmentResponse(plant, recentAnalyses);
    }
    if (query.contains('regar') || query.contains('riego')) {
      return _wateringResponse(plant);
    }
    if (query.contains('plaga') || query.contains('plagas')) {
      return _pestsResponse();
    }

    if (plant != null) {
      return 'Sobre ${plant.name} (${plant.variety.isNotEmpty ? plant.variety : "sin variedad registrada"}): estado ${plant.status.label}, siembra ${_formatDate(plant.plantedDate)}. Puedo ayudarte con riego, enfermedades o tratamientos.';
    }

    return 'El maíz requiere suelo bien drenado, sol pleno y monitoreo de roya, mancha gris y tizón foliar. Registra una planta para consejos personalizados o pregúntame sobre plagas, riego o fertilización.';
  }

  String _plantStatusResponse(PlantDto? plant, List<AnalysisDto> analyses) {
    if (plant == null) {
      return 'Selecciona una planta para revisar su estado. Sin planta específica puedo darte recomendaciones generales de maíz.';
    }

    final latest = analyses.where((a) => a.plantName == plant.name).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final buffer = StringBuffer(
      '${plant.name} está en estado ${plant.status.label}. ',
    );

    if (latest.isNotEmpty) {
      final last = latest.first;
      buffer.write(
        'Último análisis (${_formatDate(last.date)}): ${last.summary}. ',
      );
    } else {
      buffer.write(
        'Aún no hay análisis registrados. Te recomiendo un análisis de hoja. ',
      );
    }

    switch (plant.status) {
      case PlantStatus.saludable:
        buffer.write('Continúa el monitoreo semanal.');
      case PlantStatus.enObservacion:
        buffer.write(
          'Vigila nuevas manchas y considera un fungicida preventivo.',
        );
      case PlantStatus.enfermo:
        buffer.write('Aplica tratamiento y repite análisis en 5 a 7 días.');
      case PlantStatus.critico:
        buffer.write(
          'Acción urgente: aislar zona y consultar extensión agrícola.',
        );
    }

    return buffer.toString();
  }

  String _treatmentResponse(PlantDto? plant, List<AnalysisDto> analyses) {
    final sorted = List<AnalysisDto>.from(
      plant == null
          ? analyses
          : analyses.where((a) => a.plantName == plant.name),
    )..sort((a, b) => b.date.compareTo(a.date));

    final latest = sorted.firstOrNull;
    if (latest != null && !latest.isHealthy) {
      // Mismos textos que la pantalla de recomendaciones (recomendaciones.json).
      final recs = recommendations?.of(latest.label);
      final severe =
          latest.severity == Severity.moderada ||
          latest.severity == Severity.severa;
      final source = severe && !latest.partial
          ? recs?.actionsModerateSevere
          : recs?.actionsMild;
      final tips = (source ?? const <String>[]).take(3).join('\n• ');
      return 'Para ${latest.disease} detectado en ${latest.plantName}:\n• $tips';
    }

    return 'Sin enfermedad activa detectada. Mantén rotación de cultivos, monitoreo de humedad y fungicida preventivo en épocas lluviosas.';
  }

  String _wateringResponse(PlantDto? plant) {
    if (plant == null) {
      return 'El maíz necesita riego profundo cada 7 a 10 días en floración. Evita encharcamiento. Registra tus plantas para consejos personalizados.';
    }

    final daysSince = DateTime.now().difference(plant.lastWateringDate).inDays;
    if (daysSince >= 7) {
      return '${plant.name}: han pasado $daysSince días desde el último riego. Es buen momento para regar profundamente, preferiblemente al amanecer.';
    }
    return '${plant.name}: último riego ${_formatDate(plant.lastWateringDate)} ($daysSince días). Próximo riego recomendado en ${7 - daysSince} días aprox.';
  }

  String _pestsResponse() {
    return 'Plagas comunes en maíz:\n'
        '• Gusano cogollero: control biológico con Bacillus thuringiensis.\n'
        '• Trips: aceite de neem en brotes nuevos.\n'
        '• Barrenador del tallo: eliminar plantas afectadas.\n'
        '• Chinches: monitoreo con trampas y rotación de cultivos.';
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}

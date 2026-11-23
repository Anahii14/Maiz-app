import 'dart:async';

import 'package:command_it/command_it.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:watch_it/watch_it.dart';

import '../../plants/manager/plants_manager.dart';
import '../../plants/model/plant_dto.dart';
import '../../plants/model/plant_status.dart';
import '../model/analysis_dto.dart';
import '../model/leaf_diagnosis.dart';
import '../services/analysis_data_source.dart';
import '../services/leaf_analyzer.dart';

class AnalysisRunRequest {
  final String plantId;
  final XFile image;

  const AnalysisRunRequest({required this.plantId, required this.image});
}

/// Resultado de un análisis: el diagnóstico y, si se guardó, su id.
class AnalysisOutcome {
  final LeafDiagnosis diagnosis;
  final String plantName;
  final String? savedId;

  const AnalysisOutcome({
    required this.diagnosis,
    required this.plantName,
    this.savedId,
  });
}

class AnalysisManager {
  AnalysisManager({
    required String userId,
    required AnalysisDataSource service,
    required PlantsManager plantsManager,
    LeafAnalyzer? analyzer,
  }) : _userId = userId,
       _service = service,
       _plantsManager = plantsManager,
       _analyzerOverride = analyzer;

  final String _userId;
  final AnalysisDataSource _service;
  final PlantsManager _plantsManager;
  final LeafAnalyzer? _analyzerOverride;

  LeafAnalyzer get _analyzer => _analyzerOverride ?? di<LeafAnalyzer>();

  final analyses = ValueNotifier<List<AnalysisEntry>>([]);

  StreamSubscription<List<AnalysisEntry>>? _subscription;

  late final runAnalysisCommand =
      Command.createAsync<AnalysisRunRequest, AnalysisOutcome?>(
        analyze,
        initialValue: null,
      );

  /// Analiza la foto, guarda el resultado y actualiza el estado de la planta.
  Future<AnalysisOutcome> analyze(AnalysisRunRequest request) async {
    final plantEntry = _plantsManager.plants.value.firstWhere(
      (entry) => entry.id == request.plantId,
    );
    final bytes = await request.image.readAsBytes();
    final diagnosis = await _analyzer.analyze(bytes);

    // "No reconocido" no se guarda: no hay un diagnóstico válido.
    if (diagnosis.status == DiagnosisStatus.notRecognized) {
      return AnalysisOutcome(
        diagnosis: diagnosis,
        plantName: plantEntry.dto.name,
      );
    }

    final id = await _service.create(
      _userId,
      AnalysisDto.fromDiagnosis(
        diagnosis: diagnosis,
        plantId: request.plantId,
        plantName: plantEntry.dto.name,
      ),
    );

    final newStatus = _statusFor(diagnosis);
    if (newStatus != plantEntry.dto.status) {
      _plantsManager.savePlantCommand.run(
        PlantSaveRequest(
          id: request.plantId,
          dto: plantEntry.dto.copyWith(status: newStatus),
        ),
      );
    }

    return AnalysisOutcome(
      diagnosis: diagnosis,
      plantName: plantEntry.dto.name,
      savedId: id,
    );
  }

  /// Estado de la planta según el último análisis.
  static PlantStatus _statusFor(LeafDiagnosis d) {
    if (d.status == DiagnosisStatus.healthy) return PlantStatus.saludable;
    return switch (d.severity) {
      Severity.severa => PlantStatus.critico,
      Severity.moderada => PlantStatus.enfermo,
      _ => PlantStatus.enObservacion,
    };
  }

  Future<AnalysisManager> init() async {
    _subscription = _service
        .watchAnalyses(_userId)
        .listen(
          (entries) {
            analyses.value = entries;
          },
          onError: (_) {
            analyses.value = const [];
          },
        );
    return this;
  }

  void dispose() {
    _subscription?.cancel();
    analyses.dispose();
  }
}

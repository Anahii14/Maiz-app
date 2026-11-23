import 'package:command_it/command_it.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../_shared/errors/exceptions.dart';
import '../../analysis/manager/analysis_manager.dart';
import '../../analysis/model/analysis_dto.dart';
import '../../plants/manager/plants_manager.dart';
import '../../plants/model/plant_dto.dart';
import '../services/camera_service.dart';

class CameraManager {
  CameraManager({
    required CameraService cameraService,
    required PlantsManager plantsManager,
    required AnalysisManager analysisManager,
  }) : _cameraService = cameraService,
       _plantsManager = plantsManager,
       _analysisManager = analysisManager;

  final CameraService _cameraService;
  final PlantsManager _plantsManager;
  final AnalysisManager _analysisManager;

  final selectedPlantId = ValueNotifier<String?>(null);
  final capturedImage = ValueNotifier<XFile?>(null);

  /// Bytes de la foto elegida, para mostrar la vista previa.
  final capturedPreview = ValueNotifier<Uint8List?>(null);

  /// Solo hay modelo para hojas; "terreno" queda deshabilitado.
  final analysisType = ValueNotifier<AnalysisType>(AnalysisType.hoja);

  ValueListenable<List<PlantEntry>> get plants => _plantsManager.plants;

  Future<void> _setImage(XFile? image) async {
    if (image == null) return;
    capturedImage.value = image;
    capturedPreview.value = await image.readAsBytes();
  }

  late final pickFromCameraCommand = Command.createAsyncNoParamNoResult(
    () async => _setImage(await _cameraService.pickFromCamera()),
  );

  late final pickFromGalleryCommand = Command.createAsyncNoParamNoResult(
    () async => _setImage(await _cameraService.pickFromGallery()),
  );

  /// Analiza la foto con el modelo real y devuelve el resultado.
  late final analyzeCommand = Command.createAsyncNoParam<AnalysisOutcome?>(
    () async {
      final image = capturedImage.value;
      final plantId = selectedPlantId.value;
      if (image == null || plantId == null) {
        throw ServerException('Selecciona una planta y sube una imagen.');
      }
      final outcome = await _analysisManager.analyze(
        AnalysisRunRequest(plantId: plantId, image: image),
      );
      if (outcome.savedId != null) {
        // Guardado: limpiar para el siguiente análisis.
        capturedImage.value = null;
        capturedPreview.value = null;
      }
      return outcome;
    },
    initialValue: null,
  );

  void selectPlant(String? plantId) => selectedPlantId.value = plantId;

  void setAnalysisType(AnalysisType type) {
    // El modelo actual solo reconoce hojas.
    analysisType.value = AnalysisType.hoja;
  }

  void reset() {
    capturedImage.value = null;
    capturedPreview.value = null;
    selectedPlantId.value = null;
    analysisType.value = AnalysisType.hoja;
  }
}

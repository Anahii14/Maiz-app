import 'dart:async';

import 'package:command_it/command_it.dart';
import 'package:flutter/foundation.dart';

import '../../auth/model/app_user.dart';
import '../model/plant_dto.dart';
import '../services/plants_data_source.dart';

class PlantsManager {
  PlantsManager({required AppUser user, required PlantsDataSource service})
    : _user = user,
      _service = service;

  final AppUser _user;
  final PlantsDataSource _service;

  final plants = ValueNotifier<List<PlantEntry>>([]);

  StreamSubscription<List<PlantEntry>>? _subscription;

  late final savePlantCommand = Command.createAsync<PlantSaveRequest, String>((
    request,
  ) async {
    if (request.id == null) {
      return _service.create(_user.id, request.dto);
    }
    await _service.update(_user.id, request.id!, request.dto);
    return request.id!;
  }, initialValue: '');

  late final deletePlantCommand = Command.createAsync<String, bool>((
    plantId,
  ) async {
    await _service.delete(_user.id, plantId);
    return true;
  }, initialValue: false);

  /// Registra un riego. Se mantiene por compatibilidad: usa [waterPlant].
  late final updateWateringCommand =
      Command.createAsync<WateringUpdateRequest, bool>((request) async {
        await waterPlant(
          request.plantId,
          request.wateringDate,
          fallback: request.current,
        );
        return true;
      }, initialValue: false);

  /// Riego con ACTUALIZACIÓN OPTIMISTA:
  /// 1. La pantalla cambia al instante (se modifica [plants] en memoria).
  /// 2. Firestore guarda en segundo plano.
  /// 3. Si falla, se vuelve al estado anterior y el error llega a quien llamó.
  ///
  /// Siempre parte de la versión MÁS NUEVA de la planta (la de [plants]),
  /// así dos riegos seguidos no se pisan entre sí.
  Future<void> waterPlant(
    String plantId,
    DateTime wateringDate, {
    PlantDto? fallback,
  }) async {
    final before = plants.value;
    final index = before.indexWhere((p) => p.id == plantId);
    final current = index >= 0 ? before[index].dto : fallback;
    if (current == null) return;

    final history = PlantDto.mergeWateringHistory(
      current: current.wateringHistory,
      wateringDate: wateringDate,
    );
    final updated = current.copyWith(
      // El último riego es el más reciente, aunque se registre uno antiguo.
      lastWateringDate: history.first,
      wateringHistory: history,
    );

    if (index >= 0) {
      plants.value = [
        for (final p in before)
          p.id == plantId ? PlantEntry(id: plantId, dto: updated) : p,
      ];
    }

    try {
      await _service.updateWatering(_user.id, plantId, updated);
    } catch (e) {
      // Se deshace solo si nadie cambió la lista mientras tanto.
      if (index >= 0) {
        final now = plants.value;
        final i = now.indexWhere((p) => p.id == plantId);
        if (i >= 0 && identical(now[i].dto, updated)) {
          plants.value = [
            for (final p in now)
              p.id == plantId ? PlantEntry(id: plantId, dto: current) : p,
          ];
        }
      }
      debugPrint('[RIEGO] no se pudo guardar: $e');
      rethrow;
    }
  }

  Future<PlantsManager> init() async {
    _subscription = _service
        .watchPlants(_user.id)
        .listen(
          (entries) {
            plants.value = entries;
          },
          onError: (_) {
            plants.value = const [];
          },
        );
    return this;
  }

  void dispose() {
    _subscription?.cancel();
    plants.dispose();
  }
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_app/features/auth/model/app_user.dart';
import 'package:mi_app/features/plants/manager/plants_manager.dart';
import 'package:mi_app/features/plants/model/plant_dto.dart';
import 'package:mi_app/features/plants/model/plant_watering.dart';

import '../helpers/in_memory_plants_data_source.dart';

/// Fuente de datos cuyo guardado de riego tarda hasta que el test decide
/// (simula una conexión lenta), o falla.
class _SlowDataSource extends InMemoryPlantsDataSource {
  Completer<void>? pending;
  bool fail = false;

  @override
  Future<void> updateWatering(
    String userId,
    String plantId,
    PlantDto updated,
  ) async {
    pending = Completer<void>();
    await pending!.future;
    if (fail) throw Exception('sin internet');
    await super.updateWatering(userId, plantId, updated);
  }
}

PlantDto _plant({
  DateTime? planted,
  DateTime? last,
  List<DateTime> history = const [],
}) =>
    PlantDto(
      name: 'Lote Norte',
      location: '',
      notes: '',
      plantedDate: planted ?? DateTime(2026, 9, 1),
      lastWateringDate: last ?? DateTime(2026, 11, 10),
      wateringHistory: history,
    );

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('Regar: actualización optimista', () {
    const user = AppUser(id: 'u1', email: 'a@test.com', name: 'Test');
    late _SlowDataSource source;
    late PlantsManager manager;

    setUp(() async {
      source = _SlowDataSource();
      // Primero se guarda la planta y luego se escucha la lista.
      await source.create(user.id, _plant());
      manager = PlantsManager(user: user, service: source);
      await manager.init();
      await _settle();
    });

    tearDown(() {
      manager.dispose();
      source.dispose();
    });

    test('la lista cambia AL INSTANTE, antes de que termine el guardado', () async {
      final id = manager.plants.value.single.id;
      final day = DateTime(2026, 11, 23, 9);

      final saving = manager.waterPlant(id, day);

      // El guardado sigue pendiente…
      expect(source.pending!.isCompleted, isFalse);
      // …pero la planta ya muestra el riego.
      final dto = manager.plants.value.single.dto;
      expect(dto.lastWateringDate, day);
      expect(dto.wateringHistory.first, day);

      source.pending!.complete();
      await saving;
      expect(source.lastWateringUpdate!.lastWateringDate, day);
    });

    test('si falla el guardado, vuelve al estado anterior', () async {
      final id = manager.plants.value.single.id;
      final before = manager.plants.value.single.dto.lastWateringDate;
      source.fail = true;

      final saving = manager.waterPlant(id, DateTime(2026, 11, 23));
      expect(manager.plants.value.single.dto.lastWateringDate, isNot(before));

      source.pending!.complete();
      await expectLater(saving, throwsException);
      expect(manager.plants.value.single.dto.lastWateringDate, before);
    });

    test('dos riegos seguidos no se pisan (usa la versión más nueva)', () async {
      final id = manager.plants.value.single.id;
      final a = manager.waterPlant(id, DateTime(2026, 11, 21));
      source.pending!.complete();
      final b = manager.waterPlant(id, DateTime(2026, 11, 23));
      source.pending!.complete();
      await Future.wait([a, b]);

      final history = manager.plants.value.single.dto.wateringHistory;
      expect(history, contains(DateTime(2026, 11, 21)));
      expect(history.first, DateTime(2026, 11, 23));
    });

    test('regar dos veces el mismo día no duplica el riego', () {
      final merged = PlantDto.mergeWateringHistory(
        current: [DateTime(2026, 11, 23, 7)],
        wateringDate: DateTime(2026, 11, 23, 18),
      );
      expect(merged, [DateTime(2026, 11, 23, 18)]);
    });
  });

  group('Cálculo de riego y etapas', () {
    final now = DateTime(2026, 11, 23, 10);

    test('sin historial usa el intervalo por defecto (3 días)', () {
      final p = _plant(last: DateTime(2026, 11, 22));
      expect(p.wateringIntervalDays, WateringConfig.defaultIntervalDays);
      expect(p.daysUntilWatering(now), 2);
      expect(nextWateringText(p.daysUntilWatering(now)), 'En 2 días');
    });

    test('con historial usa el promedio entre riegos', () {
      final p = _plant(
        last: DateTime(2026, 11, 20),
        history: [
          DateTime(2026, 11, 20),
          DateTime(2026, 11, 18),
          DateTime(2026, 11, 16),
        ],
      );
      expect(p.wateringIntervalDays, 2);
      expect(p.daysUntilWatering(now), -1);
      expect(nextWateringText(-1), 'Atrasado 1 día');
    });

    test('textos de días', () {
      expect(nextWateringText(0), 'Hoy');
      expect(nextWateringText(1), 'Mañana');
      expect(daysAgoText(0), 'Hoy');
      expect(daysAgoText(1), 'Ayer');
      expect(daysAgoText(4), 'Hace 4 días');
    });

    test('nivel de agua: lleno al regar, vacío cuando toca', () {
      expect(_plant(last: DateTime(2026, 11, 23)).waterLevel(now), 1);
      expect(_plant(last: DateTime(2026, 11, 20)).waterLevel(now), 0);
    });

    test('etapas del maíz según los días desde la siembra', () {
      expect(CornStage.fromDays(3), CornStage.emergencia);
      expect(CornStage.fromDays(30), CornStage.crecimiento);
      expect(CornStage.fromDays(50), CornStage.floracion);
      expect(CornStage.fromDays(80), CornStage.llenado);
      expect(CornStage.fromDays(130), CornStage.madurez);
      expect(_plant(planted: DateTime(2026, 9, 24)).stage(now),
          CornStage.floracion);
    });
  });
}

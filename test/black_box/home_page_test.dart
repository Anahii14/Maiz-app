import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_app/features/home/pages/home_page.dart';
import 'package:mi_app/features/plants/manager/plants_manager.dart';
import 'package:mi_app/features/plants/model/plant_dto.dart';
import 'package:mi_app/locator.dart';

import '../helpers/in_memory_plants_data_source.dart';
import '../helpers/test_app.dart';

void main() {
  group('HomePage (caja negra)', () {
    late InMemoryPlantsDataSource dataSource;

    setUp(() async {
      await resetTestLocator();
      dataSource = InMemoryPlantsDataSource();
      await registerAuthForUi();
      registerPlantsSession(dataSource: dataSource);
    });

    tearDown(() async {
      dataSource.dispose();
      await resetTestLocator();
    });

    testWidgets('inicia en dashboard con navegacion inferior', (tester) async {
      await pumpTestApp(tester, home: const HomePage(), withAuth: false);
      await tester.pumpAndSettle();

      expect(find.text('¡Hola, agricultor!'), findsOneWidget);
      expect(find.text('Analizar hoja'), findsOneWidget);
      expect(find.text('Salud de tus plantas'), findsOneWidget);
      expect(find.text('Últimas detecciones'), findsOneWidget);
      expect(find.text('Inicio'), findsWidgets);
      expect(find.text('Nuevo'), findsOneWidget);
      // El Chat IA ya no está en la barra: solo es el botón flotante.
      expect(find.text('Chat IA'), findsNothing);
      expect(find.text('Mis Plantas'), findsWidgets);
      expect(find.text('Historial'), findsWidgets);
      expect(find.text('Biblioteca'), findsWidgets);
    });

    testWidgets('muestra seccion mis plantas al seleccionar Plantas', (
      tester,
    ) async {
      await pumpTestApp(tester, home: const HomePage(), withAuth: false);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mis Plantas').last);
      await tester.pumpAndSettle();

      // Título de la sección + etiqueta de la barra inferior.
      expect(find.text('Mis Plantas'), findsNWidgets(2));
      expect(find.text('Nueva Planta'), findsOneWidget);
    });

    testWidgets('los botones de la barra miden al menos 48 dp', (tester) async {
      await pumpTestApp(tester, home: const HomePage(), withAuth: false);
      await tester.pumpAndSettle();

      for (final label in ['Inicio', 'Mis Plantas', 'Historial', 'Biblioteca']) {
        final item = find.ancestor(
          of: find.text(label).last,
          matching: find.byType(InkWell),
        );
        final size = tester.getSize(item.first);
        expect(size.width, greaterThanOrEqualTo(48), reason: label);
        expect(size.height, greaterThanOrEqualTo(48), reason: label);
      }
    });

    testWidgets('el botón central Nuevo abre el análisis', (tester) async {
      await pumpTestApp(tester, home: const HomePage(), withAuth: false);
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Analizar hoja').first);
      await tester.pumpAndSettle();

      expect(find.text('Salud de tus plantas'), findsNothing);
    });

    testWidgets('Regar actualiza la tarjeta al instante', (tester) async {
      await dataSource.create(
        'test-user',
        PlantDto(
          name: 'Lote Sur',
          location: '',
          notes: '',
          plantedDate: DateTime.now().subtract(const Duration(days: 40)),
          lastWateringDate: DateTime.now().subtract(const Duration(days: 5)),
          wateringHistory: const [],
        ),
      );
      await getIt<PlantsManager>().init();
      await pumpTestApp(tester, home: const HomePage(), withAuth: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mis Plantas').last);
      await tester.pumpAndSettle();

      expect(find.text('Regado: hace 5 días'), findsOneWidget);
      await tester.tap(find.text('Regar').first);
      await tester.pump(); // un solo cuadro: sin esperar a la base de datos

      expect(find.text('Regado: hoy'), findsOneWidget);
      expect(find.textContaining('Riego registrado'), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });
}

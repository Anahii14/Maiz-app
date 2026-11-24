import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../../../_shared/theme/corn_palette.dart';
import '../manager/plants_manager.dart';

/// Registra un riego y avisa al usuario.
///
/// La pantalla se actualiza AL INSTANTE (el manager cambia la lista en
/// memoria); Firestore guarda en segundo plano. Si el guardado falla, la
/// lista vuelve a como estaba y se muestra un aviso.
void waterPlantNow(
  BuildContext context, {
  required String plantId,
  required String plantName,
  DateTime? date,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final when = date ?? DateTime.now();
  di<PlantsManager>().waterPlant(plantId, when).catchError((Object _) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar el riego. Revisa tu internet.'),
        ),
      );
  });
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            const Icon(Icons.water_drop_rounded, color: CornPalette.water),
            const SizedBox(width: 10),
            Expanded(child: Text('Riego registrado: $plantName')),
          ],
        ),
      ),
    );
}

/// Pide una fecha y registra un riego pasado.
Future<void> waterPlantOnDate(
  BuildContext context, {
  required String plantId,
  required String plantName,
}) async {
  final now = DateTime.now();
  final selected = await showDatePicker(
    context: context,
    initialDate: now,
    firstDate: DateTime(2018),
    lastDate: now,
    helpText: 'Fecha del riego',
  );
  if (selected == null || !context.mounted) return;
  waterPlantNow(
    context,
    plantId: plantId,
    plantName: plantName,
    date: selected,
  );
}

/// Botón "Regar" grande (mínimo 48 dp de alto).
class WaterButton extends StatelessWidget {
  final String plantId;
  final String plantName;
  final bool compact;

  const WaterButton({
    super.key,
    required this.plantId,
    required this.plantName,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: CornPalette.water,
        foregroundColor: Colors.white,
        minimumSize: Size(compact ? 48 : 120, 48),
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () =>
          waterPlantNow(context, plantId: plantId, plantName: plantName),
      icon: const Icon(Icons.water_drop_rounded, size: 20),
      label: const Text('Regar', style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'agotados.dart';
import 'calendario_ventas.dart';
import 'constants/colores.dart';
import 'databases/sync_service.dart';
import 'deudas.dart';
import 'nuevo_ingreso.dart';
import 'pedidos.dart';
import 'productos.dart';
import 'venta.dart';

class Inicio extends StatefulWidget {
  const Inicio({Key? key}) : super(key: key);

  @override
  State< Inicio > createState() => _InicioState();
}

class _InicioState extends State< Inicio > {
  String _seccionActual = 'venta';
  late final AppLifecycleListener _detectorCierreVentana;
  bool _guardandoManual = false;

  @override
  void initState() {
    super.initState();
    // Intercepta el clic en el botón [X] de la ventana de Windows
    _detectorCierreVentana = AppLifecycleListener(
      onExitRequested: _verificarCambiosAntesDeCerrar,
    );
  }

  @override
  void dispose() {
    _detectorCierreVentana.dispose();
    super.dispose();
  }

  /// 1. FILTRO DE SEGURIDAD TIPO OFFICE AL INTENTAR CERRAR LA VENTANA
  Future< AppExitResponse > _verificarCambiosAntesDeCerrar() async {
    if (!SyncService.instance.tieneCambiosPendientes &&
        !SyncService.instance.estaSincronizando) {
      return AppExitResponse.exit;
    }

    if (!mounted) return AppExitResponse.exit;

    final bool? deseaGuardarYSalir = await showDialog< bool >(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Cambios no guardados'),
          ],
        ),
        content: const Text(
          'Existen movimientos recientes que aún no se han respaldado en la nube.\n\n'
              '¿Deseas guardar y respaldar los cambios antes de cerrar el sistema?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Regresar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Guardar y cerrar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (deseaGuardarYSalir != true) {
      return AppExitResponse.cancel;
    }

    await _ejecutarRespaldoManual(mostrarMensajeExito: true);
    return AppExitResponse.exit;
  }

  /// 2. LÓGICA DEL BOTÓN "GUARDAR" CON MENSAJE DE CONFIRMACIÓN
  Future< void > _ejecutarRespaldoManual({bool mostrarMensajeExito = true}) async {
    if (_guardandoManual) return;
    setState(() => _guardandoManual = true);

    final bool exitoNube = await SyncService.instance.sincronizarTodo();

    if (!mounted) return;
    setState(() => _guardandoManual = false);

    if (mostrarMensajeExito) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                exitoNube ? Icons.check_circle : Icons.info_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  exitoNube
                      ? 'Datos respaldados correctamente'
                      : 'Datos guardados en equipo local (respaldo en nube pendiente por red)',
                ),
              ),
            ],
          ),
          backgroundColor: exitoNube ? Colors.green.shade700 : Colors.blueGrey,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 3. BOTÓN "GUARDAR" EN LA BARRA LATERAL (Donde antes estaba Excel)
  Widget _buildBotonGuardarLateral(bool isDrawer) {
    final bool hayPendientes = SyncService.instance.tieneCambiosPendientes;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton.icon(
          onPressed: _guardandoManual
              ? null
              : () {
            if (isDrawer) Navigator.pop(context);
            _ejecutarRespaldoManual();
          },
          icon: _guardandoManual
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : Icon(
            hayPendientes ? Icons.cloud_upload : Icons.save,
            size: 20,
          ),
          label: Text(
            _guardandoManual ? 'Guardando...' : 'Guardar',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.teal.shade900,
            disabledForegroundColor: Colors.white70,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenido() {
    switch (_seccionActual) {
      case 'venta':
        return const Venta();
      case 'deudas':
        return const Deudas();
      case 'calendario':
        return const CalendarioVentas();
      case 'pedidos':
        return const Pedidos();
      case 'anadir':
        return const NuevoIngreso();
      case 'agotados':
        return const Agotados();
      case 'consultar':
        return const Productos();
      default:
        return const Venta();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          appBar: isDesktop
              ? null
              : AppBar(
            backgroundColor: Colores.grisOscuro,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'KTOOLS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          drawer: isDesktop ? null : _buildSidebar(isDrawer: true),
          body: Row(
            children: [
              if (isDesktop) _buildSidebar(isDrawer: false),
              Expanded(
                child: Container(
                  color: Colors.grey[100],
                  child: _contenido(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar({required bool isDrawer}) {
    return Container(
      width: 230,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colores.grisOscuro,
            Color(0xFF0D1B2A),
          ],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 30),
          const Text(
            'KTOOLS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const Text(
            'Ksystem POS Desktop',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const Text(
            'By: Ferplace',
            style: TextStyle(color: Colors.grey, fontSize: 8),
          ),
          const SizedBox(height: 40),
          _buildMenuItem(Icons.point_of_sale, 'Venta', 'venta', isDrawer),
          _buildMenuItem(Icons.shopping_bag, 'Pedidos', 'pedidos', isDrawer),
          _buildMenuItem(Icons.money_off, 'Fiado', 'deudas', isDrawer),
          _buildMenuItem(Icons.calendar_month, 'Calendario', 'calendario', isDrawer),
          _buildMenuItem(Icons.add_circle_outline, 'Añadir', 'anadir', isDrawer),
          _buildMenuItem(Icons.warning_amber_rounded, 'Agotados', 'agotados', isDrawer),
          _buildMenuItem(Icons.list_alt, 'Consultar', 'consultar', isDrawer),
          const Divider(color: Colors.grey),
          _buildBotonGuardarLateral(isDrawer),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.only(left: 20, bottom: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'v2.5.0',
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
      IconData icon,
      String title,
      String seccion,
      bool isDrawer,
      ) {
    final bool isSelected = _seccionActual == seccion;

    BoxDecoration? decoration;
    const EdgeInsets margin = EdgeInsets.symmetric(horizontal: 12, vertical: 4);

    if (isSelected) {
      decoration = BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      );
    } else if (seccion == 'venta') {
      decoration = BoxDecoration(
        color: Colors.green.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.4),
          width: 1,
        ),
      );
    } else if (seccion == 'pedidos') {
      decoration = BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.4),
          width: 1,
        ),
      );
    } else if (seccion == 'anadir') {
      decoration = BoxDecoration(
        color: const Color(0xFF003366).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.2),
          width: 1,
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: decoration,
      child: ListTile(
        visualDensity: VisualDensity.compact,
        leading: Icon(
          icon,
          color: isSelected ? Colores.azulCielo : Colors.white,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colores.azulCielo : Colors.white,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() => _seccionActual = seccion);
          if (isDrawer) Navigator.pop(context);
        },
      ),
    );
  }
}
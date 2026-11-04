import 'package:flutter/material.dart';
import '../constants/colores.dart';
import '../Utils/formatters.dart';
import '../Utils/numeric_formatter.dart';

class ResultadoPago {
  final String metodoPago;
  final double recibido;
  final double cambio;

  const ResultadoPago({
    required this.metodoPago,
    required this.recibido,
    required this.cambio,
  });
}

class DialogoPago extends StatefulWidget {
  final double totalCobrar;
  final double efectivoInicial;

  const DialogoPago({
    Key? key,
    required this.totalCobrar,
    this.efectivoInicial = 0.0,
  }) : super(key: key);

  @override
  State<DialogoPago> createState() => _DialogoPagoState();
}

class _DialogoPagoState extends State<DialogoPago> {
  bool _modoCombinado = false;
  final List<String> _seleccionados = [];

  late TextEditingController _efectivoRecibidoCtrl;
  final TextEditingController _montoTarjetaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final double efIni = widget.efectivoInicial >= widget.totalCobrar
        ? widget.efectivoInicial
        : widget.totalCobrar;
    _efectivoRecibidoCtrl = TextEditingController(
      text: ThousandsSeparatorInputFormatter.format(efIni),
    );
  }

  @override
  void dispose() {
    _efectivoRecibidoCtrl.dispose();
    _montoTarjetaCtrl.dispose();
    super.dispose();
  }

  void _seleccionarMetodo(String metodo) {
    setState(() {
      if (!_modoCombinado) {
        _seleccionados
          ..clear()
          ..add(metodo);
      } else {
        if (_seleccionados.contains(metodo)) {
          _seleccionados.remove(metodo);
        } else if (_seleccionados.length < 2) {
          _seleccionados.add(metodo);
        }
      }
    });
  }

  void _alternarCombinado() {
    setState(() {
      _modoCombinado = !_modoCombinado;
      _seleccionados.clear();
      _montoTarjetaCtrl.clear();
    });
  }

  void _cambiarTodoAEfectivo() {
    setState(() {
      _modoCombinado = false;
      _seleccionados
        ..clear()
        ..add('Efectivo');
      _efectivoRecibidoCtrl.text =
          ThousandsSeparatorInputFormatter.format(widget.totalCobrar);
    });
  }

  bool get _involucraTarjeta =>
      _seleccionados.contains('Tarjeta de Crédito') ||
          _seleccionados.contains('Tarjeta de Débito');

  double get _montoTarjeta =>
      ThousandsSeparatorInputFormatter.parse(_montoTarjetaCtrl.text);

  double get _diferenciaRestante =>
      (widget.totalCobrar - _montoTarjeta).clamp(0.0, widget.totalCobrar);

  double get _efectivoRecibido =>
      ThousandsSeparatorInputFormatter.parse(_efectivoRecibidoCtrl.text);

  bool get _datosValidos {
    if (!_modoCombinado) {
      if (_seleccionados.length != 1) return false;
      if (_seleccionados.first == 'Efectivo') {
        return _efectivoRecibido >= widget.totalCobrar;
      }
      return true;
    } else {
      if (_seleccionados.length != 2) return false;
      if (_montoTarjeta <= 0 || _montoTarjeta >= widget.totalCobrar) return false;
      if (_seleccionados.contains('Efectivo')) {
        return _efectivoRecibido >= _diferenciaRestante;
      }
      return true;
    }
  }

  void _confirmarTransaccion() {
    if (!_datosValidos) return;

    String etiquetaFinal = '';
    double recibidoFinal = widget.totalCobrar;
    double cambioFinal = 0.0;

    if (!_modoCombinado) {
      etiquetaFinal = _seleccionados.first;
      if (etiquetaFinal == 'Efectivo') {
        recibidoFinal = _efectivoRecibido;
        cambioFinal = (recibidoFinal - widget.totalCobrar).clamp(0.0, double.infinity);
      }
    } else {
      final String m1 = _seleccionados[0];
      final String m2 = _seleccionados[1];
      if (_seleccionados.contains('Efectivo')) {
        final String tarjeta = m1 == 'Efectivo' ? m2 : m1;
        etiquetaFinal =
        'Combinado ($tarjeta: ${Formatters.formatearMoneda(_montoTarjeta)} + Efectivo: ${Formatters.formatearMoneda(_diferenciaRestante)})';
        recibidoFinal = _montoTarjeta + _efectivoRecibido;
        cambioFinal = (_efectivoRecibido - _diferenciaRestante).clamp(0.0, double.infinity);
      } else {
        etiquetaFinal =
        'Combinado ($m1: ${Formatters.formatearMoneda(_montoTarjeta)} + $m2: ${Formatters.formatearMoneda(_diferenciaRestante)})';
        recibidoFinal = widget.totalCobrar;
        cambioFinal = 0.0;
      }
    }

    Navigator.pop(
      context,
      ResultadoPago(
        metodoPago: etiquetaFinal,
        recibido: recibidoFinal,
        cambio: cambioFinal,
      ),
    );
  }

  Widget _botonMetodo({
    required String titulo,
    required IconData icono,
    required Color colorBase,
  }) {
    final bool activo = _seleccionados.contains(titulo);
    return InkWell(
      onTap: () => _seleccionarMetodo(titulo),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: activo ? colorBase.withValues(alpha: 0.16) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activo ? colorBase : Colors.grey.shade300,
            width: activo ? 3.0 : 1.2,
          ),
          boxShadow: activo
              ? [
            BoxShadow(
              color: colorBase.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : [],
        ),
        child: Row(
          children: [
            Icon(icono, color: colorBase, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titulo,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: activo ? FontWeight.bold : FontWeight.w600,
                  color: Colores.grisOscuro,
                ),
              ),
            ),
            if (activo) Icon(Icons.check_circle, color: colorBase, size: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Seleccionar Método de Pago',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colores.venta.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    const Text(
                      'TOTAL A COBRAR',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    Text(
                      Formatters.formatearMoneda(widget.totalCobrar),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colores.venta,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 3 botones organizados de arriba a abajo con la colorimetría del sistema
              _botonMetodo(
                titulo: 'Tarjeta de Crédito',
                icono: Icons.credit_card,
                colorBase: Colores.venta,
              ),
              const SizedBox(height: 10),
              _botonMetodo(
                titulo: 'Tarjeta de Débito',
                icono: Icons.payment,
                colorBase: Colores.calendario,
              ),
              const SizedBox(height: 10),
              _botonMetodo(
                titulo: 'Efectivo',
                icono: Icons.payments_outlined,
                colorBase: Colores.verde,
              ),
              const SizedBox(height: 20),
              // Cuarto botón ligeramente apartado para "Combinar pago"
              InkWell(
                onTap: _alternarCombinado,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _modoCombinado
                        ? Colores.pedidos.withValues(alpha: 0.18)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _modoCombinado ? Colores.pedidos : Colors.grey.shade400,
                      width: _modoCombinado ? 3.0 : 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.call_split,
                        color: _modoCombinado ? Colores.pedidos : Colores.grisOscuro,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _modoCombinado
                            ? 'MODO COMBINADO ACTIVO (Elige 2 opciones)'
                            : 'Combinar pago',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _modoCombinado ? Colores.pedidos : Colores.grisOscuro,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_modoCombinado && _seleccionados.contains('Efectivo')) ...[
                TextField(
                  controller: _efectivoRecibidoCtrl,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Efectivo recibido del cliente',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cambio a entregar: ${Formatters.formatearMoneda((_efectivoRecibido - widget.totalCobrar).clamp(0.0, double.infinity))}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colores.verde,
                  ),
                ),
              ],
              if (_modoCombinado && _seleccionados.length == 2 && _involucraTarjeta) ...[
                TextField(
                  controller: _montoTarjetaCtrl,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Monto a cobrar en ${_seleccionados.firstWhere((m) => m.contains("Tarjeta"))}',
                    prefixText: '\$',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    setState(() {
                      _efectivoRecibidoCtrl.text =
                          ThousandsSeparatorInputFormatter.format(_diferenciaRestante);
                    });
                  },
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Restante en ${_seleccionados.lastWhere((m) => m != _seleccionados.firstWhere((x) => x.contains("Tarjeta")))}: ${Formatters.formatearMoneda(_diferenciaRestante)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colores.verde),
                  ),
                ),
                if (_seleccionados.contains('Efectivo')) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _efectivoRecibidoCtrl,
                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Efectivo entregado por el cliente',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ],
              if (_seleccionados.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Confirme cuando el pago se haya efectuado.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (!(_seleccionados.length == 1 && _seleccionados.first == 'Efectivo'))
                        TextButton(
                          onPressed: _cambiarTodoAEfectivo,
                          child: const Text('Cambiar todo a Efectivo'),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colores.verde,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: _datosValidos ? _confirmarTransaccion : null,
          icon: const Icon(Icons.check_circle),
          label: const Text(
            'CONFIRMAR PAGO E IMPRIMIR',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'db_helper.dart';
import 'models/pedido.dart';
import 'models/producto.dart';
import 'constants/colores.dart';
import 'Utils/formatters.dart';
import 'Utils/impresion_ticket.dart';
import 'nuevo_ingreso.dart';

class Pedidos extends StatefulWidget {
  const Pedidos({Key? key}) : super(key: key);

  @override
  State<Pedidos> createState() => _PedidosState();
}

class _PedidosState extends State<Pedidos> {
  List<Pedido> _pedidos = [];
  List<Pedido> _filtrados = [];
  bool _cargando = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarPedidos();
    _searchController.addListener(_filtrarPedidos);
  }

  Future<void> _cargarPedidos() async {
    setState(() => _cargando = true);
    final db = await DBHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'pedidos', 
      orderBy: "CASE WHEN estado = 'pendiente' THEN 0 ELSE 1 END ASC, fecha_creacion DESC"
    );
    setState(() {
      _pedidos = maps.map((e) => Pedido.desdeMapa(e)).toList();
      _filtrados = _pedidos;
      _cargando = false;
    });
  }

  void _filtrarPedidos() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filtrados = _pedidos.where((p) {
        return p.clienteNombre.toLowerCase().contains(query) ||
               p.productoNombre.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PEDIDOS Y APARTADOS", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarPedidos),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Z-PATTERN: ACCIÓN PRINCIPAL ARRIBA A LA IZQUIERDA
                ElevatedButton.icon(
                  onPressed: _nuevoPedido,
                  icon: const Icon(Icons.add),
                  label: const Text("NUEVO PEDIDO"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 4,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Buscar interesado o producto...",
                        prefixIcon: const Icon(Icons.search, color: Colors.orange),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.orange, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _filtrados.isEmpty
                    ? const Center(child: Text("No se encontraron pedidos"))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filtrados.length,
                        itemBuilder: (context, index) {
                          final pedido = _filtrados[index];
                          return _buildPedidoCard(pedido);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPedidoCard(Pedido pedido) {
    bool entregado = pedido.estado == 'entregado';
    double pendiente = pedido.precioApartado - pedido.totalPagado;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: entregado ? Colors.green.withOpacity(0.5) : Colors.orange.withOpacity(0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Text(pedido.clienteNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Spacer(),
            _statusTag(entregado),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text("Producto: ${pedido.productoNombre}", style: const TextStyle(fontSize: 16)),
            Text("Contacto: ${pedido.clienteContacto}", style: const TextStyle(color: Colors.grey)),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniInfo("Total", Formatters.formatearMoneda(pedido.precioApartado)),
                _miniInfo("Pagado", Formatters.formatearMoneda(pedido.totalPagado), color: Colors.green),
                _miniInfo("Pendiente", Formatters.formatearMoneda(pendiente), color: pendiente > 0 ? Colors.red : Colors.grey),
              ],
            ),
          ],
        ),
        trailing: entregado
            ? IconButton(
                icon: const Icon(Icons.print, color: Colors.blue),
                onPressed: () => _reimprimirTicket(pedido),
              )
            : PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'entregar', child: Text("Registrar Entrega")),
                  const PopupMenuItem(value: 'reimprimir', child: Text("Reimprimir Comprobante")),
                  const PopupMenuItem(value: 'modificar', child: Text("Modificar")),
                  const PopupMenuItem(value: 'eliminar', child: Text("Eliminar", style: TextStyle(color: Colors.red))),
                ],
                onSelected: (val) {
                  if (val == 'entregar') _registrarEntrega(pedido);
                  if (val == 'reimprimir') _reimprimirTicket(pedido);
                  if (val == 'modificar') _modificarPedido(pedido);
                  if (val == 'eliminar') _eliminarPedido(pedido);
                },
              ),
      ),
    );
  }

  Widget _statusTag(bool entregado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: entregado ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: entregado ? Colors.green : Colors.orange),
      ),
      child: Text(
        entregado ? "ENTREGADO" : "PENDIENTE",
        style: TextStyle(color: entregado ? Colors.green[900] : Colors.orange[900], fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _miniInfo(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ],
    );
  }

    void _nuevoPedido() async {
    final TextEditingController nombreCtrl = TextEditingController();
    final TextEditingController contactoCtrl = TextEditingController();
    final TextEditingController productoCtrl = TextEditingController();
    final TextEditingController precioNormalCtrl = TextEditingController();
    final TextEditingController precioApartadoCtrl = TextEditingController();
    final TextEditingController costoCtrl = TextEditingController();
    final TextEditingController abonoCtrl = TextEditingController();
    final TextEditingController recibidoCtrl = TextEditingController();

    double descuento = 0;
    double cambio = 0;
    Producto? productoSeleccionado;

    showDialog(
      context: context,
      barrierDismissible: true, // Se cierra al cliquear fuera
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {

          void calcularDescuento() {
            double normal = double.tryParse(precioNormalCtrl.text) ?? 0;
            double apartado = double.tryParse(precioApartadoCtrl.text) ?? 0;
            if (normal > 0) {
              setDialogState(() {
                descuento = ((normal - apartado) / normal) * 100;
              });
            }
          }

          void calcularCambio() {
            double abono = double.tryParse(abonoCtrl.text) ?? 0;
            double recibido = double.tryParse(recibidoCtrl.text) ?? 0;
            setDialogState(() {
              cambio = recibido - abono;
            });
          }

          return AlertDialog(
            title: const Text("REGISTRAR NUEVO PEDIDO"),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(labelText: "Nombre del Cliente *", prefixIcon: Icon(Icons.person)),
                    ),
                    TextField(
                      controller: contactoCtrl,
                      decoration: const InputDecoration(labelText: "Teléfono o Correo *", prefixIcon: Icon(Icons.contact_mail)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: productoCtrl,
                            decoration: const InputDecoration(labelText: "Producto *", prefixIcon: Icon(Icons.shopping_bag)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search, color: Colors.blue),
                          onPressed: () async {
                             _buscarProductoExistente((p) {
                               setDialogState(() {
                                 productoSeleccionado = p;
                                 productoCtrl.text = p.descripcion;
                                 precioNormalCtrl.text = p.precio.toString();
                                 costoCtrl.text = p.costo.toString();
                               });
                               calcularDescuento();
                             });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.green),
                          onPressed: () {
                            Navigator.push<Producto?>(this.context, MaterialPageRoute(builder: (c) => const NuevoIngreso(esPicker: true))).then((nuevoP) {
                              if (nuevoP != null) {
                                setDialogState(() {
                                  productoSeleccionado = nuevoP;
                                  productoCtrl.text = nuevoP.descripcion;
                                  precioNormalCtrl.text = nuevoP.precio.toString();
                                  costoCtrl.text = nuevoP.costo.toString();
                                });
                                calcularDescuento();
                              }
                              _cargarPedidos();
                            });
                          },
                          tooltip: "Crear nuevo producto",
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: precioNormalCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Precio Público", prefixIcon: Icon(Icons.attach_money)),
                            onChanged: (_) => calcularDescuento(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: precioApartadoCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Precio Apartado", prefixIcon: Icon(Icons.local_offer)),
                            onChanged: (_) => calcularDescuento(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: costoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Costo de Adquisición *", prefixIcon: Icon(Icons.inventory, color: Colors.blueGrey)),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.trending_down, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text("Descuento calculado: ${descuento.toStringAsFixed(1)}%",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: abonoCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Anticipo *",
                                prefixIcon: Icon(Icons.payments, color: Colors.green),
                                labelStyle: TextStyle(fontWeight: FontWeight.bold)),
                            onChanged: (_) => calcularCambio(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: recibidoCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Dinero recibido *",
                                prefixIcon: Icon(Icons.account_balance_wallet, color: Colors.blue),
                                labelStyle: TextStyle(fontWeight: FontWeight.bold)),
                            onChanged: (_) => calcularCambio(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          const Text("CAMBIO A ENTREGAR:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(Formatters.formatearMoneda(cambio < 0 ? 0 : cambio),
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: cambio >= 0 ? Colors.green : Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
              ElevatedButton(
                onPressed: () async {
                  if (nombreCtrl.text.isEmpty || contactoCtrl.text.isEmpty || productoCtrl.text.isEmpty || abonoCtrl.text.isEmpty || costoCtrl.text.isEmpty || recibidoCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Por favor rellene los campos obligatorios (*)")));
                    return;
                  }
                  
                  double abono = double.tryParse(abonoCtrl.text) ?? 0;
                  double recibido = double.tryParse(recibidoCtrl.text) ?? 0;
                  double pNormal = double.tryParse(precioNormalCtrl.text) ?? 0;
                  double pApartado = double.tryParse(precioApartadoCtrl.text) ?? abono;
                  double costo = double.tryParse(costoCtrl.text) ?? 0;

                  if (recibido < abono) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("El dinero recibido es menor al abono")));
                    return;
                  }
                  
                  final pedido = Pedido(
                    clienteNombre: nombreCtrl.text,
                    clienteContacto: contactoCtrl.text,
                    productoNombre: productoCtrl.text,
                    productoSku: productoSeleccionado?.sku ?? "N/A",
                    precioNormal: pNormal,
                    precioApartado: pApartado,
                    abonoInicial: abono,
                    totalPagado: abono,
                    costo: costo,
                    descuento: descuento,
                    fechaCreacion: DateTime.now().toString(),
                    estado: 'pendiente',
                  );

                  // 1. Guardar en tabla pedidos
                  final db = await DBHelper.instance.database;
                  int id = await db.insert('pedidos', pedido.aMapa());
                  pedido.id = id;

                  // 2. Registrar en historial de ventas
                  int folioVenta = await _registrarEnHistorial(pedido, abono, false);

                  // 3. Imprimir directamente
                  await ImpresionTicket.imprimirTicketPedido(
                    pedido: pedido,
                    montoPagadoMomento: abono,
                    recibido: recibido,
                    cambio: recibido - abono,
                    isLiquidacion: false,
                  );

                  Navigator.pop(ctx);
                  _cargarPedidos();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, 
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold)
                ),
                child: const Text("GENERAR TICKET Y GUARDAR"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _guardarPedido(Pedido pedido, double montoPagado) async {
    final db = await DBHelper.instance.database;
    
    // 1. Guardar en tabla pedidos
    int id = await db.insert('pedidos', pedido.aMapa());
    pedido.id = id;

    // 2. Registrar en historial de ventas para el calendario
    int folioVenta = await _registrarEnHistorial(pedido, montoPagado, false);

    // 3. Imprimir Ticket
    await _lanzarTicket(pedido, montoPagado, false, folioVenta);
  }

  Future<int> _registrarEnHistorial(Pedido pedido, double montoPagado, bool esLiquidacion) async {
    final db = await DBHelper.instance.database;
    
    String concepto = esLiquidacion 
        ? "Liquidación de apartado: ${pedido.clienteNombre}" 
        : "Apartado de: ${pedido.clienteNombre}";

    // Creamos un item JSON para que sea compatible con el calendario/reimpresión
    final item = {
      'sku': pedido.productoSku,
      'descripcion': "APARTADO: ${pedido.productoNombre}",
      'cantidad': 1,
      'precio': montoPagado,
      'costo': esLiquidacion ? 0 : pedido.costo, // Solo contamos el costo una vez
    };

    int idGenerado = await db.insert('ventas_historial', {
      'folio_venta': 0, // Folio temporal
      'fecha': DateTime.now().toString(),
      'total': montoPagado,
      'costo_total': esLiquidacion ? 0 : pedido.costo,
      'items': jsonEncode([item]),
      'cliente': concepto,
      'recibido': montoPagado,
      'cambio': 0,
      'es_activo': 1
    });

    // Actualizamos el folio_venta para que sea el ID generado
    await db.update(
        'ventas_historial',
        {'folio_venta': idGenerado},
        where: 'id = ?',
        whereArgs: [idGenerado]
    );

    return idGenerado;
  }

  Future<void> _lanzarTicket(Pedido pedido, double montoPagado, bool esLiquidacion, int folioVenta) async {
     // Diálogo para recibido/cambio antes de imprimir
     double recibido = montoPagado;
     double cambio = 0;

     await showDialog(
       context: context,
       builder: (ctx) {
         final TextEditingController recCtrl = TextEditingController(text: montoPagado.toString());
         return AlertDialog(
           title: const Text("Pago recibido"),
           content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               Text("Total a cobrar en este momento: ${Formatters.formatearMoneda(montoPagado)}", style: const TextStyle(fontWeight: FontWeight.bold)),
               const SizedBox(height: 15),
               TextField(
                 controller: recCtrl,
                 keyboardType: TextInputType.number,
                 autofocus: true,
                 decoration: const InputDecoration(labelText: "Efectivo Recibido", border: OutlineInputBorder()),
                 onChanged: (v) {
                 },
               ),
             ],
           ),
           actions: [
             ElevatedButton(
               onPressed: () {
                 recibido = double.tryParse(recCtrl.text) ?? montoPagado;
                 cambio = recibido - montoPagado;
                 Navigator.pop(ctx);
               },
               child: const Text("Confirmar e Imprimir"),
             )
           ],
         );
       }
     );

     await ImpresionTicket.imprimirTicketPedido(
       pedido: pedido,
       montoPagadoMomento: montoPagado,
       recibido: recibido,
       cambio: cambio,
       isLiquidacion: esLiquidacion,
     );
  }

  void _registrarEntrega(Pedido pedido) async {
    double restante = pedido.precioApartado - pedido.totalPagado;
    final TextEditingController recCtrl = TextEditingController();
    double cambio = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("REGISTRAR ENTREGA"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _infoRow("Total Pedido:", Formatters.formatearMoneda(pedido.precioApartado)),
                _infoRow("Ya pagado:", Formatters.formatearMoneda(pedido.totalPagado), color: Colors.green),
                const Divider(),
                _infoRow("MONTO RESTANTE:", Formatters.formatearMoneda(restante), color: Colors.red, bold: true),
                const SizedBox(height: 20),
                TextField(
                  controller: recCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                  decoration: const InputDecoration(
                    labelText: "Dinero recibido",
                    prefixIcon: Icon(Icons.payments),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    double r = double.tryParse(v) ?? 0;
                    setDialogState(() {
                      cambio = r - restante;
                    });
                  },
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      const Text("CAMBIO A ENTREGAR:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(Formatters.formatearMoneda(cambio < 0 ? 0 : cambio),
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: cambio >= 0 ? Colors.green : Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
              ElevatedButton(
                onPressed: cambio < 0 ? null : () async {
                  final db = await DBHelper.instance.database;
                  
                  // Actualizar pedido
                  pedido.totalPagado = pedido.precioApartado;
                  pedido.estado = 'entregado';
                  pedido.fechaEntrega = DateTime.now().toString();
                  
                  await db.update('pedidos', pedido.aMapa(), where: 'id = ?', whereArgs: [pedido.id]);

                  // Registrar liquidación en historial y obtener folio
                  int folioVenta = await _registrarEnHistorial(pedido, restante, true);

                  // Imprimir Ticket
                  await ImpresionTicket.imprimirTicketPedido(
                    pedido: pedido,
                    montoPagadoMomento: restante,
                    recibido: double.tryParse(recCtrl.text) ?? restante,
                    cambio: cambio,
                    isLiquidacion: true,
                  );

                  Navigator.pop(ctx);
                  _cargarPedidos();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: const Text("LIQUIDAR Y ENTREGAR"),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: bold ? 18 : 14)),
        ],
      ),
    );
  }

  void _reimprimirTicket(Pedido pedido) async {
    // Si ya está entregado, el monto pagado en el momento de liquidación fue (precioApartado - abonoInicial)
    double montoEnLiquidacion = pedido.precioApartado - pedido.abonoInicial;

    await ImpresionTicket.imprimirTicketPedido(
      pedido: pedido,
      montoPagadoMomento: pedido.estado == 'entregado' ? montoEnLiquidacion : pedido.abonoInicial,
      recibido: pedido.estado == 'entregado' ? montoEnLiquidacion : pedido.abonoInicial,
      cambio: 0,
      isLiquidacion: pedido.estado == 'entregado',
      isCopy: true,
    );
  }

  void _modificarPedido(Pedido pedido) {
    final TextEditingController nombreCtrl = TextEditingController(text: pedido.clienteNombre);
    final TextEditingController contactoCtrl = TextEditingController(text: pedido.clienteContacto);
    final TextEditingController productoCtrl = TextEditingController(text: pedido.productoNombre);
    final TextEditingController precioNormalCtrl = TextEditingController(text: pedido.precioNormal.toString());
    final TextEditingController precioApartadoCtrl = TextEditingController(text: pedido.precioApartado.toString());
    final TextEditingController costoCtrl = TextEditingController(text: pedido.costo.toString());
    final TextEditingController abonoCtrl = TextEditingController(text: pedido.abonoInicial.toString());

    double descuento = pedido.descuento;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          void calcularDescuento() {
            double normal = double.tryParse(precioNormalCtrl.text) ?? 0;
            double apartado = double.tryParse(precioApartadoCtrl.text) ?? 0;
            if (normal > 0) {
              setDialogState(() {
                descuento = ((normal - apartado) / normal) * 100;
              });
            }
          }

          return AlertDialog(
            title: const Text("MODIFICAR PEDIDO"),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Nombre del Cliente *")),
                    TextField(controller: contactoCtrl, decoration: const InputDecoration(labelText: "Teléfono o Correo *")),
                    TextField(controller: productoCtrl, decoration: const InputDecoration(labelText: "Producto *")),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: precioNormalCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Precio Público"),
                            onChanged: (_) => calcularDescuento(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: precioApartadoCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Precio Apartado"),
                            onChanged: (_) => calcularDescuento(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: costoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Costo *")),
                    TextField(controller: abonoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Abono Inicial *")),
                    const SizedBox(height: 10),
                    Text("Descuento: ${descuento.toStringAsFixed(1)}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
              ElevatedButton(
                onPressed: () async {
                  pedido.clienteNombre = nombreCtrl.text;
                  pedido.clienteContacto = contactoCtrl.text;
                  pedido.productoNombre = productoCtrl.text;
                  pedido.precioNormal = double.tryParse(precioNormalCtrl.text) ?? 0;
                  pedido.precioApartado = double.tryParse(precioApartadoCtrl.text) ?? 0;
                  pedido.costo = double.tryParse(costoCtrl.text) ?? 0;
                  pedido.abonoInicial = double.tryParse(abonoCtrl.text) ?? 0;
                  pedido.totalPagado = pedido.abonoInicial; // Reset total pagado al nuevo abono si es pendiente
                  pedido.descuento = descuento;

                  final db = await DBHelper.instance.database;
                  await db.update('pedidos', pedido.aMapa(), where: 'id = ?', whereArgs: [pedido.id]);
                  
                  Navigator.pop(ctx);
                  _cargarPedidos();
                },
                child: const Text("GUARDAR CAMBIOS"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _eliminarPedido(Pedido pedido) async {
    bool? confirmar = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar pedido?"),
        content: Text("Se eliminará el registro de ${pedido.clienteNombre}. Esta acción no se puede deshacer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("ELIMINAR"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final db = await DBHelper.instance.database;
      await db.delete('pedidos', where: 'id = ?', whereArgs: [pedido.id]);
      _cargarPedidos();
    }
  }

  void _buscarProductoExistente(Function(Producto) onSelected) async {
    final TextEditingController searchCtrl = TextEditingController();
    List<Producto> resultados = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Buscar Producto"),
            content: SizedBox(
              width: 400,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: "Nombre, SKU o Ubicación..."),
                    onChanged: (v) async {
                      var res = await DBHelper.instance.buscarParaSeleccionManual(v);
                      setDialogState(() { resultados = res; });
                    },
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: resultados.length,
                      itemBuilder: (c, i) {
                        final p = resultados[i];
                        return ListTile(
                          title: Text(p.descripcion),
                          subtitle: Text("SKU: ${p.sku} - Stock: ${p.stock}"),
                          trailing: Text(Formatters.formatearMoneda(p.precio), style: const TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () {
                            onSelected(p);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          );
        }
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'databases/history_db.dart';
import 'constants/colores.dart';

class HistorialVentas extends StatefulWidget {
  const HistorialVentas({Key? key}) : super(key: key);

  @override
  State<HistorialVentas> createState() => _HistorialVentasState();
}

class _HistorialVentasState extends State<HistorialVentas> {
  String _query = "";
  bool _verCaducados = false;
  List<Map<String, dynamic>> _ventas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final datos = await HistoryDB.instance.buscarVentas(_query, !_verCaducados);
    setState(() {
      _ventas = datos;
      _cargando = false;
    });
  }

  Future<void> _editarCliente(int id, String nombreActual) async {
    TextEditingController _ctrl = TextEditingController(text: nombreActual);
    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Editar Cliente"),
          content: TextField(controller: _ctrl, decoration: const InputDecoration(labelText: "Nombre", border: OutlineInputBorder())),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
                onPressed: () async {
                  await HistoryDB.instance.asignarNombreCliente(id, _ctrl.text);
                  _cargarDatos();
                  Navigator.pop(ctx);
                },
                child: const Text("Guardar")
            )
          ],
        )
    );
  }

  // --- MISMA FUNCIÓN DE DETALLE QUE EN VENTAS DEL DÍA ---
  void _verReciboDetalle(Map<String, dynamic> venta) {
    String itemsRaw = venta['items'] ?? "";
    List<String> listaItems = itemsRaw.split('|');

    showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Detalle de Venta (Histórico)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                Text("Folio: #${venta['folio_venta']}  |  Fecha: ${venta['fecha']}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 10),

                // LISTA
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: listaItems.length,
                    itemBuilder: (context, i) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                        child: Text("• ${listaItems[i].trim()}"),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: Text("Total: \$${venta['total'].toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                const SizedBox(height: 15),
                ElevatedButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cerrar"))
              ],
            ),
          ),
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- BARRA SUPERIOR ---
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.grey[100],
          child: Row(
            children: [
              const Icon(Icons.history_edu, size: 28, color: Colors.blueGrey),
              const SizedBox(width: 10),
              const Text("Bitácora Histórica", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(width: 20),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: "Buscar por Folio o Cliente...",
                      border: OutlineInputBorder(),
                      filled: true, fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(vertical: 0)
                  ),
                  onChanged: (v) {
                    _query = v;
                    _cargarDatos();
                  },
                ),
              ),
              const SizedBox(width: 20),
              Row(children: [
                Checkbox(value: _verCaducados, onChanged: (v) { setState(() => _verCaducados = v!); _cargarDatos(); }),
                const Text("Ver Archivo Muerto (>2 años)")
              ])
            ],
          ),
        ),

        // --- TABLA ---
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _ventas.isEmpty
              ? const Center(child: Text("No se encontraron registros.", style: TextStyle(fontSize: 18, color: Colors.grey)))
              : SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.blueGrey[50]),
                dataRowHeight: 60,
                columns: const [
                  DataColumn(label: Text("Folio")),
                  DataColumn(label: Text("Fecha")),
                  DataColumn(label: Text("Cliente")),
                  DataColumn(label: Text("Resumen (Vista Previa)")), // Muestra con pipes
                  DataColumn(label: Text("Total")),
                  DataColumn(label: Text("Estado")),
                  DataColumn(label: Text("Acciones")),
                ],
                rows: _ventas.map((v) {
                  bool esActivo = v['es_activo'] == 1;
                  String itemsPreview = v['items'] ?? "";
                  if(itemsPreview.length > 40) itemsPreview = itemsPreview.substring(0, 37) + "...";

                  return DataRow(
                      color: MaterialStateProperty.resolveWith<Color?>((states) => !esActivo ? Colors.orange[50] : null),
                      cells: [
                        DataCell(Text("#${v['folio_venta']}", style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(v['fecha'].toString().split(' ')[0])), // Solo fecha corta
                        DataCell(InkWell(
                          onTap: () => _editarCliente(v['id'], v['cliente']),
                          child: Row(children: [Text(v['cliente']), const Icon(Icons.edit, size: 12, color: Colors.grey)]),
                        )),
                        DataCell(Text(itemsPreview, style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic))),
                        DataCell(Text("\$${v['total'].toStringAsFixed(2)}", style: TextStyle(color: Colores.azulPrincipal, fontWeight: FontWeight.bold))),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: esActivo ? Colors.green[100] : Colors.orange[100], borderRadius: BorderRadius.circular(10)),
                          child: Text(esActivo ? "Vigente" : "Caducado", style: TextStyle(fontSize: 10, color: esActivo ? Colors.green[800] : Colors.orange[800])),
                        )),
                        DataCell(
                          // BOTÓN VER RECIBO
                            IconButton(
                              icon: const Icon(Icons.receipt, color: Colors.blue),
                              tooltip: "Ver Recibo Detallado",
                              onPressed: () => _verReciboDetalle(v),
                            )
                        ),
                      ]
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
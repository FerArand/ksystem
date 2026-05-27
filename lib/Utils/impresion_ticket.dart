import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'formatters.dart';
import '../models/pedido.dart';

import '../models/item_venta.dart' as modelo;

class ImpresionTicket {

  static Future<void> imprimirTicketAbono({
    required String nombreDeudor,
    required List<modelo.ItemVenta> items,
    required double montoAbonado,
    required double deudaAnterior,
    required double saldoRestante,
    double recibido = 0,
    double cambio = 0,
    bool isCopy = false,
  }) async {
    final doc = pw.Document();
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    const PdfPageFormat formatoTicket = PdfPageFormat(
        58 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 0
    );

    doc.addPage(
      pw.Page(
          pageFormat: formatoTicket,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(left: 0, right: 15 * PdfPageFormat.mm),
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.SizedBox(height: 5 * PdfPageFormat.mm),

                    pw.Text('KTOOLS',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),

                    pw.Text(isCopy ? 'COPIA COMPROBANTE DE ABONO' : 'COMPROBANTE DE ABONO',
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),

                    pw.SizedBox(height: 2),
                    pw.Text('Blvrd Miguel Hidalgo 2135A, Valle de Leon, 37140 Guanajuato, Gto.',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 6)),

                    pw.SizedBox(height: 5),
                    if (isCopy)
                      pw.Text('--- COPIA DEL ORIGINAL ---', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    
                    pw.Text(fecha, style: const pw.TextStyle(fontSize: 7)),
                    pw.Text('Cliente: $nombreDeudor',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),

                    pw.Divider(borderStyle: pw.BorderStyle.dashed),

                    pw.Text('DETALLE DE DEUDA:',
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),

                    ...items.map((item) {
                      return pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 2),
                          child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Expanded(flex: 1, child: pw.Text('${item.cantidad}x', style: const pw.TextStyle(fontSize: 6))),
                                pw.Expanded(flex: 3, child: pw.Text(item.descripcion, maxLines: 2, style: const pw.TextStyle(fontSize: 6))),
                                pw.Expanded(flex: 1, child: pw.Text(Formatters.formatearMoneda(item.precio * item.cantidad), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 6))),
                              ]
                          )
                      );
                    }).toList(),

                    pw.Divider(borderStyle: pw.BorderStyle.dashed),

                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('DEUDA TOTAL:', style: const pw.TextStyle(fontSize: 7)),
                          pw.Text(Formatters.formatearMoneda(deudaAnterior), style: const pw.TextStyle(fontSize: 7)),
                        ]
                    ),
                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('SU ABONO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                          pw.Text(Formatters.formatearMoneda(montoAbonado), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        ]
                    ),
                    if (recibido > 0) ...[
                      pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('EFECTIVO:', style: const pw.TextStyle(fontSize: 7)),
                            pw.Text(Formatters.formatearMoneda(recibido), style: const pw.TextStyle(fontSize: 7)),
                          ]
                      ),
                      pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('CAMBIO:', style: const pw.TextStyle(fontSize: 7)),
                            pw.Text(Formatters.formatearMoneda(cambio), style: const pw.TextStyle(fontSize: 7)),
                          ]
                      ),
                    ],

                    pw.Divider(borderStyle: pw.BorderStyle.dashed),

                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('SALDO RESTANTE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                          pw.Text(Formatters.formatearMoneda(saldoRestante), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        ]
                    ),

                    pw.SizedBox(height: 10),
                    pw.Text('Gracias por su preferencia',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                    pw.SizedBox(height: 10 * PdfPageFormat.mm),
                  ]
              ),
            );
          }
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Abono_$nombreDeudor',
    );
  }

  static Future<void> imprimirTicketPedido({
    required Pedido pedido,
    required double montoPagadoMomento,
    required double recibido,
    required double cambio,
    bool isLiquidacion = false,
    bool isCopy = false,
  }) async {
    final doc = pw.Document();
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    const PdfPageFormat formatoTicket = PdfPageFormat(
        58 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 0
    );

    doc.addPage(
      pw.Page(
          pageFormat: formatoTicket,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(left: 0, right: 15 * PdfPageFormat.mm),
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.SizedBox(height: 5 * PdfPageFormat.mm),

                    pw.Text('KTOOLS',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),

                    pw.Text(isCopy ? (isLiquidacion ? 'COPIA LIQUIDACIÓN PEDIDO' : 'COPIA COMPROBANTE PEDIDO') : (isLiquidacion ? 'LIQUIDACIÓN DE PEDIDO' : 'COMPROBANTE DE PEDIDO'),
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),

                    pw.SizedBox(height: 2),
                    pw.Text('Blvrd Miguel Hidalgo 2135A, Valle de Leon, 37140 Guanajuato, Gto.',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 6)),

                    pw.SizedBox(height: 5),
                    if (isCopy)
                      pw.Text('--- COPIA DEL ORIGINAL ---', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    
                    pw.Text(fecha, style: const pw.TextStyle(fontSize: 7)),
                    pw.Text('Cliente: ${pedido.clienteNombre}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),

                    pw.Divider(borderStyle: pw.BorderStyle.dashed),

                    pw.Text('DETALLE DEL PEDIDO:',
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),

                    pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(flex: 3, child: pw.Text(pedido.productoNombre, maxLines: 2, style: const pw.TextStyle(fontSize: 7))),
                          pw.Expanded(flex: 1, child: pw.Text(Formatters.formatearMoneda(pedido.precioApartado), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7))),
                        ]
                    ),

                    pw.Divider(borderStyle: pw.BorderStyle.dashed),

                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('PRECIO TOTAL:', style: const pw.TextStyle(fontSize: 7)),
                          pw.Text(Formatters.formatearMoneda(pedido.precioApartado), style: const pw.TextStyle(fontSize: 7)),
                        ]
                    ),
                    
                    if (!isLiquidacion) ...[
                      pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('ABONO INICIAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                            pw.Text(Formatters.formatearMoneda(montoPagadoMomento), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                          ]
                      ),
                      pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('SALDO PENDIENTE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                            pw.Text(Formatters.formatearMoneda(pedido.precioApartado - pedido.totalPagado), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                          ]
                      ),
                    ] else ...[
                      pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAL PAGADO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                            pw.Text(Formatters.formatearMoneda(pedido.totalPagado), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                          ]
                      ),
                      pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('ESTADO:', style: const pw.TextStyle(fontSize: 7)),
                            pw.Text('LIQUIDADO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.green)),
                          ]
                      ),
                    ],

                    pw.SizedBox(height: 5),
                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('EFECTIVO RECIBIDO:', style: const pw.TextStyle(fontSize: 7)),
                          pw.Text(Formatters.formatearMoneda(recibido), style: const pw.TextStyle(fontSize: 7)),
                        ]
                    ),
                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('CAMBIO:', style: const pw.TextStyle(fontSize: 7)),
                          pw.Text(Formatters.formatearMoneda(cambio), style: const pw.TextStyle(fontSize: 7)),
                        ]
                    ),

                    pw.SizedBox(height: 10),
                    pw.Text('Gracias por su preferencia',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                    pw.SizedBox(height: 10 * PdfPageFormat.mm),
                  ]
              ),
            );
          }
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Pedido_${pedido.clienteNombre}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    );
  }
  
  static Future<void> imprimirTicket({
    required List<modelo.ItemVenta> items,
    required double total,
    required double recibido,
    required double cambio,
    required dynamic folioVenta,
    String? fechaOriginal, 
    bool isCopy = false,
    String? nombreCliente,
    List<modelo.ItemVenta>? itemsDevueltos, 
  }) async {
    
    final doc = pw.Document();
    final fechaActual = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final fechaMostrar = fechaOriginal ?? fechaActual;

    // Calcular total devuelto si existe
    double montoDevueltoTotal = 0;
    if (itemsDevueltos != null) {
      for (var item in itemsDevueltos) {
        montoDevueltoTotal += (item.precio * item.cantidad);
      }
    }

    const PdfPageFormat formatoTicket = PdfPageFormat(
      58 * PdfPageFormat.mm, 
      double.infinity, 
      marginAll: 0
    );

    doc.addPage(
      pw.Page(
        pageFormat: formatoTicket,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(left: 0, right: 15 * PdfPageFormat.mm), 
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.SizedBox(height: 5 * PdfPageFormat.mm), 
                
                // ENCABEZADO
                pw.Text('KTOOLS', 
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                
                pw.Text(isCopy 
                    ? (nombreCliente != null ? 'COPIA - VENTA A CRÉDITO' : 'COPIA - FERREELÉCTRICA')
                    : (nombreCliente != null ? 'VENTA A CRÉDITO' : 'FERREELÉCTRICA'), 
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                
                pw.SizedBox(height: 2),
                pw.Text('Blvrd Miguel Hidalgo 2135A, Valle de Leon, 37140 Guanajuato, Gto.',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 6)),

                if (itemsDevueltos != null || folioVenta.toString().endsWith('M')) ...[
                  pw.SizedBox(height: 2),
                  pw.Text('Ticket de devolución', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],

                pw.SizedBox(height: 5),
                if (isCopy && !(itemsDevueltos != null || folioVenta.toString().endsWith('M')))
                  pw.Text('--- COPIA DEL ORIGINAL ---', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),

                if (fechaOriginal != null) 
                  pw.Text('FECHA ORIGINAL:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                
                pw.Text(fechaMostrar, style: const pw.TextStyle(fontSize: 7)),
                
                if (nombreCliente != null)
                  pw.Text('Cliente: $nombreCliente',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),

                pw.Text('Folio Venta: #$folioVenta', 
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                
                pw.Divider(borderStyle: pw.BorderStyle.dashed),

                // LISTA DE PRODUCTOS (Encabezados)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(flex: 1, child: pw.Text('Cant', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 3, child: pw.Text('Art', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 1, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold))),
                  ]
                ),
                pw.SizedBox(height: 4),

                // ITEMS ACTUALES
                ...items.map((item) {
                  final subtotal = item.precio * item.cantidad;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(flex: 1, child: pw.Text('${item.cantidad}', style: const pw.TextStyle(fontSize: 6))),
                        pw.Expanded(flex: 3, child: pw.Text(item.descripcion, maxLines: 2, style: const pw.TextStyle(fontSize: 6))),
                        pw.Expanded(flex: 1, child: pw.Text(Formatters.formatearMoneda(subtotal), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 6))),
                      ]
                    )
                  );
                }).toList(),

                if (itemsDevueltos != null && itemsDevueltos.isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Text('PRODUCTOS DEVUELTOS:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  ...itemsDevueltos.map((item) {
                    final subtotal = item.precio * item.cantidad;
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(flex: 1, child: pw.Text('${item.cantidad}', style: const pw.TextStyle(fontSize: 6))),
                          pw.Expanded(flex: 3, child: pw.Text(item.descripcion, maxLines: 2, style: const pw.TextStyle(fontSize: 6, decoration: pw.TextDecoration.lineThrough))),
                          pw.Expanded(flex: 1, child: pw.Text('-${Formatters.formatearMoneda(subtotal)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 6))),
                        ]
                      )
                    );
                  }).toList(),
                ],

                pw.Divider(borderStyle: pw.BorderStyle.dashed),

                // TOTALES
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL ACTUAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    pw.Text(Formatters.formatearMoneda(total), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  ]
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Recibido original:', style: const pw.TextStyle(fontSize: 7)),
                      pw.Text(Formatters.formatearMoneda(recibido), style: const pw.TextStyle(fontSize: 7)),
                    ]
                ),
                if (itemsDevueltos != null || folioVenta.toString().endsWith('M')) ...[
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Monto devuelto:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text(Formatters.formatearMoneda(montoDevueltoTotal), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ]
                  ),
                ],
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Cambio Original:', style: pw.TextStyle(fontSize: 6)),
                      pw.Text(Formatters.formatearMoneda(cambio), style: pw.TextStyle(fontSize: 6)),
                    ]
                ),

                pw.SizedBox(height: 10),
                pw.Text('Gracias por su preferencia', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                
                if (fechaOriginal != null) ...[
                   pw.SizedBox(height: 4),
                   pw.Text('Copia impresa el: $fechaActual', style: const pw.TextStyle(fontSize: 6)),
                ],

                pw.Divider(borderStyle: pw.BorderStyle.dashed),
                
                // DISCLAIMERS
                pw.Text('Este no es comprobante fiscal', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                pw.SizedBox(height: 5),
                pw.Text(
                  '15 días de garantía por defecto de fábrica. No cubre daños por mala instalación o uso. En electrónicos no se aceptan cambios ni devoluciones.',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 6), 
                ),
                pw.SizedBox(height: 10 * PdfPageFormat.mm),
              ]
            ),
          );
        }
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Ticket_$folioVenta',
    );
  }

  static Future<List<int>> generarPdfTicket({
    required List<modelo.ItemVenta> items,
    required double total,
    required double recibido,
    required double cambio,
    required dynamic folioVenta,
    String? fechaOriginal,
    String? nombreCliente,
    List<modelo.ItemVenta>? itemsDevueltos,
  }) async {
    final doc = pw.Document();
    final fechaActual = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final fechaMostrar = fechaOriginal ?? fechaActual;

    // Calcular total devuelto si existe
    double montoDevueltoTotal = 0;
    if (itemsDevueltos != null) {
      for (var item in itemsDevueltos) {
        montoDevueltoTotal += (item.precio * item.cantidad);
      }
    }

    const PdfPageFormat formatoTicket = PdfPageFormat(
        58 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 0
    );

    doc.addPage(
      pw.Page(
          pageFormat: formatoTicket,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(left: 0, right: 15 * PdfPageFormat.mm),
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.SizedBox(height: 5 * PdfPageFormat.mm),

                    pw.Text('KTOOLS',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),

                    pw.Text(nombreCliente != null ? 'VENTA A CRÉDITO' : 'FERREELÉCTRICA',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),

                    pw.SizedBox(height: 2),
                    pw.Text('Blvrd Miguel Hidalgo 2135A, Valle de Leon, 37140 Guanajuato, Gto.',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 6)),

                    if (itemsDevueltos != null || folioVenta.toString().endsWith('M')) ...[
                      pw.SizedBox(height: 2),
                      pw.Text('Ticket de devolución', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ],

                    pw.SizedBox(height: 5),
                    if (fechaOriginal != null)
                      pw.Text('FECHA ORIGINAL:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),

                    pw.Text(fechaMostrar, style: const pw.TextStyle(fontSize: 7)),

                    if (nombreCliente != null)
                      pw.Text('Cliente: $nombreCliente',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),

                    pw.Text('Folio Venta: #$folioVenta',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),

                    pw.Divider(borderStyle: pw.BorderStyle.dashed),

                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(flex: 1, child: pw.Text('Cant', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold))),
                          pw.Expanded(flex: 3, child: pw.Text('Art', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold))),
                          pw.Expanded(flex: 1, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold))),
                        ]
                    ),
                    pw.SizedBox(height: 4),

                    ...items.map((item) {
                      final subtotal = item.precio * item.cantidad;
                      return pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 2),
                          child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Expanded(flex: 1, child: pw.Text('${item.cantidad}', style: const pw.TextStyle(fontSize: 6))),
                                pw.Expanded(flex: 3, child: pw.Text(item.descripcion, maxLines: 2, style: const pw.TextStyle(fontSize: 6))),
                                pw.Expanded(flex: 1, child: pw.Text('\$${subtotal.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 6))),
                              ]
                          )
                      );
                    }).toList(),

                    if (itemsDevueltos != null && itemsDevueltos.isNotEmpty) ...[
                      pw.SizedBox(height: 5),
                      pw.Text('PRODUCTOS DEVUELTOS:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      ...itemsDevueltos.map((item) {
                        final subtotal = item.precio * item.cantidad;
                        return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 2),
                            child: pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Expanded(flex: 1, child: pw.Text('${item.cantidad}', style: const pw.TextStyle(fontSize: 6))),
                                  pw.Expanded(flex: 3, child: pw.Text(item.descripcion, maxLines: 2, style: const pw.TextStyle(fontSize: 6, decoration: pw.TextDecoration.lineThrough))),
                                  pw.Expanded(flex: 1, child: pw.Text('-\$${subtotal.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 6))),
                                ]
                            )
                        );
                      }).toList(),
                    ],

                    pw.Divider(borderStyle: pw.BorderStyle.dashed),

                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('TOTAL ACTUAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          pw.Text('\$${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        ]
                    ),
                    pw.SizedBox(height: 2),
                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Recibido original:', style: const pw.TextStyle(fontSize: 7)),
                          pw.Text('\$${recibido.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7)),
                        ]
                    ),
                    if (itemsDevueltos != null || folioVenta.toString().endsWith('M')) ...[
                      pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Monto reintegrado:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                            pw.Text('\$${montoDevueltoTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                          ]
                      ),
                    ],
                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('CAMBIO:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text('\$${cambio.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ]
                    ),

                    pw.SizedBox(height: 10),
                    pw.Text('Gracias por su preferencia', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),

                    if (fechaOriginal != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Text('Copia impresa el: $fechaActual', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
                    ],

                    pw.Divider(borderStyle: pw.BorderStyle.dashed),

                    pw.Text('Este no es comprobante fiscal', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      '15 días de garantía por defecto de fábrica. No cubre daños por mala instalación o uso. En electrónicos no se aceptan cambios ni devoluciones.',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 6),
                    ),
                    pw.SizedBox(height: 10 * PdfPageFormat.mm),
                  ]
              ),
            );
          }
      ),
    );

    return doc.save();
  }
}

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../venta.dart';

import '../models/item_venta.dart' as modelo;

class ImpresionTicket {

  static Future<void> imprimirTicketAbono({
    required String nombreDeudor,
    required List<modelo.ItemVenta> items,
    required double montoAbonado,
    required double deudaAnterior,
    required double saldoRestante,
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

                    pw.Text('COMPROBANTE DE ABONO',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),

                    pw.SizedBox(height: 5),
                    pw.Text(fecha, style: const pw.TextStyle(fontSize: 7)),
                    pw.Text('Cliente: $nombreDeudor',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),

                    pw.Divider(borderStyle: pw.BorderStyle.dashed),

                    pw.Text('DETALLE DE DEUDA (PRODUCTOS):',
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
                                pw.Expanded(flex: 1, child: pw.Text('\$${(item.precio * item.cantidad).toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 6))),
                              ]
                          )
                      );
                    }).toList(),

                    pw.Divider(borderStyle: pw.BorderStyle.dashed),

                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('DEUDA TOTAL:', style: const pw.TextStyle(fontSize: 7)),
                          pw.Text('\$${deudaAnterior.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7)),
                        ]
                    ),
                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('SU ABONO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                          pw.Text('\$${montoAbonado.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        ]
                    ),
                    pw.Divider(borderStyle: pw.BorderStyle.dashed),
                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('SALDO PENDIENTE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                          pw.Text('\$${saldoRestante.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        ]
                    ),

                    pw.SizedBox(height: 10),
                    pw.Text('Conserve este comprobante', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                    pw.SizedBox(height: 10 * PdfPageFormat.mm),
                  ]
              ),
            );
          }
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Abono_${nombreDeudor}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    );
  }
  
  static Future<void> imprimirTicket({
    required List<ItemVenta> items,
    required double total,
    required double recibido,
    required double cambio,
    required int folioVenta,
    String? fechaOriginal, // Nuevo parámetro opcional
  }) async {
    
    final doc = pw.Document();
    final fechaActual = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final fechaMostrar = fechaOriginal ?? fechaActual;

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
                
                pw.Text('FERREELÉCTRICA', 
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                
                pw.SizedBox(height: 5),
                if (fechaOriginal != null) 
                  pw.Text('FECHA ORIGINAL:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                
                pw.Text(fechaMostrar, style: const pw.TextStyle(fontSize: 7)),
                
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

                // ITEMS
                ...items.map((item) {
                  final subtotal = item.producto.precio * item.cantidad;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(flex: 1, child: pw.Text('${item.cantidad}', style: const pw.TextStyle(fontSize: 6))),
                        pw.Expanded(flex: 3, child: pw.Text(item.producto.descripcion, maxLines: 2, style: const pw.TextStyle(fontSize: 6))),
                        pw.Expanded(flex: 1, child: pw.Text('\$${subtotal.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 6))),
                      ]
                    )
                  );
                }).toList(),

                pw.Divider(borderStyle: pw.BorderStyle.dashed),

                // TOTALES
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    pw.Text('\$${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  ]
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Recibido:', style: const pw.TextStyle(fontSize: 7)),
                      pw.Text('\$${recibido.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7)),
                    ]
                ),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Cambio:', style: const pw.TextStyle(fontSize: 7)),
                      pw.Text('\$${cambio.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7)),
                    ]
                ),

                pw.SizedBox(height: 10),
                pw.Text('Gracias por su preferencia', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                
                if (fechaOriginal != null) ...[
                   pw.SizedBox(height: 4),
                   pw.Text('Copia impresa el: $fechaActual', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
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
}
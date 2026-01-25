import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../venta.dart'; // Importa para acceder a la clase ItemVenta

class ImpresionTicket {

  static Future<void> imprimirTicket({
    required List<ItemVenta> items,
    required double total,
    required double recibido,
    required double cambio,
    required int folioVenta, // El número de venta/ID
  }) async {

    final doc = pw.Document();
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // Definimos el tamaño del papel (Rollo de 80mm o 58mm)
    // 80mm es aprox 226 puntos de ancho en PDF.
    // Si tu impresora es de 58mm, reduce el width a aprox 150.0
    final PdfPageFormat formatoTicket = PdfPageFormat(
        58 * PdfPageFormat.mm,
        double.infinity, // Largo infinito (rollo)
        marginAll: 5 * PdfPageFormat.mm // Margen de 5mm
    );

    doc.addPage(
      pw.Page(
          pageFormat: formatoTicket,
          build: (pw.Context context) {
            return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  // --- ENCABEZADO ---
                  pw.Text('KTOOLS',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 24)),
                  pw.Text('Ferreeléctrica',
                      style: pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 5),
                  pw.Text('$fecha', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Folio Venta: #$folioVenta', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),

                  pw.Divider(borderStyle: pw.BorderStyle.dashed),

                  // --- LISTA DE PRODUCTOS ---
                  // Encabezados de columna
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(flex: 1, child: pw.Text('Cant', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                        pw.Expanded(flex: 3, child: pw.Text('Desc', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                        pw.Expanded(flex: 1, child: pw.Text('Importe', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      ]
                  ),
                  pw.SizedBox(height: 4),

                  // Items
                  ...items.map((item) {
                    final subtotal = item.producto.precio * item.cantidad;
                    // Usamos el precio según el tipo de venta si quisieras pasarlo,
                    // aquí asumo precio público normal, ajusta si es Rappi
                    return pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(flex: 1, child: pw.Text('${item.cantidad}', style: const pw.TextStyle(fontSize: 9))),
                          pw.Expanded(flex: 3, child: pw.Text(item.producto.descripcion, style: const pw.TextStyle(fontSize: 9))),
                          pw.Expanded(flex: 1, child: pw.Text('\$${subtotal.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                        ]
                    );
                  }).toList(),

                  pw.Divider(borderStyle: pw.BorderStyle.dashed),

                  // --- TOTALES ---
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                        pw.Text('\$${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      ]
                  ),
                  pw.SizedBox(height: 2),
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Recibido:', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('\$${recibido.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                      ]
                  ),
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Cambio:', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('\$${cambio.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                      ]
                  ),

                  pw.SizedBox(height: 10),
                  pw.Text('Gracias por su preferencia', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),

                  pw.Divider(borderStyle: pw.BorderStyle.dashed),

                  // --- DISCLAIMERS ---
                  pw.Text('Este no es comprobante fiscal', style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'KTOOLS no asume responsabilidad por daños derivados de una instalación incorrecta, negligencia o variaciones de voltaje.',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ]
            );
          }
      ),
    );

    // ESTO ABRE EL DIÁLOGO DE IMPRESIÓN DEL SISTEMA
    // Si configuras la impresora térmica como "Predeterminada" en Windows/Linux,
    // el usuario solo da Enter.
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Ticket_$folioVenta',
      // usePrinterSettings: true, // Intenta usar config de impresora
    );
  }
}
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../venta.dart';

class ImpresionTicket {
  
  static Future<void> imprimirTicket({
    required List<ItemVenta> items,
    required double total,
    required double recibido,
    required double cambio,
    required int folioVenta,
  }) async {
    
    final doc = pw.Document();
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // --- CORRECCIÓN CRÍTICA DE ANCHO ---
    // Aunque el papel es de 58mm, la zona imprimible real es de aprox 48mm.
    // Definimos la página en 58mm para que el driver no se queje, 
    // pero usaremos un margen derecho grande para forzar al texto a quedarse en la izquierda.
    final PdfPageFormat formatoTicket = PdfPageFormat(
      58 * PdfPageFormat.mm, 
      double.infinity, 
      marginAll: 0
    );

    doc.addPage(
      pw.Page(
        pageFormat: formatoTicket,
        build: (pw.Context context) {
          return pw.Padding(
            // Padding Izquierdo: 0 (porque la impresora ya agrega uno físico)
            // Padding Derecho: 8mm (para evitar que se corte si se mueve)
            padding: const pw.EdgeInsets.only(left: 0, right: 8 * PdfPageFormat.mm), 
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.SizedBox(height: 5 * PdfPageFormat.mm), 
                
                // --- ENCABEZADO ---
                pw.Text('KTOOLS', 
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                // CAMBIO: Mayúsculas
                pw.Text('FERREELÉCTRICA', 
                    style: const pw.TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Text(fecha, style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Folio Venta: #$folioVenta', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                
                pw.Divider(borderStyle: pw.BorderStyle.dashed),

                // --- LISTA DE PRODUCTOS ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(flex: 1, child: pw.Text('Cant', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 3, child: pw.Text('Art', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 1, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                  ]
                ),
                pw.SizedBox(height: 4),

                ...items.map((item) {
                  final subtotal = item.producto.precio * item.cantidad;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(flex: 1, child: pw.Text('${item.cantidad}', style: const pw.TextStyle(fontSize: 7))),
                        pw.Expanded(flex: 3, child: pw.Text(item.producto.descripcion, maxLines: 2, style: const pw.TextStyle(fontSize: 7))),
                        pw.Expanded(flex: 1, child: pw.Text('\$${subtotal.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7))),
                      ]
                    )
                  );
                }).toList(),

                pw.Divider(borderStyle: pw.BorderStyle.dashed),

                // --- TOTALES ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text('\$${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ]
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Recibido:', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('\$${recibido.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                    ]
                ),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Cambio:', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('\$${cambio.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                    ]
                ),

                pw.SizedBox(height: 10),
                pw.Text('Gracias por su preferencia', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                
                pw.Divider(borderStyle: pw.BorderStyle.dashed),
                
                // --- DISCLAIMERS ---
                // CAMBIO: Letra más grande (de 7 a 9)
                pw.Text('Este no es comprobante fiscal', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.SizedBox(height: 5),
                pw.Text(
                  'KTOOLS no asume responsabilidad por daños derivados de una instalación incorrecta, negligencia o variaciones de voltaje. No se aceptan cambios por daño físico.',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7), 
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
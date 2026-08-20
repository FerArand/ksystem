import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'constants/colores.dart';
import 'databases/factureros.dart'; // Asegúrate de que la ruta sea correcta

class FacturaForm extends StatefulWidget {
  final dynamic ventaId;
  final List<int>? ticketPdf;
  const FacturaForm({super.key, this.ventaId, this.ticketPdf});

  @override
  State<FacturaForm> createState() => _FacturaFormState();
}

class _FacturaFormState extends State<FacturaForm> {
  final _formKey = GlobalKey<FormState>();

  final _rfcController = TextEditingController();
  final _nombreController = TextEditingController();
  final _cpController = TextEditingController();
  final _emailController = TextEditingController();

  String? _regimenFiscal;
  String? _usoCfdi;
  bool _isSending = false;

  // Variables de control para el registro de factureros
  Facturero? _factureroOriginal;
  bool _guardarRegistro = true;

  final List<Map<String, String>> _regimenes = [
    {'code': '601', 'name': '601 - General de Ley Personas Morales'},
    {'code': '603', 'name': '603 - Personas Morales con Fines no Lucrativos'},
    {'code': '605', 'name': '605 - Sueldos y Salarios'},
    {'code': '606', 'name': '606 - Arrendamiento'},
    {'code': '612', 'name': '612 - Personas Físicas con Actividades Empresariales'},
    {'code': '621', 'name': '621 - Incorporación Fiscal'},
    {'code': '626', 'name': '626 - Régimen Simplificado de Confianza (RESICO)'},
  ];

  final List<Map<String, String>> _usos = [
    {'code': 'G01', 'name': 'G01 - Adquisición de mercancías'},
    {'code': 'G03', 'name': 'G03 - Gastos en general'},
    {'code': 'S01', 'name': 'S01 - Sin efectos fiscales'},
    {'code': 'CP01', 'name': 'CP01 - Pagos'},
  ];

  void _cargarFacturero(Facturero f) {
    setState(() {
      _factureroOriginal = f;
      _rfcController.text = f.rfc;
      _nombreController.text = f.razonSocial;
      _cpController.text = f.codigoPostal;
      _emailController.text = f.correo;

      // Validamos que el código exista en nuestras listas antes de asignarlo
      bool regimenExiste = _regimenes.any((r) => r['code'] == f.regimenFiscal);
      _regimenFiscal = regimenExiste ? f.regimenFiscal : null;

      bool usoExiste = _usos.any((u) => u['code'] == f.usoCfdi);
      _usoCfdi = usoExiste ? f.usoCfdi : null;
    });
  }

  Future<void> _mostrarBuscador() async {
    List<Facturero> resultados = [];
    TextEditingController buscadorController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: const Text('Buscar Cliente'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: buscadorController,
                      decoration: const InputDecoration(
                        hintText: 'Nombre o Razón Social...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (val) async {
                        if (val.length >= 2) {
                          var res = await FacturerosDB.buscarPorRazonSocial(val);
                          setStateModal(() {
                            resultados = res;
                          });
                        } else {
                          setStateModal(() {
                            resultados = [];
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: resultados.length,
                        itemBuilder: (context, index) {
                          final f = resultados[index];
                          return ListTile(
                            title: Text(f.razonSocial, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(f.rfc),
                            onTap: () {
                              _cargarFacturero(f);
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _validarYEnviar() async {
    if (!_formKey.currentState!.validate()) return;

    final datosActuales = Facturero(
      rfc: _rfcController.text.toUpperCase().trim(),
      razonSocial: _nombreController.text.toUpperCase().trim(),
      codigoPostal: _cpController.text.trim(),
      regimenFiscal: _regimenFiscal ?? '',
      correo: _emailController.text.trim(),
      usoCfdi: _usoCfdi ?? '',
    );

    bool huboCambios = false;
    if (_factureroOriginal != null) {
      huboCambios = (
          datosActuales.rfc != _factureroOriginal!.rfc ||
              datosActuales.razonSocial != _factureroOriginal!.razonSocial ||
              datosActuales.codigoPostal != _factureroOriginal!.codigoPostal ||
              datosActuales.regimenFiscal != _factureroOriginal!.regimenFiscal ||
              datosActuales.correo != _factureroOriginal!.correo ||
              datosActuales.usoCfdi != _factureroOriginal!.usoCfdi
      );
    }

    if (_factureroOriginal != null && huboCambios && _guardarRegistro) {
      bool? confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cambios detectados'),
          content: const Text(
            'Se detectaron modificaciones en los datos de este cliente. '
                '¿Deseas proceder con el envío y actualizar automáticamente el registro existente?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar y revisar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí, enviar y actualizar'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
      await FacturerosDB.guardarOActualizar(datosActuales);
      _ejecutarEnvioSolicitud(datosActuales);
      return;
    }

    if ((huboCambios || _factureroOriginal == null) && !_guardarRegistro) {
      bool? confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Registro no guardado'),
          content: const Text(
            'Los cambios no se guardarán en el registro del cliente. '
                'Si lo deseas, cancela el proceso y activa la casilla "Guardar registro".\n\n'
                '¿Deseas continuar con el envío sin guardar los cambios?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar sin guardar'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
      _ejecutarEnvioSolicitud(datosActuales);
      return;
    }

    if (_guardarRegistro) {
      await FacturerosDB.guardarOActualizar(datosActuales);
    }
    _ejecutarEnvioSolicitud(datosActuales);
  }

  Future<void> _ejecutarEnvioSolicitud(Facturero datos) async {
    setState(() => _isSending = true);

    final String subject = 'Solicitud de Factura - ${datos.rfc}';
    final String bodyText = '''
SOLICITUD DE FACTURACIÓN
------------------------
Folio de Venta: ${widget.ventaId ?? 'N/A'}
RFC: ${datos.rfc}
Nombre/Razón Social: ${datos.razonSocial}
Código Postal: ${datos.codigoPostal}
Régimen Fiscal: ${datos.regimenFiscal}
Uso de CFDI: ${datos.usoCfdi}
Correo del Cliente: ${datos.correo}

Favor de emitir la factura correspondiente. Se adjunta copia del ticket de venta.
''';

    const String username = 'facturacionktools@gmail.com';
    const String password = 'qxfe cqem khxq idla';

    final smtpServer = gmail(username, password);

    final message = Message()
      ..from = const Address(username, 'Ksystem Billing')
      ..recipients.add(username)
      ..subject = subject
      ..text = bodyText;

    if (widget.ticketPdf != null) {
      message.attachments.add(
        StreamAttachment(
          Stream.value(widget.ticketPdf!),
          'application/pdf',
          fileName: 'ticket_${widget.ventaId ?? "venta"}.pdf',
        ),
      );
    }

    try {
      await send(message, smtpServer);
      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
            backgroundColor: Colores.rojo,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colores.verde),
            SizedBox(width: 10),
            Text("Solicitud Enviada"),
          ],
        ),
        content: const Text("Los datos fiscales y el ticket se han enviado correctamente para su procesamiento."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Cierra el modal y regresa a la vista anterior
            },
            child: const Text("ENTENDIDO", style: TextStyle(fontWeight: FontWeight.bold, color: Colores.azulPrincipal)),
          ),
        ],
      ),
    );
  }

  InputDecoration _minimalInput(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colores.azulPrincipal, size: 20),
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colores.azulPrincipal, width: 2)),
      errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colores.rojo)),
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colores.grisOscuro),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Datos de Facturación',
          style: TextStyle(color: Colores.grisOscuro, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _mostrarBuscador,
                icon: const Icon(Icons.search, color: Colores.azulPrincipal),
                label: const Text('Buscar Cliente Guardado', style: TextStyle(color: Colores.azulPrincipal)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colores.azulPrincipal),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Complete la información tal como aparece en la Constancia de Situación Fiscal.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 30),

              TextFormField(
                controller: _rfcController,
                inputFormatters: [UpperCaseTextFormatter()],
                textCapitalization: TextCapitalization.characters,
                decoration: _minimalInput('RFC del Cliente', Icons.badge_outlined),
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Requerido';
                  if (value.length < 12) return 'Muy corto';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nombreController,
                inputFormatters: [UpperCaseTextFormatter()],
                textCapitalization: TextCapitalization.characters,
                decoration: _minimalInput('Nombre o Razón Social', Icons.business_outlined),
                validator: (value) => value!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _cpController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                decoration: _minimalInput('Código Postal', Icons.location_on_outlined),
                validator: (value) => value!.length != 5 ? 'Debe tener 5 dígitos' : null,
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: _regimenFiscal,
                decoration: _minimalInput('Régimen Fiscal', Icons.account_balance_outlined),
                style: const TextStyle(color: Colors.black, fontSize: 13),
                isExpanded: true,
                items: _regimenes.map((r) => DropdownMenuItem(
                    value: r['code'],
                    child: Text(r['name']!, overflow: TextOverflow.ellipsis)
                )).toList(),
                onChanged: (val) => setState(() => _regimenFiscal = val),
                validator: (val) => val == null ? 'Seleccione uno' : null,
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: _usoCfdi,
                decoration: _minimalInput('Uso de CFDI', Icons.gavel_outlined),
                style: const TextStyle(color: Colors.black, fontSize: 13),
                items: _usos.map((u) => DropdownMenuItem(
                    value: u['code'],
                    child: Text(u['name']!)
                )).toList(),
                onChanged: (val) => setState(() => _usoCfdi = val),
                validator: (val) => val == null ? 'Seleccione uno' : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _minimalInput('Correo para envío', Icons.email_outlined),
                validator: (value) => (value == null || !value.contains('@')) ? 'Email inválido' : null,
              ),

              const SizedBox(height: 40),

              Row(
                children: [
                  Checkbox(
                    value: _guardarRegistro,
                    onChanged: (val) {
                      setState(() {
                        _guardarRegistro = val ?? true;
                      });
                    },
                    activeColor: Colores.azulPrincipal,
                  ),
                  const Expanded(
                    child: Text(
                      'Guardar registro para futuras facturas',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _validarYEnviar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colores.azulPrincipal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isSending
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('ENVIAR SOLICITUD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
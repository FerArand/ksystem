import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final bool isDecimal;

  ThousandsSeparatorInputFormatter({this.isDecimal = true});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Permitir el punto decimal al final mientras se escribe
    if (isDecimal && newValue.text.endsWith('.')) {
      // Verificar si ya hay un punto previo para evitar duplicados
      if (oldValue.text.contains('.')) {
        return oldValue;
      }
      return newValue;
    }

    // Eliminar comas existentes para procesar el número puro
    String stripped = newValue.text.replaceAll(',', '');
    
    // Validar que sea un número válido
    if (isDecimal) {
      if (double.tryParse(stripped) == null) return oldValue;
    } else {
      if (int.tryParse(stripped) == null) return oldValue;
    }

    // Separar parte entera y decimal para formatear solo la entera
    List<String> parts = stripped.split('.');
    String integerPart = parts[0];
    String? decimalPart = parts.length > 1 ? parts[1] : null;

    final formatter = NumberFormat("#,###", "en_US");
    num? intVal = num.tryParse(integerPart);
    if (intVal == null && integerPart.isNotEmpty) return oldValue;
    
    String formattedInt = integerPart.isEmpty ? "" : formatter.format(intVal);
    String formatted = decimalPart != null ? "$formattedInt.$decimalPart" : formattedInt;

    // Calcular la nueva posición del cursor
    // La lógica se basa en mantener la distancia desde el final del texto
    int cursorPosition = formatted.length - (newValue.text.length - newValue.selection.extentOffset);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: cursorPosition.clamp(0, formatted.length),
      ),
    );
  }

  /// Utilidad para obtener el valor numérico sin comas
  static double parse(String text) {
    return double.tryParse(text.replaceAll(',', '')) ?? 0.0;
  }
  
  static int parseInt(String text) {
    return int.tryParse(text.replaceAll(',', '')) ?? 0;
  }

  static String format(num value, {bool isDecimal = true}) {
    final formatter = isDecimal 
        ? NumberFormat("#,###.##", "en_US") 
        : NumberFormat("#,###", "en_US");
    return formatter.format(value);
  }
}

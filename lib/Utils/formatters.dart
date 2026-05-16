import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 2,
  );

  static String formatearMoneda(double valor) {
    return _currencyFormat.format(valor);
  }

  // Versión compacta sin decimales para el calendario si es necesario
  static String formatearMonedaCompacta(double valor) {
    return NumberFormat.currency(
      locale: 'es_MX',
      symbol: '\$',
      decimalDigits: 0,
    ).format(valor);
  }
}

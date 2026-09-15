import 'gateway_exception.dart';

/// Additional gateway API fields, addressed by dot-notation keys such as
/// `billing.address.city` or `customer.email`.
///
/// Use it for session and authentication fields that have no dedicated model, for example
/// payer details that improve the chance of a frictionless 3DS authentication. Field names
/// are those of the gateway API version used by the session.
///
/// Card and wallet data are rejected here (`sourceOfFunds.*`): they must go through
/// `CardDetails` or the wallet API so they are never handled as free-form values.
class GatewayFields {
  final Map<String, Object> _values = {};

  static final RegExp _keyFormat = RegExp(
    r'^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$',
  );
  static const String _reservedRootKey = 'sourceOfFunds';

  void setString(String key, String value) => _set(key, value);

  void setInt(String key, int value) => _set(key, value);

  void setDouble(String key, double value) => _set(key, value);

  void setBool(String key, bool value) => _set(key, value);

  /// Fields in insertion order. Values are `String`, `int`, `double` or `bool`.
  Map<String, Object> get values => Map.unmodifiable(_values);

  bool get isEmpty => _values.isEmpty;

  void _set(String key, Object value) {
    if (!_keyFormat.hasMatch(key)) {
      throw GatewayException(
        code: GatewayErrorCode.invalidArgument,
        message:
            'Invalid gateway field key "$key". '
            'Use dot notation with letters and digits, e.g. "billing.address.city".',
      );
    }
    if (key == _reservedRootKey || key.startsWith('$_reservedRootKey.')) {
      throw GatewayException(
        code: GatewayErrorCode.invalidArgument,
        message:
            'Gateway field "$key" is reserved. '
            'Send card data with CardDetails and wallet data with the wallet API.',
      );
    }
    _values[key] = value;
  }

  // Values may contain personal data, so only keys are printed.
  @override
  String toString() => 'GatewayFields(${_values.keys.join(', ')})';
}

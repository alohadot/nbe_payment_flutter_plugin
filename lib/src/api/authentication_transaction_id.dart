import 'dart:math';

/// Creates a random UUID (version 4) to identify one payer authentication attempt.
///
/// The gateway stores each authentication under this identifier and the merchant server
/// references it in the Pay request, so every attempt on an order needs a new one. A
/// UUID (36 characters) fits the gateway's transaction identifier limits.
String generateAuthenticationTransactionId({Random? random}) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => source.nextInt(256));

  // RFC 4122: version 4 in the high nibble of byte 6, variant 10xx in byte 8.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

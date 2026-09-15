/// Replaces every character except the last [visibleCount] with `•`.
///
/// Used by `toString` of models that hold card or session data, so that accidentally
/// logging a model never prints the full value.
String maskAllButLast(String value, int visibleCount) {
  if (value.length <= visibleCount) {
    return '•' * value.length;
  }
  final hiddenLength = value.length - visibleCount;
  return '${'•' * hiddenLength}${value.substring(hiddenLength)}';
}

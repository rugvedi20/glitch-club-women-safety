extension StringExtensions on String {
  bool get isEmail {
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return regex.hasMatch(this);
  }
}

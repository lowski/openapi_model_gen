extension ProgrammingCasesExtension on String {
  /// Converts the first character in this string to upper case.
  String toTitleCase() =>
      isEmpty ? '' : this[0].toUpperCase() + (length > 1 ? substring(1) : '');

  /// Convert a string to lower camel case.
  ///
  /// All non-alphanumeric characters are removed.
  ///
  /// ```dart
  /// 'this_is_a_test'.toCamelCase() // 'thisIsATest'
  /// 'ThisTest'.toCamelCase() // 'thisTest'
  /// 'Something like Camels'.toCamelCase() // 'somethingLikeCamels'
  /// 'Interesting?! 9__Camels!'.toCamelCase() // 'interesting9Camels'
  /// ```
  String toCamelCase() {
    String out = '';
    bool newWord = false;
    for (final c in split('')) {
      // New word if the upper and lower case versions of the character are not
      // different (meaning not an alphabet character) and c is not an int.
      if (c.toLowerCase() == c.toUpperCase() && int.tryParse(c) == null) {
        newWord = true;
        continue;
      }

      out += newWord ? c.toUpperCase() : c;
      newWord = false;

      if (int.tryParse(c) != null) {
        newWord = true;
      }
    }
    if (out.isNotEmpty) {
      out = out[0].toLowerCase() + (out.length > 1 ? out.substring(1) : '');
    }
    return out;
  }

  /// Converts a string to upper camel case.
  ///
  /// ```
  /// string.toUpperCamelCase() == string.toUpperCamelCase()
  /// ```
  ///
  ///
  String toUpperCamelCase() => toCamelCase().toTitleCase();

  /// Convert a string, that is camel case or contains spaces, to snake case.
  ///
  /// All non-alphanumeric characters are removed and replaced by an underscore.
  /// (repeated and trailing underscores are removed)
  ///
  /// ```dart
  /// 'thisIsATest'.toSnakeCase() // 'this_is_a_test'
  /// 'ThisTest'.toSnakeCase() // 'this_test'
  /// 'Something like Camels'.toSnakeCase() // 'something_like_camels'
  /// 'Interesting?! 9__Camels!'.toSnakeCase() // 'interesting_9_camels'
  /// ```
  String toSnakeCase() {
    String out = '';
    for (final c in split('')) {
      if (out.isEmpty) {
        out += c.toLowerCase();
        continue;
      }
      // New word if the upper and lower case versions of the character are not
      // different (meaning not an alphabet character) and c is not an int.
      if (c == ' ' ||
          (c.toLowerCase() == c.toUpperCase() && int.tryParse(c) == null)) {
        if (!out.endsWith('_')) {
          out += '_';
        }
        continue;
      }

      // New word, if the character is upper case
      if (c.toUpperCase() == c) {
        if (!out.endsWith('_')) {
          out += '_';
        }
      }
      out += c.toLowerCase();
    }
    if (out.endsWith('_')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }
}

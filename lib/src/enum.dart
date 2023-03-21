import 'package:code_builder/code_builder.dart' as cb;
import 'package:openapi_model_gen/src/generator_options.dart';

import 'programming_cases_extension.dart';
import 'property.dart';

class Enum {
  String name;
  PropertyType type;
  Map<String, String> valueToName = {};

  Enum({
    required this.name,
    required this.type,
  });

  factory Enum.fromOas({
    required Map<String, dynamic> oas,
    required String name,
    required Property prop,
  }) {
    final e = Enum(
      name: name,
      type: prop.type,
    );

    final useDescriptionsAsNames = oas['x-enum-descriptions'] != null &&
        oas['x-enum-descriptions'].length == oas['enum'].length;

    final enumValues = (oas['enum'] as List<dynamic>);

    for (int i = 0; i < enumValues.length; i++) {
      final item = enumValues[i];
      String name;

      // Take the name from the enum descriptions if possible
      if (useDescriptionsAsNames) {
        name = oas['x-enum-descriptions'][i].toString().toCamelCase();
      } else {
        name =
            prop.type == PropertyType.integer ? 'number$item' : item.toString();
      }

      e.add(item.toString(), name);
    }

    return e;
  }

  /// Add a value to the enum.
  ///
  /// [name] is the name of the enum entry.
  ///
  /// [value] is the data representation of the enum entry.
  void add(String value, String name) {
    valueToName[value] = name;
  }

  static bool isTypeSupported(PropertyType type) =>
      type == PropertyType.integer || type == PropertyType.string;

  void build(cb.LibraryBuilder parent, GeneratorOptions options) {
    final enm = cb.Enum((enumBuilder) {
      enumBuilder.name = name;

      for (final entry in valueToName.entries) {
        final jsonValue = type == PropertyType.integer
            ? cb.literal(int.parse(entry.key))
            : cb.literal(entry.key);
        enumBuilder.values.add(
          cb.EnumValue(
            (enumValueBuilder) {
              enumValueBuilder
                ..name = entry.value
                ..annotations.add(
                  cb.refer('JsonValue').call([jsonValue]),
                );
            },
          ),
        );
      }
    });
    parent.body.add(enm);
  }
}

import 'package:code_builder/code_builder.dart';
import 'package:openapi_model_gen/src/generator_options.dart';

class PropertyType {
  static final integer = PropertyType('int');
  static final boolean = PropertyType('bool');
  static final number = PropertyType('num');
  static final string = PropertyType('String');
  static final array = PropertyType('List');
  static final object = PropertyType('Object');
  static final stringDateTime = PropertyType('DateTime');
  static final mapStringDynamic = PropertyType('Map<String, dynamic>');

  static final _oasMap = {
    'integer': integer,
    'boolean': boolean,
    'number': number,
    'string': string,
    'array': array,
    'object': object,
  };

  final String dartName;

  PropertyType(this.dartName);

  PropertyType.map(String key, String value) : dartName = 'Map<$key, $value>';
  PropertyType.mapString(String value) : dartName = 'Map<String, $value>';

  PropertyType.list(String dartName) : dartName = 'List<$dartName>';

  factory PropertyType.fromOas(String type) {
    if (!_oasMap.containsKey(type)) {
      throw ArgumentError.value(type, 'type');
    }
    return _oasMap[type]!;
  }

  PropertyType asListType() => PropertyType.list(dartName);

  @override
  String toString() => 'PropertyType(dartName: $dartName)';
}

class Property {
  String name;
  PropertyType type;
  bool nullable;
  String comment;
  String importDirective;

  Property({
    required this.name,
    required this.type,
    bool? nullable,
    this.comment = '',
    this.importDirective = '',
  }) : nullable = nullable ?? false;

  @override
  String toString() =>
      'Property(name: $name, type: $type, nullable: $nullable)';

  String get dartType => type.dartName + (nullable ? '?' : '');

  Reference get reference => refer(
        dartType,
        importDirective.isNotEmpty ? importDirective : null,
      );

  factory Property.fromOas(Map<String, dynamic> schema, {String name = ''}) {
    PropertyType type = PropertyType.fromOas(schema['type'] ?? 'object');
    if (type == PropertyType.string &&
        (schema['format'] == 'date' || schema['format'] == 'date-time')) {
      type = PropertyType.stringDateTime;
    }
    return Property(
      name: schema['title'] ?? name,
      type: type,
      nullable: schema['nullable'],
      comment: schema['description'] ?? '',
    );
  }

  void build(ClassBuilder parent, GeneratorOptions options) {
    parent.fields.add(
      Field(
        (fieldBuilder) {
          fieldBuilder.name = name;
          fieldBuilder.type = reference;
          fieldBuilder.modifier = FieldModifier.final$;

          if (comment.isNotEmpty) {
            fieldBuilder.docs.add(
              comment.splitMapJoin(
                RegExp(r'\n'),
                onNonMatch: (m) => '/// $m',
              ),
            );
          }
        },
      ),
    );
    final param = Parameter(
      (parameterBuilder) => parameterBuilder
        ..name = name
        ..named = true
        ..toThis = true
        ..required = !nullable,
    );

    parent.constructors[0] = parent.constructors.first.rebuild(
      (p1) => p1.optionalParameters.add(param),
    );
  }
}

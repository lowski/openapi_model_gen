import 'package:code_builder/code_builder.dart';

import 'enum.dart' as omg_enum;
import 'generator_options.dart';
import 'programming_cases_extension.dart';
import 'property.dart';
import 'ref.dart';

const _refEquatable =
    Reference('Equatable', 'package:equatable/equatable.dart');
const _refJsonSerializable = Reference(
    'JsonSerializable()', 'package:json_annotation/json_annotation.dart');
const _refCopyWith = Reference(
    'CopyWith()', 'package:copy_with_extension/copy_with_extension.dart');
const _annotationOverride = CodeExpression(Code('override'));

class Schema {
  String ref;
  Ref refR;
  String name;
  List<Property> properties;
  List<Schema> subschemas;
  List<omg_enum.Enum> enums;

  Schema({
    required this.ref,
    required this.name,
  })  : properties = [],
        subschemas = [],
        enums = [],
        refR = Ref.parse(ref);
  Schema.withRef({
    required this.refR,
    required this.name,
  })  : properties = [],
        subschemas = [],
        enums = [],
        ref = refR.uri.toString();

  @override
  String toString() => 'Schema(name: $name, ref: $ref)';

  String get fileName {
    return snakeCaseName + '.dart';
  }

  String get snakeCaseName => name.toSnakeCase();

  void build(LibraryBuilder parent, GeneratorOptions options) {
    final cls = Class((classBuilder) {
      classBuilder
        ..name = name
        ..annotations.addAll([
          if (options.useJsonSerializable) _refJsonSerializable,
          if (options.useCopyWith) _refCopyWith,
        ]);

      if (options.useEquatable) {
        classBuilder.extend = _refEquatable;
      }

      final optionalParameters = <Parameter>[];
      classBuilder.constructors.add(Constructor((b) {
        b.constant = true;
        b.optionalParameters.addAll(optionalParameters);
      }));

      for (final prop in properties) {
        prop.build(classBuilder, options);
      }

      if (options.useEquatable) {
        classBuilder.methods.add(
          Method(
            (b) {
              b.name = 'props';
              b.type = MethodType.getter;
              b.returns = refer('List<Object?>');
              b.lambda = true;
              b.annotations.add(_annotationOverride);
              b.body = Code('['
                  '${properties.map((e) => e.name).join(', ')}'
                  ']');
            },
          ),
        );
      }

      if (options.useJsonSerializable) {
        classBuilder.constructors.add(Constructor((b) {
          b.name = 'fromJson';
          b.factory = true;
          b.requiredParameters.add(Parameter((b) {
            b.name = 'json';
            b.type = refer('Map<String, dynamic>');
          }));
          b.lambda = true;
          b.body = Code('_\$${name}FromJson(json)');
        }));

        // add a toJson method redirecting to the generated one
        classBuilder.methods.add(
          Method(
            (b) {
              b.name = 'toJson';
              b.type = MethodType.getter;
              b.returns = refer('Map<String, dynamic>');
              b.lambda = true;
              b.body = Code('_\$${name}ToJson(this)');
            },
          ),
        );
      }
    });

    parent.body.add(cls);
  }
}

import 'dart:io';

import 'package:args/args.dart';
import 'package:code_builder/code_builder.dart' as cb;
import 'package:dart_style/dart_style.dart';
import 'package:openapi_model_gen/src/enum.dart';
import 'package:openapi_model_gen/src/generator_options.dart';
import 'package:openapi_model_gen/src/programming_cases_extension.dart';
import 'package:openapi_model_gen/src/property.dart';
import 'package:openapi_model_gen/src/ref.dart';
import 'package:openapi_model_gen/src/schema.dart';
import 'package:yaml/yaml.dart';

void main(List<String> argv) async {
  final args = parseArgs(argv);

  final outputDir = Directory(args['output']);

  final inputFile = File(args['input']);
  final input = loadYaml(inputFile.readAsStringSync());
  final schemas = input['components']['schemas'];
  final models = schemas.keys.toList();

  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final opt = GeneratorOptions(
    useEquatable: args['equatable'] ?? true,
    useJsonSerializable: args['json-serializable'] ?? true,
    useCopyWith: args['copy-with'] ?? true,
  );

  for (final import in (args['schema-mappings'] as Iterable<String>)) {
    if (!import.contains('=')) {
      throw Exception('Invalid schema mapping: $import');
    }
    opt.schemaMappings[import.split('=')[0]] =
        import.split('=').skip(1).join('=');
  }

  print('Creating models...');
  for (final model in models) {
    final schema = createSchemaFromRef(
      Ref.parse(
        '${File(args['input']).absolute.path}#/components/schemas/$model',
      ),
      options: opt,
    );

    String out = createFileFromClasses(
      schema,
      additionalSchemas: schema.subschemas,
      options: opt,
    );

    File(args['output'] + '/${schema.fileName}').writeAsStringSync(out);
  }
  print('Done!');
}

Schema createSchemaFromRef(
  Ref ref, {
  GeneratorOptions? options,
  bool allowEmptyTitle = false,
}) {
  options ??= GeneratorOptions();

  Map<String, dynamic> map = ref.loadMap();

  Ref resolved = ref;
  if (map['\$ref'] != null) {
    resolved = ref.resolve(Ref.parse(map['\$ref']));
    map = resolved.loadMap();
  }

  if (map['title'] == null && !allowEmptyTitle) {
    throw Exception('Schema does not have a title: ${ref.uri}');
  }

  final schema = Schema.withRef(
    name: map['title']?.toString().toUpperCamelCase() ?? '',
    refR: resolved,
  );

  final properties = map['properties']?.cast<String, dynamic>();

  // If the schema is from another file or does not have any properties, we do
  // not need to parse any further.
  if (!resolved.sameFile(ref) || properties == null) {
    return schema;
  }

  for (final entry in properties.entries) {
    final property = (entry.value as Map).cast<String, dynamic>();

    Property prop = Property.fromOas(
      property,
      name: entry.key,
    );

    if (property['enum'] != null &&
        property['enum'].isNotEmpty &&
        Enum.isTypeSupported(prop.type)) {
      final e = Enum.fromOas(
        oas: property,
        name: '${schema.name} ${prop.name}'.toUpperCamelCase(),
        prop: prop,
      );

      schema.enums.add(e);
      prop.type = PropertyType(e.name);
    } else if (prop.type == PropertyType.object) {
      // Create a new subschema if the property is an object
      final subschema = createSchemaFromRef(
        resolved.appendFragment('/properties/${entry.key}'),
        allowEmptyTitle: true,
      );

      final additionalPropertiesPath = resolved
          .appendFragment('/properties/${entry.key}/additionalProperties');
      if (additionalPropertiesPath.load() != null) {
        final property = additionalPropertiesPath.loadMap();

        final additionalProps = Property.fromOas(property);

        prop.type = PropertyType.mapString(additionalProps.dartType);
      } else {
        if (subschema.name.isEmpty) {
          subschema.name = (entry.key as String).toTitleCase();
        }
        prop.type = PropertyType(subschema.name);

        if (schema.refR.isParent(subschema.refR)) {
          // If the subschemas ref is a child of the schemas ref, the subschema
          // is inlined and therefore should be included in the same file.
          schema.subschemas.add(subschema);
        } else {
          // If not, the subschema was probably a $ref and will be created on its
          // own, so we just need to import the file.
          prop.importDirective =
              options.schemaMappings[subschema.name] ?? subschema.fileName;
        }
      }
    } else if (prop.type == PropertyType.array) {
      final itemProperty = Property.fromOas(
        property['items'].cast<String, dynamic>(),
      );

      if (itemProperty.type != PropertyType.object) {
        prop.type = itemProperty.type.asListType();
      } else {
        final subschema = createSchemaFromRef(
          schema.refR.appendFragment('/properties/${entry.key}/items'),
          allowEmptyTitle: true,
        );

        if (subschema.name.isEmpty) {
          subschema.name = '${schema.name} ${entry.key}'.toUpperCamelCase();
          subschema.name = subschema.name.endsWith('s')
              ? subschema.name.substring(0, subschema.name.length - 1)
              : subschema.name;
        }

        prop.type = PropertyType.list(subschema.name);

        if (schema.refR.isParent(subschema.refR)) {
          // If the subschemas ref is a child of the schemas ref, the subschema
          // is inlined and therefore should be included in the same file.
          schema.subschemas.add(subschema);
        } else {
          // If not, the subschema was probably a $ref and will be created on its
          // own, so we just need to import the file.
          prop.importDirective =
              options.schemaMappings[subschema.name] ?? subschema.fileName;
        }
      }
    }

    if (map['required'] != null && !map['required'].contains(entry.key)) {
      prop.nullable = true;
    }

    schema.properties.add(prop);
  }

  return schema;
}

String createFileFromClasses(
  Schema schema, {
  required GeneratorOptions options,
  List<Schema> additionalSchemas = const [],
}) {
  final library = cb.Library((b) {
    schema.build(b, options);

    for (final subschema in schema.subschemas) {
      subschema.build(b, options);
    }

    for (final enm in schema.enums) {
      enm.build(b, options);
    }

    b.directives.add(cb.Directive.part('${schema.snakeCaseName}.g.dart'));
  });

  final emitter = cb.DartEmitter(
    useNullSafetySyntax: true,
    orderDirectives: true,
    allocator: cb.Allocator(),
  );
  return DartFormatter().format('${library.accept(emitter)}');
}

ArgResults parseArgs(List<String> argv) {
  final parser = ArgParser();

  parser.addOption(
    'input',
    abbr: 'i',
    mandatory: true,
    help: 'Path to the OAS file.',
  );
  parser.addOption(
    'output',
    abbr: 'o',
    mandatory: true,
    help: 'Directory into which the model classes will be saved.',
  );
  parser.addMultiOption(
    'schema-mappings',
    help: 'Import paths for specific models in the format <classname>=<path>, '
        'e.g. "--schema-mappings Offer=package:super_package/models/offer.dart"',
  );

  parser.addFlag(
    'json-serializable',
    help: 'Add support for the json_serializable package',
    defaultsTo: true,
    negatable: true,
  );

  parser.addFlag(
    'equatable',
    help: 'Add support for the equatable package',
    defaultsTo: true,
    negatable: true,
  );

  parser.addFlag(
    'copy-with',
    help: 'Add support for the copy_with package',
    defaultsTo: true,
    negatable: true,
  );

  parser.addFlag(
    'help',
    help: 'Show this Dialog',
    defaultsTo: false,
    negatable: false,
  );

  ArgResults args;
  try {
    args = parser.parse(argv);
  } on FormatException catch (e) {
    if (argv.contains('--help')) {
      print('Usage:');
      print(parser.usage);
      exit(0);
    }

    print('Invalid command: ${e.message}\n\nUsage:');
    print(parser.usage);
    exit(0);
  } catch (e) {
    print('Invalid command: $e\n\nUsage:');
    print(parser.usage);
    exit(0);
  }

  if (args.rest.isNotEmpty) {
    print('Invalid arguments: ${args.rest.join(', ')}\n\nUsage:');
    print(parser.usage);
    exit(0);
  }

  if (args['help']) {
    print('Usage:');
    print(parser.usage);
    exit(0);
  }

  return args;
}

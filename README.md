# openapi_model_gen

A package to generate model classes from an OpenAPI spec file. By default the generated
models support the packages `equatable`, `json_serializable`, and `copy_with_extension`.

## Installation

Since the models support additional functionality through other packages, you will need to install
these as well:

```sh
dart pub add equatable json_annotation copy_with_extension
dart pub add --dev build_runner copy_with_extension_gen json_serializable
```

## Usage

To generate the model classes from a given OpenAPI spec file use the following command:

```sh
dart pub run openapi_model_gen -i ./openapi_spec.yaml -o ./lib/generated_models/
dart pub run build_runner build
```

This will generate classes for all schemas found in the spec file.

### Schema Mappings

If you want to reference classes that are not generated, you can map class names to import urls.
In that case the imports will be automatically added where appropriate.

```sh
dart pub run openapi_model_gen <...> --schema-mappings ExternalClass=package:external_package/external_class.dart
```

### External packages

If you don't want or need support for some of the external packages, you can explicitly enable
or disable them. By default every package is enabled.

```sh
# enable all (only for readability, as the flags are enabled by default)
dart pub run openapi_model_gen --copy-with --json-serializable --equatable <...>
# disable all
dart pub run openapi_model_gen --no-copy-with --no-json-serializable --no-equatable <...>
```

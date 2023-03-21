class GeneratorOptions {
  bool useEquatable;
  bool useJsonSerializable;
  bool useCopyWith;

  /// Map the name of a schema to the import path of the file that contains the
  /// class.
  Map<String, String> schemaMappings = {};

  GeneratorOptions({
    this.useEquatable = true,
    this.useJsonSerializable = true,
    this.useCopyWith = true,
  });
}

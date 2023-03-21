import 'dart:io';

import 'package:yaml/yaml.dart';

class Ref {
  /// Get the absolute file referenced by this.
  File get file => File(uri.path).absolute;

  final Uri uri;

  Ref._(
    this.uri,
  );

  factory Ref.parse(String s) {
    return Ref._(Uri.parse(s));
  }

  /// Resolve [ref] relative to `this`.
  Ref resolve(Ref ref) {
    return Ref._(uri.resolveUri(ref.uri));
  }

  /// Traverse [map] to find the object referenced by the fragment of `this`.
  dynamic findIn(dynamic map) {
    return getFragment(map, uri.fragment);
  }

  /// Load the object referenced by `this`.
  dynamic load() {
    final document = loadYaml(file.readAsStringSync());

    return findIn(document);
  }

  /// Load the `Map<String, dynamic>` referenced by [this].
  Map<String, dynamic> loadMap() => (load() as Map).cast<String, dynamic>();

  /// Check if two Refs are in the same file.
  bool sameFile(Ref o) => file.path == o.file.path;

  /// Check if [o] is a child of `this`.
  bool isParent(Ref o) =>
      sameFile(o) && o.uri.fragment.startsWith(uri.fragment + '/');

  /// Append [fragment] to the fragment of `this`.
  Ref appendFragment(String fragment) {
    if (fragment.startsWith('/')) {
      fragment = fragment.substring(1);
    }
    return Ref.parse(toString() + '/' + fragment);
  }

  @override
  String toString() => uri.toString();

  /// Traverse [map] to find the object referenced by [fragment].
  ///
  /// ```
  /// getFragment(map, '/components/schemas/Object')
  ///  == getFragment(map, 'components/schemas/Object');
  ///
  /// getFragment(map, '/components/schemas/Object');
  ///   == map['components']['schemas']['Object']
  /// ```
  static dynamic getFragment(dynamic map, String fragment) {
    fragment = fragment.startsWith('/') ? fragment.substring(1) : fragment;
    if (fragment.isEmpty) {
      return map;
    }
    return getFragment(
      (map as Map).cast<String, dynamic>()[fragment.split('/')[0]],
      fragment.contains('/') ? fragment.substring(fragment.indexOf('/')) : '',
    );
  }
}

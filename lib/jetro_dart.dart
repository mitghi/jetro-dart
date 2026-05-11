/// Dart / Flutter API for [jetro](https://github.com/mitghi/jetro).
///
/// Usage:
/// ```dart
/// final j = Jetro.fromBytes(utf8.encode('{"x":1}'));
/// final out = j.collect(r'$.x');     // -> 1
/// j.dispose();
/// ```
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'src/bindings.dart' as ffi;

class JetroException implements Exception {
  JetroException(this.message);
  final String message;
  @override
  String toString() => 'JetroException: $message';
}

/// Single-document query handle. Caller is responsible for [dispose].
class Jetro {
  Jetro._(this._handle);

  final Pointer<ffi.JetroHandle> _handle;
  bool _disposed = false;

  /// Build a [Jetro] from raw JSON bytes.
  ///
  /// The bytes are copied into the Rust side; the caller can free the
  /// input buffer immediately after this returns.
  static Jetro fromBytes(List<int> jsonBytes) {
    final len = jsonBytes.length;
    final ptr = malloc.allocate<Uint8>(len);
    try {
      ptr.asTypedList(len).setRange(0, len, jsonBytes);
      final h = ffi.jetroNew(ptr, len);
      if (h == nullptr) {
        throw JetroException('failed to parse JSON document');
      }
      return Jetro._(h);
    } finally {
      malloc.free(ptr);
    }
  }

  /// Convenience: build from a UTF-8 string.
  static Jetro fromString(String jsonText) =>
      fromBytes(utf8.encode(jsonText));

  /// Evaluate `expr` against this document and return the result as
  /// raw JSON bytes. Skip [collect] when you do not need the value
  /// materialised into Dart maps / lists.
  Uint8List collectJsonBytes(String expr) {
    if (_disposed) throw StateError('Jetro disposed');
    final eb = utf8.encode(expr);
    final ep = malloc.allocate<Uint8>(eb.length);
    ep.asTypedList(eb.length).setRange(0, eb.length, eb);
    final r = ffi.jetroCollect(_handle, ep, eb.length);
    malloc.free(ep);
    try {
      if (ffi.jetroResultOk(r) == 0) {
        final n = ffi.jetroResultLen(r);
        final p = ffi.jetroResultData(r);
        final msg = utf8.decode(p.asTypedList(n));
        throw JetroException(msg);
      }
      final n = ffi.jetroResultLen(r);
      final p = ffi.jetroResultData(r);
      return Uint8List.fromList(p.asTypedList(n));
    } finally {
      ffi.jetroResultFree(r);
    }
  }

  /// Evaluate `expr` and decode the result into native Dart values
  /// (`null` / `bool` / `int` / `double` / `String` / `List` / `Map`).
  Object? collect(String expr) =>
      json.decode(utf8.decode(collectJsonBytes(expr)));

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ffi.jetroFree(_handle);
  }
}

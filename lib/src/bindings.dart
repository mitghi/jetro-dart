// Native Assets bindings. The Dart build hook (`hook/build.dart`)
// emits a `NativeCodeAsset` keyed to this library path, so the
// `@Native` lookups below resolve to the bundled `libjetro_dart`
// without any `DynamicLibrary.open` call from user code.
//
// Pure-Dart consumers (CLI / server) and Flutter consumers (with
// `flutter config --enable-native-assets`) share this file unchanged.

import 'dart:ffi';

final class JetroHandle extends Opaque {}

final class JetroResult extends Opaque {}

@Native<Pointer<JetroHandle> Function(Pointer<Uint8>, UintPtr)>(
    symbol: 'jetro_new')
external Pointer<JetroHandle> jetroNew(Pointer<Uint8> bytes, int len);

@Native<Void Function(Pointer<JetroHandle>)>(symbol: 'jetro_free')
external void jetroFree(Pointer<JetroHandle> handle);

@Native<
    Pointer<JetroResult> Function(
        Pointer<JetroHandle>, Pointer<Uint8>, UintPtr)>(symbol: 'jetro_collect')
external Pointer<JetroResult> jetroCollect(
    Pointer<JetroHandle> handle, Pointer<Uint8> expr, int exprLen);

@Native<Int32 Function(Pointer<JetroResult>)>(symbol: 'jetro_result_ok')
external int jetroResultOk(Pointer<JetroResult> result);

@Native<Pointer<Uint8> Function(Pointer<JetroResult>)>(
    symbol: 'jetro_result_data')
external Pointer<Uint8> jetroResultData(Pointer<JetroResult> result);

@Native<UintPtr Function(Pointer<JetroResult>)>(symbol: 'jetro_result_len')
external int jetroResultLen(Pointer<JetroResult> result);

@Native<Void Function(Pointer<JetroResult>)>(symbol: 'jetro_result_free')
external void jetroResultFree(Pointer<JetroResult> result);

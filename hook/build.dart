// Build hook for the `jetro_dart` package, invoked by Dart's
// `package:hooks` pipeline at `dart run` / `flutter build` time.
//
// Strategy
//   1. Identify the target triple (OS + arch).
//   2. Try to download a prebuilt `libjetro_dart.{dylib,so,dll}` from
//      this package's GitHub Release matching the package version. The
//      release artifact name encodes the target triple.
//   3. If the download fails (no release, offline, unsupported target),
//      fall back to invoking `cargo build --release` against the
//      bundled Rust workspace in `rust/`.
//   4. Register the resulting library as a `CodeAsset` keyed to
//      `package:jetro_dart/src/bindings.dart` so the `@Native<...>`
//      lookups in that file resolve to the bundled cdylib.
//
// The hook is intentionally permissive: prebuilt binary first (fast,
// no toolchain required); source build as a guaranteed fallback for
// any reasonable host with a Rust toolchain installed.

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

const _releaseBaseUrl =
    'https://github.com/mitghi/jetro-dart/releases/download';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final code = input.config.code;
    final pkgUri = input.packageRoot;
    final pkgVersion = _readVersion(pkgUri);
    final triple = _targetTriple(code.targetOS, code.targetArchitecture);
    final libFileName = _libFileName(code.targetOS);

    final outDir = input.outputDirectory.toFilePath();
    Directory(outDir).createSync(recursive: true);
    final libPath = '$outDir/$libFileName';

    var resolved = await _tryDownloadPrebuilt(
      version: pkgVersion,
      triple: triple,
      libFileName: libFileName,
      destination: libPath,
    );

    if (!resolved) {
      stderr.writeln(
          'jetro_dart: prebuilt binary unavailable for $triple, '
          'falling back to cargo build from source...');
      resolved = _buildFromSource(
        packageRoot: pkgUri,
        destination: libPath,
        libFileName: libFileName,
      );
    }

    if (!resolved) {
      throw StateError(
          'jetro_dart: could not provide a native library for $triple. '
          'Install rustup + run `cargo --version`, or open an issue at '
          'https://github.com/mitghi/jetro-dart/issues with your target '
          'platform.');
    }

    output.assets.code.add(CodeAsset(
      package: 'jetro_dart',
      name: 'src/bindings.dart',
      linkMode: DynamicLoadingBundled(),
      file: Uri.file(libPath),
    ));
  });
}

String _readVersion(Uri packageRoot) {
  final pubspec = File.fromUri(packageRoot.resolve('pubspec.yaml'));
  for (final line in pubspec.readAsLinesSync()) {
    final m = RegExp(r'^version:\s*([^\s#]+)').firstMatch(line);
    if (m != null) return m.group(1)!;
  }
  return '0.0.0';
}

String _targetTriple(OS os, Architecture arch) {
  if (os == OS.macOS) {
    if (arch == Architecture.arm64) return 'aarch64-apple-darwin';
    if (arch == Architecture.x64) return 'x86_64-apple-darwin';
  } else if (os == OS.linux) {
    if (arch == Architecture.x64) return 'x86_64-unknown-linux-gnu';
    if (arch == Architecture.arm64) return 'aarch64-unknown-linux-gnu';
  } else if (os == OS.windows) {
    if (arch == Architecture.x64) return 'x86_64-pc-windows-msvc';
    if (arch == Architecture.arm64) return 'aarch64-pc-windows-msvc';
  } else if (os == OS.iOS) {
    if (arch == Architecture.arm64) return 'aarch64-apple-ios';
    if (arch == Architecture.x64) return 'x86_64-apple-ios';
  } else if (os == OS.android) {
    if (arch == Architecture.arm64) return 'aarch64-linux-android';
    if (arch == Architecture.arm) return 'armv7-linux-androideabi';
    if (arch == Architecture.x64) return 'x86_64-linux-android';
  }
  return '$arch-$os';
}

String _libFileName(OS os) {
  if (os == OS.macOS || os == OS.iOS) return 'libjetro_dart.dylib';
  if (os == OS.windows) return 'jetro_dart.dll';
  return 'libjetro_dart.so';
}

Future<bool> _tryDownloadPrebuilt({
  required String version,
  required String triple,
  required String libFileName,
  required String destination,
}) async {
  final assetName = 'jetro_dart-v$version-$triple-$libFileName';
  final url = Uri.parse('$_releaseBaseUrl/v$version/$assetName');
  final client = HttpClient();
  try {
    final req = await client.getUrl(url);
    final resp = await req.close();
    if (resp.statusCode != 200) {
      await resp.drain();
      return false;
    }
    final out = File(destination).openWrite();
    await resp.pipe(out);
    return true;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

bool _buildFromSource({
  required Uri packageRoot,
  required String destination,
  required String libFileName,
}) {
  final rustDir = packageRoot.resolve('rust/').toFilePath();
  if (!Directory(rustDir).existsSync()) return false;
  final cargo = Process.runSync(
    'cargo',
    ['build', '--release', '--manifest-path', '$rustDir/Cargo.toml'],
    runInShell: true,
  );
  if (cargo.exitCode != 0) {
    stderr.writeln(cargo.stdout);
    stderr.writeln(cargo.stderr);
    return false;
  }
  final built = packageRoot
      .resolve('target/release/')
      .resolve(libFileName)
      .toFilePath();
  if (!File(built).existsSync()) return false;
  File(built).copySync(destination);
  return true;
}

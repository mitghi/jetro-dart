# Changelog

## 0.1.1

- Bump `jetro-core` to 0.5.8.

## 0.1.0

- Initial release.
- Dart / Flutter bindings for [jetro](https://github.com/mitghi/jetro) via
  `package:hooks` Native Assets.
- Build hook downloads prebuilt cdylib from GitHub Releases, falls back to
  `cargo build --release` against the bundled Rust workspace.
- Cold-run benchmark harness covering 24 cases from `bench_cold.rs`,
  comparing jetro against hand-written Dart and `jsonata_dart`.
- C ABI: `jetro_new` / `jetro_collect` / `jetro_free` plus four result
  accessors.

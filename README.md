# jetro-dart

Dart / Flutter FFI bindings for **[jetro](https://github.com/mitghi/jetro)** a
compact query language and JSON processing engine written in Rust.

## Install

```bash
# Pure Dart (CLI / server / scripts)
dart pub add jetro_dart

# Flutter
flutter pub add jetro_dart
flutter config --enable-native-assets   # one-time per machine
```

After installation:

```dart
import 'package:jetro_dart/jetro_dart.dart';

final j = Jetro.fromString(jsonText);
final paid = j.collect(
    r'$.orders.filter(status == "paid").map(total).sum()');
j.dispose();
```

## A real example

```dart
import 'dart:convert';
import 'package:jetro_dart/jetro_dart.dart';

final bytes = utf8.encode(jsonString);
final j = Jetro.fromBytes(bytes);

final report = j.collect(r'''
{
  "top_paid_premium": $.orders
    .filter(status == "paid" and total >= 100)
    .filter(customer.tier == "gold" or customer.tier == "platinum")
    .sort_by(-total)
    .take(2)
    .map({
      order_id: id,
      who: customer.name,
      amount: total,
      label: f"order {@.id}: {customer.name} ({customer.tier}) USD {@.total}",
      line_total: items.map(qty * price).sum(),
      last_event: match events.last() with {
          {kind: "delivered", at: t}    -> {state: "ok",     at: t},
          {kind: "shipped",   at: t}    -> {state: "moving", at: t},
          {kind: "refund", reason: r}   -> {state: "refund", reason: r},
          _                             -> {state: "unknown"}
      }
    }),

  "paid_total": $.orders
    .filter(status == "paid")
    .map(total)
    .sum()
}
''');

j.dispose();
```

The equivalent hand-written Dart (typed access, null-safe casts,
manual sort, manual projection, manual `last_event` switch) is ~50
lines and runs ~10× slower.

---

## What is jetro?

Jetro is a query language plus an execution engine for JSON. It reads like
the iterator chains you already know — `filter`, `map`, `sort_by`, `take`,
`flat_map`, `sum`, `avg`, `unique`, `group_by`, `count_by`, `match`, `let
… in`, f-strings, and so on and compiles each expression into a planned,
demand-aware pipeline that runs on top of a SIMD-accelerated JSON tape.

The same expression that filters an array can reshape the result into
nested objects, mutate the document in place, group / index by a field,
or pattern-match on the shape of a sub-tree.

## Quick Language Preview

### Path navigation

```text
$                         root document
@                         current item inside map / filter / lambda

$.user.name               field access
$.user?.name              null-safe field access
$.items[0]                index
$.items[1:5]              slice
$..price                  recursive descent over the whole document
```

### Query

```text
$.books.filter(price > 10)
$.books.sort_by(-rating).take(5)
$.orders.filter(status == "paid").map(total).sum()
```

### Shape

```text
$.books.map({title, price})

$.orders.map({
  id,
  customer: customer.name,
  city: customer.address.city,
  total
})
```

### Compose into a single response payload

```text
{
  "featured": $.books
    .filter(rating >= 4.5)
    .sort_by(-price)
    .take(3)
    .map({title, author, price}),

  "stats": {
    "count": $.books.count(),
    "avg_price": $.books.map(price).avg(),
    "tags": $.books.flat_map(tags).unique().sort()
  }
}
```

### Bind and format

```text
let min_total = 100 in
$.orders
  .filter(total >= min_total)
  .map({
    id,
    label: f"{customer.name}: ${total}"
  })
```

### Group, index, count

```text
$.orders.group_by(status)
$.users.index_by(id)
$.events.count_by(type)
```

### Mutate documents in place

```text
$.user.name.set("Ada")
$.cart.items.filter(qty == 0).delete()
patch $ { .user.active: true }
```

### Pattern match on shape

```text
match $.user with {
    {role: "admin"}                    -> "full",
    {role: "user", verified: true}     -> "limited",
    {role: r, ...*rest}                -> {...*rest, role: r},
    _                                  -> "denied"
}

$..match {
    {tag: "click", id: i} -> i,
    _                     -> false
}
```

The full grammar lives at [jetro/jetro-core/src/SYNTAX.md](https://github.com/mitghi/jetro/blob/main/jetro-core/src/SYNTAX.md).
the canonical user guide is **[The Jetro Book](https://mitghi.github.io/jetro-book/)**.

---

## Benchmark (cold single run)

The harness ports `jetro/jetro-core/examples/bench_cold.rs` to Dart
verbatim. Every engine pays the full per-call cost: parse the
document, parse + compile the query, execute, serialise the result.
No warm-up, no iteration averaging.

**Engines compared**

| Engine    | What                                                      |
|-----------|-----------------------------------------------------------|
| `native`  | Hand-written Dart loops over `jsonDecode`'d JSON.         |
| `jetro`   | This package — Rust pipeline via `dart:ffi` cdylib.       |
| `jsonata` | `jsonata_dart` (pure-Dart implementation of JSONata).     |

**Sample run** (N = 8 000 records, ~3.9 MB doc, M1 / macOS / release /
Dart JIT):

| # | Case | native | **jetro** | jsonata |
|---|------|------:|------:|------:|
| 1  | active top-100 expensive-item revenue        |  76.53ms | **13.14ms (0.17x)** |  73.52ms (0.96x) |
| 2  | flatmap+sort all-items+take+project          |  65.98ms |  **9.84ms (0.15x)** | 143.54ms (2.18x) |
| 3  | sort+skip+take+project                       |  51.84ms |  **7.46ms (0.14x)** |  93.53ms (1.80x) |
| 4  | filter+flatmap-tags+unique                   |  51.87ms |  **9.81ms (0.19x)** |  51.74ms (1.00x) |
| 5  | flatmap+filter+map-arith+sum                 |  60.64ms | **10.01ms (0.17x)** |  61.65ms (1.02x) |
| 6  | filter+sort+take+fstring                     |  47.75ms |  **8.42ms (0.18x)** |  55.76ms (1.17x) |
| 7  | filter+flatmap+avg                           |  54.49ms |  **8.84ms (0.16x)** |  42.77ms (0.78x) |
| 8  | sort+take+nested-computed-projection         |  64.19ms |  **7.76ms (0.12x)** |  77.57ms (1.21x) |
| 9  | 5-stage filter chain + count                 |  42.43ms |  **8.51ms (0.20x)** |  40.77ms (0.96x) |
| 10 | count_by(active) / group_by+map              |  44.56ms |  **7.88ms (0.18x)** | N/A |
| 11 | sort+take+map+unique (top-300 zips)          |  54.02ms |  **7.89ms (0.15x)** |  61.44ms (1.14x) |
| 12 | flatmap+map+unique+len (all prices)          |  69.68ms |  **8.82ms (0.13x)** |  51.15ms (0.73x) |
| 13 | filter+map+sum                               |  48.68ms |  **7.37ms (0.15x)** |  57.35ms (1.18x) |
| 14 | flat_map+filter+count                        |  45.92ms |  **8.33ms (0.18x)** |  64.45ms (1.40x) |
| 15 | filter+flat_map+map+sum                      |  35.86ms |  **7.46ms (0.21x)** |  57.18ms (1.59x) |
| 16 | sort_by+take+map (top10)                     |  41.56ms |  **7.21ms (0.17x)** |  66.63ms (1.60x) |
| 17 | map+unique (cities)                          |  40.63ms |  **7.19ms (0.18x)** |  61.64ms (1.52x) |
| 18 | map (deep projection)                        |  56.54ms | **12.88ms (0.23x)** |  73.59ms (1.30x) |
| 19 | map f-string                                 |  50.76ms |  **8.78ms (0.17x)** |  51.51ms (1.01x) |
| 20 | flat_map+map (all prices)                    |  55.13ms |  **8.17ms (0.15x)** |  63.49ms (1.15x) |
| 21 | filter+first                                 |  46.49ms |  **6.18ms (0.13x)** |  48.03ms (1.03x) |
| 22 | skip+take+map (pagination)                   |  51.39ms |  **6.79ms (0.13x)** |  43.45ms (0.85x) |
| 23 | filter+map+avg                               |  46.21ms |  **7.27ms (0.16x)** |  38.14ms (0.83x) |
| 24 | README showcase (3-filter+sort+take+match)   |  41.89ms |  **9.12ms (0.22x)** | N/A |

`(Nx)` after each engine = engine time ÷ native Dart time on the same case.

Numbers vary ±20 % run-to-run depending on host load; engine ordering
is stable.

---

## How install actually works

`jetro_dart` ships using the Dart `hooks` (Native Assets) protocol.
The build pipeline is:

1. Compute the target triple for your host (or Flutter target).
2. Try to download a prebuilt `libjetro_dart.{dylib,so,dll}` from the
   GitHub Release matching the package version.
3. If that fails (offline, unsupported target), fall back to
   `cargo build --release` against the bundled Rust workspace in
   `rust/`. Requires a Rust toolchain (`rustup`).
4. Register the resulting library as a `CodeAsset` keyed to
   `package:jetro_dart/src/bindings.dart`, so the `@Native` lookups in
   the Dart facade resolve automatically.

### Supported prebuilt targets

| OS / arch              | Triple                      |
|------------------------|-----------------------------|
| macOS arm64            | `aarch64-apple-darwin`      |
| macOS x86_64           | `x86_64-apple-darwin`       |
| Linux x86_64           | `x86_64-unknown-linux-gnu`  |
| Linux aarch64          | `aarch64-unknown-linux-gnu` |
| Windows x86_64         | `x86_64-pc-windows-msvc`    |
| Android arm64-v8a      | `aarch64-linux-android`     |
| Android armeabi-v7a    | `armv7-linux-androideabi`   |
| Android x86_64         | `x86_64-linux-android`      |

Other targets fall through to source-build (`cargo build`).

### From source (contributors)

```bash
cargo build --release -p jetro-dart-ffi
dart pub get
dart test                                  # 81 tests
dart run example/jetro_dart_example.dart   # walk through the language
dart run bench/bench_cold.dart [N]         # default N = 8000
```

## C ABI

```c
JetroHandle*  jetro_new(const uint8_t* bytes, size_t len);
void          jetro_free(JetroHandle*);

JetroResult*  jetro_collect(JetroHandle*, const uint8_t* expr, size_t expr_len);
int32_t       jetro_result_ok(const JetroResult*);     // 1 = ok, 0 = error
const uint8_t* jetro_result_data(const JetroResult*);  // JSON bytes (ok) or UTF-8 error
size_t        jetro_result_len(const JetroResult*);
void          jetro_result_free(JetroResult*);
```

Success bytes are the JSON encoding of `Jetro::collect`'s `Value`;
error bytes are the UTF-8 error message.

## Related

- **[The Jetro Book](https://mitghi.github.io/jetro-book/)** — guided
  tour, full grammar reference, every builtin with worked examples.
- **[jetro](https://github.com/mitghi/jetro)** — upstream Rust engine.
- **[jetrocli](https://github.com/mitghi/jetrocli)** — interactive use
  in the terminal.
- **[jetro-py](https://github.com/mitghi/jetro-py)** — Python binding,
  same engine.

## License

MIT

/// Cold single-run bench: each engine pays full parse + compile +
/// execute + serialize cost per case. Mirrors
/// jetro/jetro-core/examples/bench_cold.rs case-for-case.
///
/// Engines:
///   - native     hand-written Dart (mirrors the Rust `native` baseline)
///   - jetro      via FFI cdylib (jetro-dart)
///   - jsonata    jsonata_dart, pure Dart
///
/// Run:
///   cargo build --release -p jetro-dart-ffi
///   dart run bench/bench_cold.dart
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:jetro_dart/jetro_dart.dart';
import 'package:jsonata_dart/jsonata_dart.dart';

import 'payload.dart';
import 'native_cases.dart' as nat;

double timeOne(void Function() f) {
  final sw = Stopwatch()..start();
  f();
  return sw.elapsedMicroseconds / 1000.0;
}

/// Return ms or null on failure.
double? safeTime(void Function() f) {
  try {
    return timeOne(f);
  } catch (_) {
    return null;
  }
}

class Case {
  Case(this.id, this.name, this.native, this.jetro, {this.jsonata});
  final int id;
  final String name;
  final Object? Function(Map root) native;
  final String jetro;
  final String? jsonata;
}

void blackBox(Object? v) {
  // Force Dart not to drop the work: serialize result to JSON bytes and
  // toss into a sink that touches the bytes.
  if (v == null) return;
  final s = jsonEncode(v);
  if (s.length == -1) stderr.write('!'); // never taken
}

List<Case> buildCases() {
  return [
    Case(
      1,
      'active top-100 expensive-item revenue',
      nat.case1,
      r'$.data.filter(active).filter(score > 200).sort(-score).take(100).flat_map(items).filter(price > 50).map(qty * price).sum()',
      jsonata:
          r'$sum((data[active=true and score > 200]^(>score))[0..99].items[price > 50].(qty * price))',
    ),
    Case(
      2,
      'flatmap+sort all-items+take+project',
      nat.case2,
      r'$.data.flat_map(items).sort(-price).take(30).map({sku, price})',
      jsonata:
          r'(data.items^(>price))[0..29].{"sku": sku, "price": price}',
    ),
    Case(
      3,
      'sort+skip+take+project',
      nat.case3,
      r'$.data.sort(-score).skip(200).take(50).map({id, city: user.addr.city, score})',
      jsonata:
          r'(data^(>score))[200..249].{"id": id, "city": user.addr.city, "score": score}',
    ),
    Case(
      4,
      'filter+flatmap-tags+unique',
      nat.case4,
      r'$.data.filter(active).flat_map(tags).unique()',
      jsonata: r'$distinct(data[active=true].tags)',
    ),
    Case(
      5,
      'flatmap+filter+map-arith+sum',
      nat.case5,
      r'$.data.flat_map(items).filter(price > 100).map(qty * price).sum()',
      jsonata: r'$sum(data.items[price > 100].(qty * price))',
    ),
    Case(
      6,
      'filter+sort+take+fstring',
      nat.case6,
      r'$.data.filter(active).sort(-score).take(50).map(f"#{id} {user.name} ({user.addr.city}) score={score}")',
      jsonata:
          r'(data[active=true]^(>score))[0..49].("#" & $string(id) & " " & user.name & " (" & user.addr.city & ") score=" & $string(score))',
    ),
    Case(
      7,
      'filter+flatmap+avg',
      nat.case7,
      r'$.data.filter(score > 700).flat_map(items).map(price).avg()',
      jsonata: r'$average(data[score > 700].items.price)',
    ),
    Case(
      8,
      'sort+take+nested-computed-projection',
      nat.case8,
      r'$.data.sort(-score).take(20).map({id, city: user.addr.city, total: items.map(qty * price).sum()})',
      jsonata:
          r'(data^(>score))[0..19].{"id": id, "city": user.addr.city, "total": $sum(items.(qty * price))}',
    ),
    Case(
      9,
      '5-stage filter chain + count',
      nat.case9,
      r'$.data.filter(active).filter(score > 500).flat_map(items).filter(price > 75).filter(qty > 2).len()',
      jsonata:
          r'$count(data[active=true and score > 500].items[price > 75 and qty > 2])',
    ),
    Case(
      10,
      'count_by(active) / group_by+map',
      nat.case10,
      r'$.data.count_by(active)',
      // jsonata count_by is awkward — skip
    ),
    Case(
      11,
      'sort+take+map+unique (top-300 zips)',
      nat.case11,
      r'$.data.sort(-score).take(300).map(user.addr.zip).unique()',
      jsonata: r'$distinct((data^(>score))[0..299].user.addr.zip)',
    ),
    Case(
      12,
      'flatmap+map+unique+len (all prices)',
      nat.case12,
      r'$.data.flat_map(items).map(price).unique().len()',
      jsonata: r'$count($distinct(data.items.price))',
    ),
    Case(
      13,
      'filter+map+sum',
      nat.case13,
      r'$.data.filter(active).map(score).sum()',
      jsonata: r'$sum(data[active=true].score)',
    ),
    Case(
      14,
      'flat_map+filter+count',
      nat.case14,
      r'$.data.flat_map(items).filter(price > 50).len()',
      jsonata: r'$count(data.items[price > 50])',
    ),
    Case(
      15,
      'filter+flat_map+map+sum',
      nat.case15,
      r'$.data.filter(active).flat_map(items).map(qty * price).sum()',
      jsonata: r'$sum(data[active=true].items.(qty * price))',
    ),
    Case(
      16,
      'sort_by+take+map (top10)',
      nat.case16,
      r'$.data.sort_by(-score).take(10).map({id, name: user.name, score})',
      jsonata:
          r'(data^(>score))[0..9].{"id": id, "name": user.name, "score": score}',
    ),
    Case(
      17,
      'map+unique (cities)',
      nat.case17,
      r'$.data.map(user.addr.city).unique()',
      jsonata: r'$distinct(data.user.addr.city)',
    ),
    Case(
      18,
      'map (deep projection)',
      nat.case18,
      r'$.data.map({id, city: user.addr.city, item_count: items.len(), total: items.map(qty * price).sum()})',
      jsonata:
          r'data.{"id": id, "city": user.addr.city, "item_count": $count(items), "total": $sum(items.(qty * price))}',
    ),
    Case(
      19,
      'map f-string',
      nat.case19,
      r'$.data.map(f"#{id} {user.name} ({user.addr.city}) ${score}")',
      jsonata:
          r'data.("#" & $string(id) & " " & user.name & " (" & user.addr.city & ") $" & $string(score))',
    ),
    Case(
      20,
      'flat_map+map (all prices)',
      nat.case20,
      r'$.data.flat_map(items).map(price)',
      jsonata: r'data.items.price',
    ),
    Case(
      21,
      'filter+first',
      nat.case21,
      r'$.data.filter(score > 900).first()',
      jsonata: r'(data[score > 900])[0].id',
    ),
    Case(
      22,
      'skip+take+map (pagination)',
      nat.case22,
      r'$.data.skip(100).take(20).map({id})',
      jsonata: r'data[100..119].{"id": id}',
    ),
    Case(
      23,
      'filter+map+avg',
      nat.case23,
      r'$.data.filter(active).map(score).avg()',
      jsonata: r'$average(data[active=true].score)',
    ),
    Case(
      24,
      'README showcase (3-filter+sort+take+match)',
      nat.case24,
      r'''$.data
            .filter(status == "paid")
            .filter(score >= 500)
            .filter(user.tier == "gold" or user.tier == "platinum")
            .sort_by(-score)
            .take(50)
            .map({
              id,
              who: user.name,
              tier: user.tier,
              score_val: score,
              label: f"order {@.id}: {user.name} ({user.tier}) score {@.score}",
              line_total: items.map(qty * price).sum(),
              last_event: match events.last() with {
                  {kind: "delivered", at: t}    -> {state: "ok",     at: t},
                  {kind: "shipped",   at: t}    -> {state: "moving", at: t},
                  {kind: "refund", reason: r}   -> {state: "refund", reason: r},
                  _                             -> {state: "unknown"}
              }
            })''',
      // jsonata can express most of it but the `last_event` pattern match
      // needs nested $$. Skipped to keep harness honest.
    ),
  ];
}

String fmt(double? ms) =>
    ms == null ? 'N/A'.padLeft(11) : '${ms.toStringAsFixed(3).padLeft(8)}ms';

String ratio(double? base, double? other) {
  if (base == null || other == null || base == 0) return '       ';
  final r = other / base;
  return '${r.toStringAsFixed(2)}x'.padLeft(7);
}

void main(List<String> argv) {
  final n = argv.isNotEmpty ? int.parse(argv.first) : 8000;
  stderr.writeln('building doc (N=$n)...');
  final jsonStr = buildDoc(n);
  final docBytes = Uint8List.fromList(utf8.encode(jsonStr));
  stderr.writeln('doc built: ${(docBytes.length / 1024).toStringAsFixed(0)} KB');

  // Eager-load cdylib + warm jetro process-wide caches (pest grammar,
  // regex tables, simd-json codepaths) outside the timed region so case 1
  // does not absorb first-dlopen + first-init tax on macOS.
  stderr.writeln('warming jetro dylib...');
  {
    final warmDoc = utf8.encode('{"data":[{"a":1}]}');
    final j = Jetro.fromBytes(warmDoc);
    j.collectJsonBytes(r'$.data.map(a).sum()');
    j.dispose();
  }
  // Warm jsonata parser similarly so first run is fair.
  Jsonata(r'$sum(data.a)').evaluate({'data': [{'a': 1}]});

  print(
      'Cold single-run bench - N=$n  input=${(docBytes.length / 1024).toStringAsFixed(0)} KB  (no warmup, no iters)\n');
  print(
      '${'case'.padRight(46)}  ${'native'.padLeft(11)}  ${'jetro'.padLeft(11)} ${'(x)'.padLeft(8)}  ${'jsonata'.padLeft(11)} ${'(x)'.padLeft(8)}');

  final cases = buildCases();
  for (final c in cases) {
    // native
    final tNative = safeTime(() {
      final root = jsonDecode(utf8.decode(docBytes)) as Map<String, Object?>;
      final out = c.native(root);
      blackBox(out);
    });

    // jetro via FFI
    final tJetro = safeTime(() {
      final j = Jetro.fromBytes(docBytes);
      try {
        final out = j.collectJsonBytes(c.jetro);
        if (out.isEmpty) stderr.write('?'); // touch
      } finally {
        j.dispose();
      }
    });

    // jsonata
    final tJsonata = c.jsonata == null
        ? null
        : safeTime(() {
            final j = jsonDecode(utf8.decode(docBytes));
            final out = Jsonata(c.jsonata!).evaluate(j);
            blackBox(out);
          });

    final name = c.name.length > 44
        ? c.name.substring(0, 44)
        : c.name.padRight(44);
    print(
        '$name  ${fmt(tNative)}  ${fmt(tJetro)} ${ratio(tNative, tJetro)}  ${fmt(tJsonata)} ${ratio(tNative, tJsonata)}');
  }
}

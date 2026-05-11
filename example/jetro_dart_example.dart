/// End-to-end example for `jetro_dart`. Generates the same synthetic
/// document as the cold-run benchmark (`bench/bench_cold.dart`) and
/// runs a handful of representative queries against it:
///
///   1. top-N aggregation chain (`filter`, `sort_by`, `take`, `map`)
///   2. cross-array fan-out + reduction (`flat_map`, `filter`, `sum`)
///   3. grouping (`group_by`, `count_by`)
///   4. pattern-match projection (`match … with`)
///   5. f-string formatting and `let … in` binding
///   6. in-place mutation (`patch`)
///
/// Run from the package root:
/// ```bash
/// dart run example/jetro_dart_example.dart
/// ```
library;

import 'dart:convert';

import 'package:jetro_dart/jetro_dart.dart';

import '../bench/payload.dart';

void main() {
  // Build a ~3.9 MB synthetic document (N = 8 000 orders).
  final document = buildDoc(8000);
  final j = Jetro.fromString(document);

  print('--- 1. Top 5 paid orders for gold/platinum customers ---');
  final topPaid = j.collect(r'''
    $.data
      .filter(status == "paid")
      .filter(user.tier == "gold" or user.tier == "platinum")
      .sort_by(-score)
      .take(5)
      .map({
        id,
        who: user.name,
        tier: user.tier,
        score,
        line_total: items.map(qty * price).sum()
      })
  ''');
  print(const JsonEncoder.withIndent('  ').convert(topPaid));

  print('\n--- 2. Total revenue for active customers (one expression) ---');
  final revenue = j.collect(
      r'$.data.filter(active).flat_map(items).map(qty * price).sum()');
  print('revenue = $revenue');

  print('\n--- 3. count_by(active) ---');
  final counts = j.collect(r'$.data.count_by(active)');
  print(counts);

  print('\n--- 4. Pattern-match on the last event ---');
  final classified = j.collect(r'''
    $.data
      .filter(score > 950)
      .take(3)
      .map({
        id,
        last_event: match events.last() with {
          {kind: "delivered", at: t}    -> {state: "ok",     at: t},
          {kind: "shipped",   at: t}    -> {state: "moving", at: t},
          {kind: "refund", reason: r}   -> {state: "refund", reason: r},
          _                             -> {state: "unknown"}
        }
      })
  ''');
  print(const JsonEncoder.withIndent('  ').convert(classified));

  print('\n--- 5. f-string + let-in ---');
  final formatted = j.collect(r'''
    let cutoff = 900 in
    $.data
      .filter(score > cutoff)
      .take(3)
      .map(f"#{id} {user.name} ({user.addr.city}) score={score}")
  ''');
  print(formatted);

  print('\n--- 6. Mutation (.set) ---');
  // Build a small handle so the encoded result is short enough to print.
  final small = Jetro.fromString(jsonEncode({
    'user': {'name': 'old', 'active': false}
  }));
  final renamed = small.collect(r'$.user.name.set("Ada")');
  print(renamed);
  small.dispose();

  j.dispose();
}

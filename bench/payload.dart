/// Byte-for-byte port of `build_doc(n)` from
/// jetro/jetro-core/examples/bench_cold.rs. Generates the same JSON
/// document so all engines bench against identical input.
library;

String buildDoc(int n) {
  final cities = [
    'NYC', 'SF', 'LA', 'Boston', 'Seattle', 'Austin', 'Miami', 'Chicago'
  ];
  final statuses = ['paid', 'refunded', 'cancelled'];
  final tiers = ['gold', 'silver', 'platinum', 'bronze'];

  final b = StringBuffer('{"data":[');
  for (var i = 0; i < n; i++) {
    if (i > 0) b.write(',');
    final city = cities[i % cities.length];
    final status = statuses[i % statuses.length];
    final tier = tiers[(i ~/ 3) % tiers.length];

    final items = StringBuffer('[');
    final itemCount = 3 + (i % 5);
    for (var k = 0; k < itemCount; k++) {
      if (k > 0) items.write(',');
      final qty = (k + 1) * 2;
      final price = ((i * 7 + k * 13) % 200).toDouble() + 9.99;
      items.write('{"sku":"S${i}_$k","qty":$qty,"price":$price}');
    }
    items.write(']');

    String lastKind;
    switch (i % 4) {
      case 0:
        lastKind = 'delivered';
        break;
      case 1:
        lastKind = 'shipped';
        break;
      case 2:
        lastKind = 'refund';
        break;
      default:
        lastKind = 'placed';
    }
    final d1 = (i % 27) + 1;
    final d2 = ((i + 1) % 27) + 1;
    final d3 = ((i + 2) % 27) + 1;
    final p2 = d1.toString().padLeft(2, '0');
    final p2b = d2.toString().padLeft(2, '0');
    final p2c = d3.toString().padLeft(2, '0');

    String events;
    if (lastKind == 'refund') {
      events =
          '[{"kind":"placed","at":"2025-04-${p2}T10:00:00Z"},{"kind":"refund","reason":"r${i % 5}"}]';
    } else if (lastKind == 'placed') {
      events = '[{"kind":"placed","at":"2025-04-${p2}T10:00:00Z"}]';
    } else {
      events =
          '[{"kind":"placed","at":"2025-04-${p2}T10:00:00Z"},{"kind":"shipped","at":"2025-04-${p2b}T08:00:00Z"},{"kind":"${lastKind}","at":"2025-04-${p2c}T17:00:00Z"}]';
    }

    final age = 18 + (i % 60);
    final zip = 10000 + (i % 1000);
    final t0 = i % 5;
    final t1 = (i + 1) % 5;
    final t2 = (i + 2) % 5;
    final active = (i % 3 == 0) ? 'true' : 'false';
    final score = (i * 37) % 1000;

    b.write(
        '{"id":$i,"user":{"name":"user_$i","age":$age,"addr":{"city":"$city","zip":"$zip"},"tier":"$tier"},"items":$items,"tags":["t$t0","t$t1","t$t2"],"active":$active,"score":$score,"status":"$status","events":$events}');
  }
  b.write(']}');
  return b.toString();
}

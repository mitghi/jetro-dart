/// Native-Dart implementations of each cold-bench case.
/// Each function takes the already-decoded root map `{"data": [...]}` and
/// returns the result (or null) to keep work alive.
library;

import 'dart:convert';

Object case1(Map root) {
  final data = (root['data'] as List).cast<Map>();
  final active = <Map>[];
  for (final r in data) {
    if (r['active'] == true && (r['score'] as num) > 200) active.add(r);
  }
  active.sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
  double total = 0;
  final take = active.length < 100 ? active.length : 100;
  for (var i = 0; i < take; i++) {
    final items = (active[i]['items'] as List).cast<Map>();
    for (final it in items) {
      final p = (it['price'] as num).toDouble();
      if (p > 50.0) total += (it['qty'] as num).toDouble() * p;
    }
  }
  return total;
}

Object case2(Map root) {
  final data = (root['data'] as List).cast<Map>();
  final all = <List<Object>>[];
  for (final r in data) {
    for (final it in (r['items'] as List).cast<Map>()) {
      all.add([it['sku'], (it['price'] as num).toDouble()]);
    }
  }
  all.sort(
      (a, b) => (b[1] as double).compareTo(a[1] as double));
  final out = <Map>[];
  final take = all.length < 30 ? all.length : 30;
  for (var i = 0; i < take; i++) {
    out.add({'sku': all[i][0], 'price': all[i][1]});
  }
  return out;
}

Object case3(Map root) {
  final data = (root['data'] as List).cast<Map>();
  final sorted = List<Map>.from(data);
  sorted.sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
  final out = <Map>[];
  final start = 200;
  final end = start + 50 < sorted.length ? start + 50 : sorted.length;
  for (var i = start; i < end; i++) {
    final r = sorted[i];
    out.add({
      'id': r['id'],
      'city': (r['user'] as Map)['addr']['city'],
      'score': r['score'],
    });
  }
  return out;
}

Object case4(Map root) {
  final data = (root['data'] as List).cast<Map>();
  final tags = <String>[];
  for (final r in data) {
    if (r['active'] == true) {
      tags.addAll((r['tags'] as List).cast<String>());
    }
  }
  tags.sort();
  final dedup = <String>[];
  String? prev;
  for (final t in tags) {
    if (t != prev) {
      dedup.add(t);
      prev = t;
    }
  }
  return dedup;
}

Object case5(Map root) {
  final data = (root['data'] as List).cast<Map>();
  double total = 0;
  for (final r in data) {
    for (final it in (r['items'] as List).cast<Map>()) {
      final p = (it['price'] as num).toDouble();
      if (p > 100.0) total += (it['qty'] as num).toDouble() * p;
    }
  }
  return total;
}

Object case6(Map root) {
  final data = (root['data'] as List).cast<Map>();
  final active = <Map>[];
  for (final r in data) {
    if (r['active'] == true) active.add(r);
  }
  active.sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
  final out = <String>[];
  final take = active.length < 50 ? active.length : 50;
  for (var i = 0; i < take; i++) {
    final r = active[i];
    final u = r['user'] as Map;
    out.add(
        '#${r['id']} ${u['name']} (${(u['addr'] as Map)['city']}) score=${r['score']}');
  }
  return out;
}

Object case7(Map root) {
  final data = (root['data'] as List).cast<Map>();
  final prices = <double>[];
  for (final r in data) {
    if ((r['score'] as num) > 700) {
      for (final it in (r['items'] as List).cast<Map>()) {
        prices.add((it['price'] as num).toDouble());
      }
    }
  }
  if (prices.isEmpty) return 0.0;
  double s = 0;
  for (final p in prices) {
    s += p;
  }
  return s / prices.length;
}

Object case8(Map root) {
  final data = (root['data'] as List).cast<Map>();
  final sorted = List<Map>.from(data);
  sorted.sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
  final out = <Map>[];
  final take = sorted.length < 20 ? sorted.length : 20;
  for (var i = 0; i < take; i++) {
    final r = sorted[i];
    double total = 0;
    for (final it in (r['items'] as List).cast<Map>()) {
      total += (it['qty'] as num).toDouble() * (it['price'] as num).toDouble();
    }
    out.add({
      'id': r['id'],
      'city': (r['user'] as Map)['addr']['city'],
      'total': total,
    });
  }
  return out;
}

Object case9(Map root) {
  final data = (root['data'] as List).cast<Map>();
  int count = 0;
  for (final r in data) {
    if (r['active'] != true) continue;
    if ((r['score'] as num) <= 500) continue;
    for (final it in (r['items'] as List).cast<Map>()) {
      if ((it['price'] as num) > 75 && (it['qty'] as num) > 2) count++;
    }
  }
  return count;
}

Object case10(Map root) {
  final data = (root['data'] as List).cast<Map>();
  int t = 0, f = 0;
  for (final r in data) {
    if (r['active'] == true) {
      t++;
    } else {
      f++;
    }
  }
  return {'true': t, 'false': f};
}

Object case11(Map root) {
  final data = (root['data'] as List).cast<Map>();
  final sorted = List<Map>.from(data);
  sorted.sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
  final zips = <String>[];
  final take = sorted.length < 300 ? sorted.length : 300;
  for (var i = 0; i < take; i++) {
    zips.add(((sorted[i]['user'] as Map)['addr'] as Map)['zip'] as String);
  }
  zips.sort();
  final dedup = <String>[];
  String? prev;
  for (final z in zips) {
    if (z != prev) {
      dedup.add(z);
      prev = z;
    }
  }
  return dedup;
}

Object case12(Map root) {
  final data = (root['data'] as List).cast<Map>();
  final prices = <int>[];
  for (final r in data) {
    for (final it in (r['items'] as List).cast<Map>()) {
      prices.add(((it['price'] as num).toDouble() * 100.0).toInt());
    }
  }
  prices.sort();
  int unique = 0;
  int? prev;
  for (final p in prices) {
    if (p != prev) {
      unique++;
      prev = p;
    }
  }
  return unique;
}

Object case13(Map root) {
  final data = (root['data'] as List).cast<Map>();
  int s = 0;
  for (final r in data) {
    if (r['active'] == true) s += (r['score'] as int);
  }
  return s;
}

Object case14(Map root) {
  final data = (root['data'] as List).cast<Map>();
  int n = 0;
  for (final r in data) {
    for (final it in (r['items'] as List).cast<Map>()) {
      if ((it['price'] as num) > 50) n++;
    }
  }
  return n;
}

Object case15(Map root) {
  final data = (root['data'] as List).cast<Map>();
  double s = 0;
  for (final r in data) {
    if (r['active'] != true) continue;
    for (final it in (r['items'] as List).cast<Map>()) {
      s += (it['qty'] as num).toDouble() * (it['price'] as num).toDouble();
    }
  }
  return s;
}

Object case16(Map root) {
  final data = (root['data'] as List).cast<Map>();
  final sorted = List<Map>.from(data);
  sorted.sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
  final out = <Map>[];
  final take = sorted.length < 10 ? sorted.length : 10;
  for (var i = 0; i < take; i++) {
    final r = sorted[i];
    out.add({
      'id': r['id'],
      'name': (r['user'] as Map)['name'],
      'score': r['score'],
    });
  }
  return out;
}

Object case17(Map root) {
  final data = (root['data'] as List).cast<Map>();
  final seen = <String>{};
  for (final r in data) {
    seen.add(((r['user'] as Map)['addr'] as Map)['city'] as String);
  }
  final out = seen.toList()..sort();
  return out;
}

Object case18(Map root) {
  final data = (root['data'] as List).cast<Map>();
  final out = <Map>[];
  for (final r in data) {
    final items = (r['items'] as List).cast<Map>();
    double total = 0;
    for (final it in items) {
      total += (it['qty'] as num).toDouble() * (it['price'] as num).toDouble();
    }
    out.add({
      'id': r['id'],
      'city': ((r['user'] as Map)['addr'] as Map)['city'],
      'item_count': items.length,
      'total': total,
    });
  }
  return out;
}

Object case19(Map root) {
  final data = (root['data'] as List).cast<Map>();
  final out = <String>[];
  for (final r in data) {
    final u = r['user'] as Map;
    out.add(
        '#${r['id']} ${u['name']} (${(u['addr'] as Map)['city']}) \$${r['score']}');
  }
  return out;
}

Object case20(Map root) {
  final data = (root['data'] as List).cast<Map>();
  final prices = <double>[];
  for (final r in data) {
    for (final it in (r['items'] as List).cast<Map>()) {
      prices.add((it['price'] as num).toDouble());
    }
  }
  return prices;
}

Object? case21(Map root) {
  final data = (root['data'] as List).cast<Map>();
  for (final r in data) {
    if ((r['score'] as num) > 900) return r['id'];
  }
  return null;
}

Object case22(Map root) {
  final data = (root['data'] as List).cast<Map>();
  final out = <Map>[];
  final start = 100;
  final end = start + 20 < data.length ? start + 20 : data.length;
  for (var i = start; i < end; i++) {
    out.add({'id': data[i]['id']});
  }
  return out;
}

Object case23(Map root) {
  final data = (root['data'] as List).cast<Map>();
  int s = 0;
  int n = 0;
  for (final r in data) {
    if (r['active'] == true) {
      s += (r['score'] as int);
      n++;
    }
  }
  if (n == 0) return 0.0;
  return s / n;
}

Object case24(Map root) {
  final data = (root['data'] as List).cast<Map>();
  final hits = <Map>[];
  for (final r in data) {
    final u = r['user'] as Map;
    final tier = u['tier'] as String;
    if (r['status'] == 'paid' &&
        (r['score'] as num) >= 500 &&
        (tier == 'gold' || tier == 'platinum')) {
      hits.add(r);
    }
  }
  hits.sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
  final out = <Map>[];
  final take = hits.length < 50 ? hits.length : 50;
  for (var i = 0; i < take; i++) {
    final r = hits[i];
    final u = r['user'] as Map;
    double lineTotal = 0;
    for (final it in (r['items'] as List).cast<Map>()) {
      lineTotal +=
          (it['qty'] as num).toDouble() * (it['price'] as num).toDouble();
    }
    final events = (r['events'] as List).cast<Map>();
    final last = events.isEmpty ? null : events.last;
    Map<String, Object?> lastEvent;
    if (last != null && last['kind'] == 'delivered') {
      lastEvent = {'state': 'ok', 'at': last['at']};
    } else if (last != null && last['kind'] == 'shipped') {
      lastEvent = {'state': 'moving', 'at': last['at']};
    } else if (last != null && last['kind'] == 'refund') {
      lastEvent = {'state': 'refund', 'reason': last['reason']};
    } else {
      lastEvent = {'state': 'unknown'};
    }
    out.add({
      'id': r['id'],
      'who': u['name'],
      'tier': u['tier'],
      'score_val': r['score'],
      'label':
          'order ${r['id']}: ${u['name']} (${u['tier']}) score ${r['score']}',
      'line_total': lineTotal,
      'last_event': lastEvent,
    });
  }
  return out;
}

/// Sentinel: also serialize so we measure the same total cold cost as the
/// Rust bench (which calls `serde_json::to_vec` inside `black_box`).
String serialize(Object? v) => jsonEncode(v);

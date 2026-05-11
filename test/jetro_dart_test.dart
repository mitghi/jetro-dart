import 'dart:convert';

import 'package:jetro_dart/jetro_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Jetro - construction', () {
    test('fromString accepts well-formed JSON', () {
      final j = Jetro.fromString('{"x": 42}');
      addTearDown(j.dispose);
      expect(j, isA<Jetro>());
    });

    test('fromBytes accepts UTF-8 bytes', () {
      final j = Jetro.fromBytes(utf8.encode('{"a": 1, "b": 2}'));
      addTearDown(j.dispose);
      expect(j, isA<Jetro>());
    });

    test('fromString and fromBytes are interchangeable', () {
      const text = '{"data": [1, 2, 3]}';
      final fromStr = Jetro.fromString(text);
      addTearDown(fromStr.dispose);
      final fromBytes = Jetro.fromBytes(utf8.encode(text));
      addTearDown(fromBytes.dispose);
      expect(fromStr.collect(r'$.data.sum()'),
          equals(fromBytes.collect(r'$.data.sum()')));
    });

    test('empty object document round-trips', () {
      final j = Jetro.fromString('{}');
      addTearDown(j.dispose);
      expect(j.collect(r'$'), equals(<String, Object?>{}));
    });

    test('empty array document round-trips', () {
      final j = Jetro.fromString('[]');
      addTearDown(j.dispose);
      expect(j.collect(r'$'), equals(<Object?>[]));
    });

    test('Unicode content survives round-trip', () {
      final j = Jetro.fromString('{"name": "Ada Löve­ace", "emoji": "🚀"}');
      addTearDown(j.dispose);
      expect(j.collect(r'$.emoji'), equals(['🚀']));
    });
  });

  group('Jetro - path navigation', () {
    test('simple field access returns wrapped list', () {
      final j = Jetro.fromString('{"x": 42}');
      addTearDown(j.dispose);
      expect(j.collect(r'$.x'), equals([42]));
    });

    test('nested field access', () {
      final j = Jetro.fromString('{"a": {"b": {"c": "deep"}}}');
      addTearDown(j.dispose);
      expect(j.collect(r'$.a.b.c'), equals(['deep']));
    });

    test('null-safe access on missing key returns null', () {
      final j = Jetro.fromString('{"user": {}}');
      addTearDown(j.dispose);
      expect(j.collect(r'$.user?.email'), isNull);
    });

    test('array index access returns scalar', () {
      final j = Jetro.fromString('{"items": [10, 20, 30]}');
      addTearDown(j.dispose);
      expect(j.collect(r'$.items[0]'), equals(10));
      expect(j.collect(r'$.items[2]'), equals(30));
    });

    test('array slice', () {
      final j = Jetro.fromString('{"items": [0, 1, 2, 3, 4, 5]}');
      addTearDown(j.dispose);
      expect(j.collect(r'$.items[1:4]'), equals([1, 2, 3]));
    });

    test('recursive descent picks up nested matches', () {
      final j = Jetro.fromString(
          '{"x":{"y":{"z":1}}, "items":[{"z":2},{"z":3}]}');
      addTearDown(j.dispose);
      final out = (j.collect(r'$..z') as List).cast<int>()..sort();
      expect(out, equals([1, 2, 3]));
    });

    test('chained nullable access on missing path', () {
      final j = Jetro.fromString('{}');
      addTearDown(j.dispose);
      expect(j.collect(r'$.missing?.deeper?.x'), isNull);
    });
  });

  group('Jetro - aggregation', () {
    final sampleDoc = '''
      {"items": [
        {"name": "a", "price": 10, "qty": 2},
        {"name": "b", "price": 50, "qty": 1},
        {"name": "c", "price": 80, "qty": 3}
      ]}
    ''';

    test('sum of all prices', () {
      final j = Jetro.fromString(sampleDoc);
      addTearDown(j.dispose);
      expect(j.collect(r'$.items.map(price).sum()'), equals(140));
    });

    test('filter + map + sum (revenue)', () {
      final j = Jetro.fromString(sampleDoc);
      addTearDown(j.dispose);
      expect(
          j.collect(r'$.items.filter(price > 40).map(qty * price).sum()'),
          equals(290));
    });

    test('avg over all rows', () {
      final j = Jetro.fromString(sampleDoc);
      addTearDown(j.dispose);
      expect(j.collect(r'$.items.map(price).avg()'), closeTo(46.666, 0.01));
    });

    test('count and length on filter chain', () {
      final j = Jetro.fromString(sampleDoc);
      addTearDown(j.dispose);
      expect(j.collect(r'$.items.len()'), equals(3));
      expect(j.collect(r'$.items.filter(qty > 1).len()'), equals(2));
      expect(j.collect(r'$.items.filter(price > 1000).len()'), equals(0));
    });

    test('first via sort_by + first()', () {
      final j = Jetro.fromString(sampleDoc);
      addTearDown(j.dispose);
      final result = j.collect(r'$.items.sort_by(-price).first()') as Map;
      expect(result['name'], equals('c'));
      expect(result['price'], equals(80));
      expect(result['qty'], equals(3));
    });

    test('first on empty pipeline returns null', () {
      final j = Jetro.fromString('{"v": []}');
      addTearDown(j.dispose);
      expect(j.collect(r'$.v.first()'), isNull);
    });

    test('unique values', () {
      final j = Jetro.fromString('{"tags": ["a", "b", "a", "c", "b"]}');
      addTearDown(j.dispose);
      final out = (j.collect(r'$.tags.unique()') as List).cast<String>()
        ..sort();
      expect(out, equals(['a', 'b', 'c']));
    });

    test('min / max produce numeric values', () {
      final j = Jetro.fromString('{"v": [3, 1, 4, 1, 5, 9, 2, 6]}');
      addTearDown(j.dispose);
      expect(j.collect(r'$.v.min()'), equals(1));
      expect(j.collect(r'$.v.max()'), equals(9));
    });

    test('avg of integer sequence', () {
      final j = Jetro.fromString('{"v": [2, 4, 6, 8]}');
      addTearDown(j.dispose);
      expect(j.collect(r'$.v.avg()'), equals(5));
    });
  });

  group('Jetro - reshape', () {
    test('map projects to selected fields only', () {
      final j = Jetro.fromString('''
        {"users": [
          {"id": 1, "name": "Ada", "secret": "hush"},
          {"id": 2, "name": "Lin", "secret": "hush"}
        ]}
      ''');
      addTearDown(j.dispose);
      final out = (j.collect(r'$.users.map({id, name})') as List)
          .cast<Map<String, Object?>>();
      expect(out, hasLength(2));
      expect(out[0].keys, unorderedEquals(['id', 'name']));
      expect(out[0]['secret'], isNull);
      expect(out[1]['name'], equals('Lin'));
    });

    test('renamed projection with nested path', () {
      final j =
          Jetro.fromString('{"u": [{"id": 1, "addr": {"city": "NYC"}}]}');
      addTearDown(j.dispose);
      final out = (j.collect(r'$.u.map({id, city: addr.city})') as List)
          .cast<Map<String, Object?>>();
      expect(out.single, equals({'id': 1, 'city': 'NYC'}));
    });

    test('computed total in projection', () {
      final j = Jetro.fromString('''
        {"data": [
          {"id": 1, "items": [{"q": 2, "p": 5}, {"q": 1, "p": 10}]},
          {"id": 2, "items": [{"q": 3, "p": 4}]}
        ]}
      ''');
      addTearDown(j.dispose);
      final out =
          (j.collect(r'$.data.map({id, total: items.map(q * p).sum()})')
                  as List)
              .cast<Map<String, Object?>>();
      expect(out, hasLength(2));
      expect(out[0]['id'], equals(1));
      expect(out[0]['total'], equals(20));
      expect(out[1]['id'], equals(2));
      expect(out[1]['total'], equals(12));
    });

    test('f-string interpolation produces strings', () {
      final j = Jetro.fromString(
          '{"u": [{"id": 1, "name": "Ada"}, {"id": 2, "name": "Lin"}]}');
      addTearDown(j.dispose);
      final out =
          (j.collect(r'$.u.map(f"#{id} {name}")') as List).cast<String>();
      expect(out, equals(['#1 Ada', '#2 Lin']));
    });

    test('top-level object composition', () {
      final j = Jetro.fromString('{"v": [1, 2, 3]}');
      addTearDown(j.dispose);
      final out = j.collect(r'''
        {
          "total": $.v.sum(),
          "count": $.v.len(),
          "first": $.v.first(),
          "doubled": $.v.map(@ * 2)
        }
      ''') as Map;
      expect(out['total'], equals(6));
      expect(out['count'], equals(3));
      expect(out['first'], equals(1));
      expect(out['doubled'], equals([2, 4, 6]));
    });
  });

  group('Jetro - long chains', () {
    test('seven-stage chain produces expected scalar', () {
      final j = Jetro.fromString('''
        {"data": [
          {"active": true,  "score": 250, "items": [{"qty": 2, "price": 60}]},
          {"active": true,  "score": 100, "items": [{"qty": 1, "price": 90}]},
          {"active": false, "score": 900, "items": [{"qty": 5, "price": 99}]},
          {"active": true,  "score": 500, "items": [{"qty": 3, "price": 40},
                                                    {"qty": 1, "price": 70}]}
        ]}
      ''');
      addTearDown(j.dispose);
      // active rows with score>200 = rows 0 and 3
      // items with price>50 from those rows: row 0 -> {60,2}, row 3 -> {70,1}
      // qty*price sum = 120 + 70 = 190
      expect(
          j.collect(
              r'$.data.filter(active).filter(score > 200).flat_map(items).filter(price > 50).map(qty * price).sum()'),
          equals(190));
    });

    test('filter + sort_by + take + map projection', () {
      final j = Jetro.fromString('''
        {"u": [
          {"id": 1, "score": 30, "tier": "gold"},
          {"id": 2, "score": 90, "tier": "silver"},
          {"id": 3, "score": 70, "tier": "gold"},
          {"id": 4, "score": 50, "tier": "gold"}
        ]}
      ''');
      addTearDown(j.dispose);
      final out = (j.collect(r'''
        $.u
          .filter(tier == "gold")
          .sort_by(-score)
          .take(2)
          .map({id, score})
      ''') as List)
          .cast<Map<String, Object?>>();
      expect(out, hasLength(2));
      expect(out[0]['id'], equals(3));
      expect(out[0]['score'], equals(70));
      expect(out[1]['id'], equals(4));
    });

    test('flat_map + filter + count', () {
      final j = Jetro.fromString('''
        {"orders": [
          {"items": [{"p": 10}, {"p": 60}, {"p": 80}]},
          {"items": [{"p": 5}, {"p": 70}]}
        ]}
      ''');
      addTearDown(j.dispose);
      expect(j.collect(r'$.orders.flat_map(items).filter(p > 50).len()'),
          equals(3));
    });

    test('skip + take pagination', () {
      final j = Jetro.fromString(
          '{"v": [10, 20, 30, 40, 50, 60, 70, 80, 90]}');
      addTearDown(j.dispose);
      expect(j.collect(r'$.v.skip(3).take(3)'), equals([40, 50, 60]));
      expect(j.collect(r'$.v.skip(7).take(3)'), equals([80, 90]));
      expect(j.collect(r'$.v.skip(100)'), equals(<Object?>[]));
    });
  });

  group('Jetro - let-in bindings', () {
    test('single let with filter and sum', () {
      final j = Jetro.fromString('{"v": [1, 2, 3, 4, 5]}');
      addTearDown(j.dispose);
      expect(j.collect(r'let cutoff = 2 in $.v.filter(@ > cutoff).sum()'),
          equals(12));
    });

    test('nested let-in bindings', () {
      final j = Jetro.fromString('{"v": [1, 2, 3, 4, 5, 6, 7]}');
      addTearDown(j.dispose);
      expect(
          j.collect(
              r'let a = 2 in let b = 6 in $.v.filter(@ > a and @ < b).len()'),
          equals(3));
    });

    test('let binding used inside projection', () {
      final j = Jetro.fromString(
          '{"u": [{"name": "ada"}, {"name": "lin"}]}');
      addTearDown(j.dispose);
      expect(
          j.collect(r'let suffix = "!" in $.u.map(name + suffix)'),
          equals(['ada!', 'lin!']));
    });
  });

  group('Jetro - pattern match', () {
    test('matches first arm on delivered', () {
      final j = Jetro.fromString(
          '{"events": [{"kind": "delivered", "at": "t1"}]}');
      addTearDown(j.dispose);
      final out = j.collect(r'''
        match $.events.last() with {
          {kind: "delivered", at: t}  -> {state: "ok",     at: t},
          {kind: "refund", reason: r} -> {state: "refund", reason: r},
          _                           -> {state: "unknown"}
        }
      ''') as Map;
      expect(out['state'], equals('ok'));
      expect(out['at'], equals('t1'));
      expect(out.containsKey('reason'), isFalse);
    });

    test('falls through to wildcard arm', () {
      final j = Jetro.fromString('{"events": [{"kind": "queued"}]}');
      addTearDown(j.dispose);
      final out = j.collect(r'''
        match $.events.last() with {
          {kind: "delivered", at: t}  -> {state: "ok",     at: t},
          {kind: "refund", reason: r} -> {state: "refund", reason: r},
          _                           -> {state: "unknown"}
        }
      ''') as Map;
      expect(out, equals({'state': 'unknown'}));
    });

    test('binds field from match arm', () {
      final j = Jetro.fromString(
          '{"events": [{"kind": "refund", "reason": "duplicate"}]}');
      addTearDown(j.dispose);
      final out = j.collect(r'''
        match $.events.last() with {
          {kind: "delivered", at: t}  -> {state: "ok",     at: t},
          {kind: "refund", reason: r} -> {state: "refund", reason: r},
          _                           -> {state: "unknown"}
        }
      ''') as Map;
      expect(out['state'], equals('refund'));
      expect(out['reason'], equals('duplicate'));
    });
  });

  group('Jetro - group/index/count_by', () {
    test('group_by produces map keyed by the group value', () {
      final j = Jetro.fromString('''
        {"d": [
          {"k": "a", "v": 1},
          {"k": "b", "v": 2},
          {"k": "a", "v": 3}
        ]}
      ''');
      addTearDown(j.dispose);
      final out = j.collect(r'$.d.group_by(k)') as Map;
      expect(out.keys, unorderedEquals(['a', 'b']));
      expect((out['a'] as List), hasLength(2));
      expect((out['b'] as List), hasLength(1));
    });

    test('index_by makes a map from id', () {
      final j = Jetro.fromString(
          '{"u": [{"id": 1, "n": "a"}, {"id": 2, "n": "b"}]}');
      addTearDown(j.dispose);
      final out = j.collect(r'$.u.index_by(id)') as Map;
      expect(out['1'] ?? out[1], isNotNull);
      // jetro uses numeric keys for numeric ids; accept either form.
      final byOne = out['1'] ?? out[1];
      expect((byOne as Map)['n'], equals('a'));
    });

    test('count_by(bool) yields boolean-keyed map', () {
      final j = Jetro.fromString(
          '{"d": [{"a": true}, {"a": true}, {"a": false}]}');
      addTearDown(j.dispose);
      final out = j.collect(r'$.d.count_by(a)') as Map;
      expect(out['true'] ?? out[true], equals(2));
      expect(out['false'] ?? out[false], equals(1));
    });

    test('count_by(string) yields string-keyed map', () {
      final j = Jetro.fromString(
          '{"d": [{"s": "x"}, {"s": "y"}, {"s": "x"}]}');
      addTearDown(j.dispose);
      final out = j.collect(r'$.d.count_by(s)') as Map;
      expect(out['x'], equals(2));
      expect(out['y'], equals(1));
    });
  });

  group('Jetro - mutation', () {
    test('.set replaces a field value', () {
      final j = Jetro.fromString('{"x": 1, "y": 2}');
      addTearDown(j.dispose);
      final out = j.collect(r'$.x.set(99)') as Map;
      expect(out['x'], equals(99));
      expect(out['y'], equals(2));
    });

    test('.delete removes an array element', () {
      final j = Jetro.fromString('{"items": [10, 20, 30]}');
      addTearDown(j.dispose);
      final out = j.collect(r'$.items[0].delete()') as Map;
      expect(out['items'], equals([20, 30]));
    });

    test('mutation does not affect a fresh handle', () {
      const text = '{"x": 1}';
      final a = Jetro.fromString(text);
      addTearDown(a.dispose);
      // mutating expression on `a`:
      expect((a.collect(r'$.x.set(7)') as Map)['x'], equals(7));
      // a fresh handle from the same source still sees the original:
      final b = Jetro.fromString(text);
      addTearDown(b.dispose);
      expect((b.collect(r'$') as Map)['x'], equals(1));
    });
  });

  group('Jetro - type / boolean ops', () {
    test('is number / is bool', () {
      final j = Jetro.fromString('{"n": 42, "b": true}');
      addTearDown(j.dispose);
      expect(j.collect(r'$.n is number'), isTrue);
      expect(j.collect(r'$.b is bool'), isTrue);
    });

    test('combined and/or in filter', () {
      final j = Jetro.fromString('''
        {"u": [
          {"a": true,  "n": 1},
          {"a": false, "n": 2},
          {"a": true,  "n": 3}
        ]}
      ''');
      addTearDown(j.dispose);
      expect(
          j.collect(r'$.u.filter(a and n > 2).map(n).sum()'), equals(3));
      expect(j.collect(r'$.u.filter(a or n > 1).len()'), equals(3));
    });

    test('string concat with + operator', () {
      final j = Jetro.fromString('{"a": "Hello", "b": "World"}');
      addTearDown(j.dispose);
      expect(j.collect(r'$.a + " " + $.b'), equals('Hello World'));
    });
  });

  group('Jetro - edge cases', () {
    test('take(k) where k > len returns all elements', () {
      final j = Jetro.fromString('{"v": [1, 2]}');
      addTearDown(j.dispose);
      expect(j.collect(r'$.v.take(10)'), equals([1, 2]));
    });

    test('skip past end returns empty array', () {
      final j = Jetro.fromString('{"v": [1, 2]}');
      addTearDown(j.dispose);
      expect(j.collect(r'$.v.skip(10)'), equals(<Object?>[]));
    });

    test('filter matching nothing has length 0', () {
      final j = Jetro.fromString('{"v": [1, 2, 3]}');
      addTearDown(j.dispose);
      expect(j.collect(r'$.v.filter(@ > 100).len()'), equals(0));
    });

    test('map over an empty array returns empty array', () {
      final j = Jetro.fromString('{"v": []}');
      addTearDown(j.dispose);
      expect(j.collect(r'$.v.map(@ * 2)'), equals(<Object?>[]));
    });

    test('large input (>64 KB) processes without truncation', () {
      final list = List<int>.generate(20000, (i) => i);
      final doc = jsonEncode({'v': list});
      final j = Jetro.fromString(doc);
      addTearDown(j.dispose);
      expect(j.collect(r'$.v.len()'), equals(20000));
      expect(j.collect(r'$.v.sum()'), equals(199990000));
    });
  });

  group('Jetro - low-level API', () {
    test('collectJsonBytes returns raw UTF-8 JSON', () {
      final j = Jetro.fromString('{"v": [1, 2, 3]}');
      addTearDown(j.dispose);
      final bytes = j.collectJsonBytes(r'$.v');
      expect(bytes, isNotEmpty);
      expect(utf8.decode(bytes), equals('[1,2,3]'));
    });

    test('collectJsonBytes round-trips through json.decode', () {
      final j = Jetro.fromString('{"items": [10, 20]}');
      addTearDown(j.dispose);
      final viaBytes =
          json.decode(utf8.decode(j.collectJsonBytes(r'$.items.sum()')));
      final viaCollect = j.collect(r'$.items.sum()');
      expect(viaBytes, equals(viaCollect));
    });
  });

  group('Jetro - errors', () {
    test('garbage expression throws JetroException', () {
      final j = Jetro.fromString('{}');
      addTearDown(j.dispose);
      JetroException? caught;
      try {
        j.collect('not a real query');
      } on JetroException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught!.message, isNotEmpty);
      expect(caught.toString(), startsWith('JetroException:'));
    });

    test('invalid JSON surfaces on first collect', () {
      final j = Jetro.fromBytes(utf8.encode('not json'));
      addTearDown(j.dispose);
      expect(() => j.collect(r'$'), throwsA(isA<JetroException>()));
    });

    test('referencing missing field is null, not error', () {
      final j = Jetro.fromString('{}');
      addTearDown(j.dispose);
      expect(j.collect(r'$.missing?.deeper'), isNull);
    });
  });

  group('Jetro - lifecycle', () {
    test('dispose is idempotent', () {
      final j = Jetro.fromString('{}');
      expect(j.dispose, returnsNormally);
      expect(j.dispose, returnsNormally);
    });

    test('use after dispose throws StateError', () {
      final j = Jetro.fromString('{}');
      j.dispose();
      expect(() => j.collectJsonBytes(r'$'), throwsA(isA<StateError>()));
      expect(() => j.collect(r'$'), throwsA(isA<StateError>()));
    });

    test('many handles in parallel produce independent results', () {
      final handles = List.generate(
          16, (i) => Jetro.fromString('{"x": $i}'),
          growable: false);
      addTearDown(() {
        for (final h in handles) {
          h.dispose();
        }
      });
      for (var i = 0; i < handles.length; i++) {
        expect(handles[i].collect(r'$.x'), equals([i]));
      }
    });
  });

  group('Jetro - list comprehensions', () {
    test('basic expression over an array', () {
      final j = Jetro.fromString('{"v": [1, 2, 3, 4]}');
      addTearDown(j.dispose);
      expect(j.collect(r'[x * 2 for x in $.v]'), equals([2, 4, 6, 8]));
    });

    test('with `if` guard', () {
      final j = Jetro.fromString('{"v": [1, 2, 3, 4, 5]}');
      addTearDown(j.dispose);
      expect(j.collect(r'[x * x for x in $.v if x > 2]'),
          equals([9, 16, 25]));
    });

    test('projecting a field with a guard', () {
      final j = Jetro.fromString('''
        {"books": [
          {"title": "cheap", "price": 5},
          {"title": "mid",   "price": 15},
          {"title": "rich",  "price": 100}
        ]}
      ''');
      addTearDown(j.dispose);
      final out = (j.collect(r'[b.title for b in $.books if b.price > 10]')
              as List)
          .cast<String>();
      expect(out, equals(['mid', 'rich']));
    });

    test('comprehension result feeds into a pipeline', () {
      final j = Jetro.fromString('{"v": [1, 2, 3, 4, 5]}');
      addTearDown(j.dispose);
      expect(j.collect(r'[x * x for x in $.v if x > 2].sum()'),
          equals(50)); // 9 + 16 + 25
    });
  });

  group('Jetro - dict comprehensions', () {
    test('builds map from a list of objects', () {
      final j = Jetro.fromString('''
        {"u": [
          {"id": 1, "n": "ada"},
          {"id": 2, "n": "lin"}
        ]}
      ''');
      addTearDown(j.dispose);
      final out = j.collect(r'{u.id: u.n for u in $.u}') as Map;
      expect(out.keys.map((k) => k.toString()).toList()..sort(),
          equals(['1', '2']));
      // accept either int or string key form depending on jetro version
      expect(out['1'] ?? out[1], equals('ada'));
      expect(out['2'] ?? out[2], equals('lin'));
    });

    test('dict comprehension with a guard drops false entries', () {
      final j = Jetro.fromString('''
        {"u": [
          {"id": 1, "active": true},
          {"id": 2, "active": false},
          {"id": 3, "active": true}
        ]}
      ''');
      addTearDown(j.dispose);
      final out = j.collect(r'{u.id: u.active for u in $.u if u.active}')
          as Map;
      expect(out, hasLength(2));
      expect((out['1'] ?? out[1]), isTrue);
      expect((out['3'] ?? out[3]), isTrue);
    });
  });

  group('Jetro - set comprehensions', () {
    test('produces distinct values from a list of objects', () {
      final j = Jetro.fromString('''
        {"books": [
          {"genre": "sci-fi"},
          {"genre": "sci-fi"},
          {"genre": "hist"},
          {"genre": "hist"},
          {"genre": "sci-fi"}
        ]}
      ''');
      addTearDown(j.dispose);
      final out = (j.collect(r'{b.genre for b in $.books}') as List)
          .cast<String>()
        ..sort();
      expect(out, equals(['hist', 'sci-fi']));
    });
  });

  group('Jetro - map-into-shape', () {
    test('postfix `=> {...}` projects with a guard', () {
      final j = Jetro.fromString('''
        {"books": [
          {"title": "cheap", "price": 5},
          {"title": "mid",   "price": 15},
          {"title": "rich",  "price": 100}
        ]}
      ''');
      addTearDown(j.dispose);
      final out =
          (j.collect(r'$.books[* if price > 10] => {title, price}') as List)
              .cast<Map<String, Object?>>();
      expect(out, hasLength(2));
      expect(out[0]['title'], equals('mid'));
      expect(out[1]['price'], equals(100));
    });
  });

  group('Jetro - object construction', () {
    test('shorthand spread + extra keys', () {
      final j = Jetro.fromString('{"base": {"a": 1, "b": 2}}');
      addTearDown(j.dispose);
      final out = j.collect(r'{...$.base, c: 3}') as Map;
      expect(out, equals({'a': 1, 'b': 2, 'c': 3}));
    });

    test('optional field drops null values', () {
      final j = Jetro.fromString('{"name": "a", "email": null}');
      addTearDown(j.dispose);
      final out =
          j.collect(r'{name: $.name, email?: $.email}') as Map;
      expect(out, equals({'name': 'a'}));
      expect(out.containsKey('email'), isFalse);
    });

    test('when-guarded field is included only when guard is true', () {
      final j = Jetro.fromString('{"score": 90}');
      addTearDown(j.dispose);
      expect(
          j.collect(r'{grade: "pass" when $.score > 50}'),
          equals({'grade': 'pass'}));
      // flip the predicate:
      expect(
          j.collect(r'{grade: "pass" when $.score > 500}'), equals({}));
    });
  });

  group('Jetro - array construction', () {
    test('two-spread concat', () {
      final j = Jetro.fromString('{"a": [1, 2], "b": [3, 4]}');
      addTearDown(j.dispose);
      expect(j.collect(r'[...$.a, ...$.b, 5]'), equals([1, 2, 3, 4, 5]));
    });

    test('mixed literal + spread', () {
      final j = Jetro.fromString('{"mid": [2, 3]}');
      addTearDown(j.dispose);
      expect(j.collect(r'[1, ...$.mid, 4]'), equals([1, 2, 3, 4]));
    });
  });

  group('Jetro - patch', () {
    test('overwrites a top-level field', () {
      final j = Jetro.fromString('{"name": "old", "age": 30}');
      addTearDown(j.dispose);
      final out = j.collect(r'patch $ { name: "Ada" }') as Map;
      expect(out['name'], equals('Ada'));
      expect(out['age'], equals(30));
    });

    test('writes through a deep dotted path', () {
      final j = Jetro.fromString(
          '{"user": {"name": "old", "active": false}}');
      addTearDown(j.dispose);
      final out = j.collect(
              r'patch $ { user.name: "Ada", user.active: true }')
          as Map;
      expect(out['user'], equals({'name': 'Ada', 'active': true}));
    });

    test('DELETE drops a key', () {
      final j = Jetro.fromString('{"a": 1, "b": 2, "tmp": 99}');
      addTearDown(j.dispose);
      final out = j.collect(r'patch $ { tmp: DELETE }') as Map;
      expect(out.keys, unorderedEquals(['a', 'b']));
      expect(out.containsKey('tmp'), isFalse);
    });

    test('bulk patch over an array', () {
      final j = Jetro.fromString('''
        {"users": [
          {"id": 1, "n": "ada"},
          {"id": 2, "n": "lin"}
        ]}
      ''');
      addTearDown(j.dispose);
      final out =
          j.collect(r'patch $ { users[*].seen: true }') as Map;
      final users = (out['users'] as List).cast<Map<String, Object?>>();
      expect(users, hasLength(2));
      expect(users.every((u) => u['seen'] == true), isTrue);
      expect(users[0]['n'], equals('ada'));
      expect(users[1]['n'], equals('lin'));
    });

    test('patch does not mutate the parsed document', () {
      const text = '{"user": {"name": "old"}}';
      final j = Jetro.fromString(text);
      addTearDown(j.dispose);
      j.collect(r'patch $ { user.name: "Ada" }');
      // a second query against the same handle still sees the original:
      expect(j.collect(r'$.user.name'), equals(['old']));
    });
  });

  group('Jetro - pattern match (advanced)', () {
    test('matches by structural shape, not just kind tag', () {
      final j = Jetro.fromString('{"node": {"x": 1, "y": 2}}');
      addTearDown(j.dispose);
      final out = j.collect(r'''
        match $.node with {
          {x: a, y: b} -> {sum: a + b, kind: "point"},
          _            -> {kind: "other"}
        }
      ''') as Map;
      expect(out['kind'], equals('point'));
      expect(out['sum'], equals(3));
    });

    test('rest pattern collects unspecified keys', () {
      final j = Jetro.fromString(
          '{"u": {"role": "user", "name": "ada", "age": 30}}');
      addTearDown(j.dispose);
      final out = j.collect(r'''
        match $.u with {
          {role: r, ...*rest} -> {role: r, rest},
          _                   -> {kind: "unknown"}
        }
      ''') as Map;
      expect(out['role'], equals('user'));
      final rest = out['rest'] as Map;
      expect(rest['name'], equals('ada'));
      expect(rest['age'], equals(30));
      expect(rest.containsKey('role'), isFalse);
    });

    test('map over array with per-row match', () {
      final j = Jetro.fromString('''
        {"events": [
          {"kind": "click", "id": 1},
          {"kind": "view",  "id": 2},
          {"kind": "click", "id": 3}
        ]}
      ''');
      addTearDown(j.dispose);
      final out = (j.collect(r'''
        $.events.map(match @ with {
          {kind: "click", id: i} -> {clicked: i},
          _                      -> {ignored: true}
        })
      ''') as List).cast<Map<String, Object?>>();
      expect(out, hasLength(3));
      expect(out[0]['clicked'], equals(1));
      expect(out[1]['ignored'], isTrue);
      expect(out[2]['clicked'], equals(3));
    });
  });
}

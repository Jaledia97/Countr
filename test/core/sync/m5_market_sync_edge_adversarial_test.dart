import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/sync/market_price_sync_service.dart';

class _ThrowingToDateObject {
  DateTime toDate() {
    throw StateError('Simulated corruption in toDate()');
  }
}

class _NonDateTimeToDateObject {
  String toDate() => 'not-a-datetime';
}

class _NullToDateObject {
  dynamic toDate() => null;
}

class _FieldToDateObject {
  // toDate is a field, not a function
  final int toDate = 42;
}

class _ThrowingMillisObject {
  int get millisecondsSinceEpoch {
    throw Exception('Simulated corruption in millisecondsSinceEpoch');
  }
}

class _NonIntMillisObject {
  String get millisecondsSinceEpoch => 'not-an-int';
}

class _BothToDateAndMillisObject {
  final DateTime _dt;
  final int _ms;
  _BothToDateAndMillisObject(this._dt, this._ms);

  DateTime toDate() => _dt;
  int get millisecondsSinceEpoch => _ms;
}

class _ThrowingToDateWithValidMillisObject {
  final int _ms;
  _ThrowingToDateWithValidMillisObject(this._ms);

  DateTime toDate() => throw UnsupportedError('toDate unsupported');
  int get millisecondsSinceEpoch => _ms;
}

void main() {
  group('Milestone 5 Remediation Re-verification: MarketSyncMetadata Timestamp Edge Cases', () {
    test('rawTs with throwing toDate() falls back safely to 0 without unhandled exception', () {
      final meta = MarketSyncMetadata.fromMap({
        'timestamp': _ThrowingToDateObject(),
        'version': 'v1',
      });
      expect(meta.timestamp, equals(0));
    });

    test('rawTs with toDate() returning non-DateTime string defaults safely to 0', () {
      final meta = MarketSyncMetadata.fromMap({
        'timestamp': _NonDateTimeToDateObject(),
        'version': 'v1',
      });
      expect(meta.timestamp, equals(0));
    });

    test('rawTs with toDate() returning null defaults safely to 0', () {
      final meta = MarketSyncMetadata.fromMap({
        'timestamp': _NullToDateObject(),
        'version': 'v1',
      });
      expect(meta.timestamp, equals(0));
    });

    test('rawTs with toDate as non-callable field defaults safely to 0', () {
      final meta = MarketSyncMetadata.fromMap({
        'timestamp': _FieldToDateObject(),
        'version': 'v1',
      });
      expect(meta.timestamp, equals(0));
    });

    test('rawTs with throwing millisecondsSinceEpoch defaults safely to 0', () {
      final meta = MarketSyncMetadata.fromMap({
        'timestamp': _ThrowingMillisObject(),
        'version': 'v1',
      });
      expect(meta.timestamp, equals(0));
    });

    test('rawTs with non-int millisecondsSinceEpoch defaults safely to 0', () {
      final meta = MarketSyncMetadata.fromMap({
        'timestamp': _NonIntMillisObject(),
        'version': 'v1',
      });
      expect(meta.timestamp, equals(0));
    });

    test('rawTs with both toDate() and millisecondsSinceEpoch prioritizes toDate()', () {
      final dt = DateTime.utc(2026, 10, 31, 3, 0);
      final obj = _BothToDateAndMillisObject(dt, 999999);
      final meta = MarketSyncMetadata.fromMap({
        'timestamp': obj,
        'version': 'v1',
      });
      expect(meta.timestamp, equals(dt.millisecondsSinceEpoch));
    });

    test('rawTs with throwing toDate() falls back to valid millisecondsSinceEpoch', () {
      final obj = _ThrowingToDateWithValidMillisObject(1793415600000);
      final meta = MarketSyncMetadata.fromMap({
        'timestamp': obj,
        'version': 'v1',
      });
      expect(meta.timestamp, equals(1793415600000));
    });

    test('rawTs with arbitrary primitive and collection types (bool, List, Map, Set) defaults safely to 0', () {
      final inputs = [
        true,
        false,
        <dynamic>[],
        <dynamic>[1, 2, 3],
        <String, dynamic>{'a': 1},
        <int>{1, 2, 3},
        3.14159,
        double.infinity,
        double.nan,
      ];

      for (final input in inputs) {
        final meta = MarketSyncMetadata.fromMap({
          'timestamp': input,
          'version': 'v1',
        });
        expect(meta.timestamp, equals(0), reason: 'Failed for type ${input.runtimeType}');
      }
    });

    test('rawTs with various ISO date formats and edge dates parses correctly', () {
      final dates = [
        '2026-10-31T03:00:00.000Z',
        '2026-10-31T03:00:00Z',
        '2026-10-31',
        '1970-01-01T00:00:00.000Z',
      ];

      for (final dateStr in dates) {
        final expected = DateTime.parse(dateStr).millisecondsSinceEpoch;
        final meta = MarketSyncMetadata.fromMap({
          'timestamp': dateStr,
          'version': 'v1',
        });
        expect(meta.timestamp, equals(expected), reason: 'Failed for $dateStr');
      }
    });

    test('rawTs with int timestamps (positive, zero, negative) parses directly', () {
      for (final ts in [0, 1793415600000, -1000, 9223372036854775807]) {
        final meta = MarketSyncMetadata.fromMap({
          'timestamp': ts,
          'version': 'v1',
        });
        expect(meta.timestamp, equals(ts));
      }
    });
  });
}

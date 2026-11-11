import 'package:flutter_test/flutter_test.dart';
import 'package:notifarma_app/core/utils/date_formatter.dart';

void main() {
  test('parses appointment timestamps using Colombia wall time', () {
    final withOffset = DateFormatter.tryParseColombiaDateTime(
      '2026-11-12T19:37:00-05:00',
    );
    final utcTimestamp = DateFormatter.tryParseColombiaDateTime(
      '2026-11-13T00:37:00Z',
    );
    final withoutOffset = DateFormatter.tryParseColombiaDateTime(
      '2026-11-12T19:37:00',
    );

    for (final value in [withOffset, utcTimestamp, withoutOffset]) {
      expect(value, isNotNull);
      expect(value!.year, 2026);
      expect(value.month, 11);
      expect(value.day, 12);
      expect(value.hour, 19);
      expect(value.minute, 37);
    }
  });

  test(
    'serializes a Colombia appointment as its corresponding UTC instant',
    () {
      final localWallTime = DateTime.utc(2026, 11, 12, 19, 37);
      final serialized = DateFormatter.toColombiaIsoString(localWallTime);
      final parsed = DateFormatter.tryParseColombiaDateTime(serialized);

      expect(serialized, '2026-11-13T00:37:00.000Z');
      expect(parsed, localWallTime);
    },
  );
}

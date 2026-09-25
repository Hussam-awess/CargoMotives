import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> baseJson() => {
    'id': 1,
    'status': 'in_transit',
    'pickup_address': 'Kariakoo, Dar es Salaam',
    'dropoff_address': 'Mbezi Beach, Dar es Salaam',
    'container_type': '20ft',
    'container_size': '20ft',
    'cargo_description': null,
    'preferred_pickup_window_start': '2026-09-30T09:00:00Z',
    'customer_notes': null,
    'currency': 'TZS',
  };

  group('Job.fromJson — cargo-authority checkpoint permits', () {
    test('parses both permits when present', () {
      final job = Job.fromJson({
        ...baseJson(),
        'pickup_permit_url': 'https://example.com/pickup.pdf',
        'pickup_permit_uploaded_at': '2026-09-28T10:00:00Z',
        'dropoff_permit_url': 'https://example.com/dropoff.pdf',
        'dropoff_permit_uploaded_at': '2026-09-29T11:00:00Z',
      });

      expect(job.pickupPermitUrl, 'https://example.com/pickup.pdf');
      expect(job.pickupPermitUploadedAt, DateTime.parse('2026-09-28T10:00:00Z'));
      expect(job.dropoffPermitUrl, 'https://example.com/dropoff.pdf');
      expect(
        job.dropoffPermitUploadedAt,
        DateTime.parse('2026-09-29T11:00:00Z'),
      );
    });

    test('defaults to null when neither permit has been uploaded', () {
      final job = Job.fromJson(baseJson());

      expect(job.pickupPermitUrl, isNull);
      expect(job.pickupPermitUploadedAt, isNull);
      expect(job.dropoffPermitUrl, isNull);
      expect(job.dropoffPermitUploadedAt, isNull);
    });
  });
}

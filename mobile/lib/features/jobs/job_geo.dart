import 'dart:math';

/// Great-circle distance in km between two coordinates — used to show a
/// job's pickup→dropoff distance without needing a routing API (this is
/// straight-line, not road distance, which is good enough for the
/// "452 km" style hint on a job card).
double kmBetween(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final dLat = _radians(lat2 - lat1);
  final dLng = _radians(lng2 - lng1);
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_radians(lat1)) * cos(_radians(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

double _radians(double degrees) => degrees * pi / 180;

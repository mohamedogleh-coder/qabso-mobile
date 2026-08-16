import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'app_utility_service.dart';

final currentPositionProvider = FutureProvider<Position?>((ref) async {
  try {
    return await AppUtilityService.getCurrentLocation();
  } catch (_) {
    return null;
  }
});

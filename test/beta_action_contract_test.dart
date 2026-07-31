import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('broken beta actions have no reachable placeholder backend requests', () {
    final favorites = source('lib/favourites.dart');
    final dailyWear = source('lib/daily_wear.dart');
    final appwrite = source('lib/services/appwrite_service.dart');
    final profile = source('lib/profile.dart');

    expect(favorites, isNot(contains('YOUR_BACKEND_URL')));
    expect(favorites, isNot(contains('/api/wardrobe/favorite')));
    expect(favorites, isNot(contains('onTap: () {}')));
    expect(dailyWear, isNot(contains('/api/style/log-wear')));
    expect(dailyWear, isNot(contains('_logWearForCurrentLook')));
    expect(appwrite, isNot(contains('Env.appwriteEndpoint}/api/')));
    expect(profile, contains("meta: 'Unavailable in beta'"));
    expect(profile, contains('onTap: null'));
  });

  test('secondary wear logging rolls back before reporting failure', () {
    final wardrobe = source('lib/wardrobe.dart');

    expect(wardrobe, contains('item.worn = previousWorn'));
    expect(wardrobe, contains('Wear was not logged. Please try again.'));
  });
}

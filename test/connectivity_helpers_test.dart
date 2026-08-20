import 'package:be_ther/core/network/connectivity_controller.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('healthUriFromApiBase strips /api and hits /health', () {
    expect(
      healthUriFromApiBase('https://be-ther.com/api/').toString(),
      'https://be-ther.com/health',
    );
    expect(
      healthUriFromApiBase('http://10.0.2.2:3000/').toString(),
      'http://10.0.2.2:3000/health',
    );
  });

  test('hasNetworkLink treats none as offline', () {
    expect(hasNetworkLink([ConnectivityResult.none]), isFalse);
    expect(hasNetworkLink([ConnectivityResult.wifi]), isTrue);
    expect(hasNetworkLink([]), isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/config/env.dart';

void main() {
  test('runtime provenance does not use the stale placeholder version', () {
    expect(Env.appBuildVersion, isNot('1.0.0+1'));
    expect(Env.canonicalRendererVersion, 'editorial_board_canonical_v1');
  });

  test('runtime provenance exposes supplied compile-time values', () {
    const expectedSha = String.fromEnvironment('AHVI_EXPECTED_GIT_SHA');
    const expectedName = String.fromEnvironment('AHVI_EXPECTED_BUILD_NAME');
    const expectedNumber = String.fromEnvironment('AHVI_EXPECTED_BUILD_NUMBER');

    if (expectedSha.isEmpty && expectedName.isEmpty && expectedNumber.isEmpty) {
      expect(Env.gitSha, 'unknown');
      expect(Env.buildName, 'dev');
      expect(Env.buildNumber, '0');
      return;
    }

    expect(Env.gitSha, expectedSha);
    expect(Env.buildName, expectedName);
    expect(Env.buildNumber, expectedNumber);
    expect(Env.appBuildVersion, '$expectedName+$expectedNumber');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/theme/app_colors.dart';

void main() {
  group('AppColors (design/02 §2.2)', () {
    test('seed is the ratified neutral-led deep ink value', () {
      expect(AppColors.seed, const Color(0xFF243447));
    });

    test('the retired saturated green seed no longer exists', () {
      expect(AppColors.seed, isNot(const Color(0xFF2E7D32)));
    });
  });
}

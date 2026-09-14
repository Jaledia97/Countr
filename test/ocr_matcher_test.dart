import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:countr/features/scanner/domain/ocr_heuristic_matcher.dart';
import 'package:countr/features/scanner/domain/adaptive_auto_adjust_controller.dart';
import 'package:countr/features/scanner/utils/camera_image_converter.dart';

void main() {
  group('OcrHeuristicMatcher', () {
    test('extracts fraction collector numbers (MTG style)', () {
      final lines = [
        'Black Lotus',
        'Artifact',
        'Tap, Sacrifice Black Lotus: Add three mana of any one color.',
        'Illus. Christopher Rush',
        '232/250',
      ];

      final result = OcrHeuristicMatcher.parseLines(lines);

      expect(result.primaryName, equals('Black Lotus'));
      expect(result.collectorNumber, equals('232'));
      expect(result.totalInSet, equals('250'));
    });

    test('extracts set-dash collector numbers (Pokémon / One Piece style)', () {
      final lines = [
        'Charizard ex',
        'HP 330',
        'Slash 60',
        'Infernal Reign',
        'SV03-125',
      ];

      final result = OcrHeuristicMatcher.parseLines(lines);

      expect(result.candidateNames, contains('Charizard ex'));
      expect(result.setCode, equals('SV03'));
      expect(result.collectorNumber, equals('125'));
    });

    test('extracts hash collector numbers (#007, No. 25)', () {
      final lines = [
        'Pikachu',
        'No. 25 Mouse Pokémon',
        'Thunderbolt 100',
        '#025',
      ];

      final result = OcrHeuristicMatcher.parseLines(lines);

      expect(result.primaryName, equals('Pikachu'));
      expect(result.collectorNumber, equals('25'));
    });

    test('cleans OCR artifacts and filters out card type noise', () {
      final lines = [
        '© 2023 Wizards of the Coast',
        'Creature — Dragon',
        '| Shivan Dragon |',
        'Flying, +1/+0 firebreathing',
        '5/5',
      ];

      final result = OcrHeuristicMatcher.parseLines(lines);

      expect(result.candidateNames, contains('Shivan Dragon'));
      expect(result.candidateNames, isNot(contains('Creature — Dragon')));
      expect(result.candidateNames, isNot(contains('© 2023 Wizards of the Coast')));
    });
  });

  group('AdaptiveAutoAdjustController', () {
    test('initial state has step 0 and 0.0 offset', () {
      final controller = AdaptiveAutoAdjustController();

      expect(controller.isEnabled, isTrue);
      expect(controller.currentStep, equals(0));
      expect(controller.currentOffset, equals(0.0));

      controller.dispose();
    });

    test('steps through negative exposures when frames fail to match over threshold', () async {
      final controller = AdaptiveAutoAdjustController(
        noMatchThreshold: const Duration(milliseconds: 20),
      );

      // Initial frame with no match
      await controller.onFrameResult(matched: false);
      expect(controller.currentStep, equals(0));

      // Wait past threshold and send next non-matching frame
      await Future.delayed(const Duration(milliseconds: 30));
      await controller.onFrameResult(matched: false);
      expect(controller.currentStep, equals(1));
      expect(controller.currentOffset, equals(-0.5));

      // Wait past threshold and step to -1.0
      await Future.delayed(const Duration(milliseconds: 30));
      await controller.onFrameResult(matched: false);
      expect(controller.currentStep, equals(2));
      expect(controller.currentOffset, equals(-1.0));

      // Wait past threshold and step to -1.5
      await Future.delayed(const Duration(milliseconds: 30));
      await controller.onFrameResult(matched: false);
      expect(controller.currentStep, equals(3));
      expect(controller.currentOffset, equals(-1.5));

      // Subsequent failures stay at max step (-1.5)
      await Future.delayed(const Duration(milliseconds: 30));
      await controller.onFrameResult(matched: false);
      expect(controller.currentStep, equals(3));

      // Successful match resets immediately to 0.0
      await controller.onFrameResult(matched: true);
      expect(controller.currentStep, equals(0));
      expect(controller.currentOffset, equals(0.0));

      controller.dispose();
    });

    test('toggle disables and resets auto adjust', () async {
      final controller = AdaptiveAutoAdjustController(
        noMatchThreshold: const Duration(milliseconds: 20),
      );

      await Future.delayed(const Duration(milliseconds: 30));
      await controller.onFrameResult(matched: false);
      expect(controller.currentStep, equals(1));

      controller.toggle();
      expect(controller.isEnabled, isFalse);
      expect(controller.currentStep, equals(0));
      expect(controller.currentOffset, equals(0.0));

      controller.dispose();
    });
  });

  group('CameraImageConverter', () {
    test('calculateRotation handles back and front camera orientations', () {
      const backCamera = CameraDescription(
        name: 'back',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      );

      expect(
        CameraImageConverter.calculateRotation(backCamera, DeviceOrientation.portraitUp),
        equals(InputImageRotation.rotation90deg),
      );

      expect(
        CameraImageConverter.calculateRotation(backCamera, DeviceOrientation.landscapeLeft),
        equals(InputImageRotation.rotation0deg),
      );

      const frontCamera = CameraDescription(
        name: 'front',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270,
      );

      expect(
        CameraImageConverter.calculateRotation(frontCamera, DeviceOrientation.portraitUp),
        equals(InputImageRotation.rotation270deg),
      );
    });
  });
}

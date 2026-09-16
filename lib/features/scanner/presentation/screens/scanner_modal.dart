import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/state/app_state.dart';
import '../../../vault/presentation/providers/vault_providers.dart';
import '../../domain/adaptive_auto_adjust_controller.dart';
import '../../domain/card_perimeter_calculator.dart';
import '../../domain/ocr_heuristic_matcher.dart';
import '../../utils/camera_image_converter.dart';
import '../widgets/dynamic_scanner_overlay.dart';
import '../widgets/scanner_success_toast.dart';
import 'inbox_screen.dart';

/// Full-screen Edge Scanner modal featuring live camera streaming,
/// on-device Google ML Kit text recognition, Adaptive Auto-Adjust glare reduction,
/// and instant SQLite catalog matching into the user's Inbox holding area.
class ScannerModal extends ConsumerStatefulWidget {
  const ScannerModal({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ScannerModal(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  ConsumerState<ScannerModal> createState() => _ScannerModalState();
}

class _ScannerModalState extends ConsumerState<ScannerModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanLineController;
  CameraController? _cameraController;
  AdaptiveAutoAdjustController? _autoAdjustController;
  late TextRecognizer _textRecognizer;
  late ObjectDetector _objectDetector;
  bool _useObjectDetectionFallback = false;

  int _selectedModeIndex = 0;
  bool _flashOn = false;
  bool _isFoilMode = false;
  bool _isExposureLocked = false;
  bool _isGreenFlash = false;
  bool _isProcessing = false;
  int _frameCount = 0;
  Rect? _detectedCardBounds;
  DateTime? _lastCardDetectedTime;
  bool _isCameraAvailable = false;
  bool _isScanningPaused = false;
  int _sessionScanCount = 0;
  DateTime? _lastIdleLogTime;
  String? _lastMatchedCardId;
  DateTime? _lastMatchTimestamp;
  VaultItem? _scannedToastCard;

  final List<String> _scanModes = [
    'RAW CARD',
    'SLAB / GRADED',
    'COMIC BOOK',
    'BARCODE',
  ];

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _objectDetector = ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.stream,
        classifyObjects: false,
        multipleObjects: false,
      ),
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Simulator, Desktop, or headless tests may not have physical cameras available
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      setState(() {
        _isCameraAvailable = false;
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _isCameraAvailable = false;
        });
        return;
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );

      await controller.initialize();

      if (!mounted) return;

      _cameraController = controller;
      _autoAdjustController = AdaptiveAutoAdjustController(
        cameraController: controller,
      );

      // Start the live frame stream for on-device OCR
      await controller.startImageStream(_processCameraFrame);

      debugPrint('[Countr Scanner] Camera successfully started: ${backCamera.name} (${controller.resolutionPreset}, ${controller.imageFormatGroup})');

      setState(() {
        _isCameraAvailable = true;
      });
    } catch (e) {
      debugPrint('Camera init error (graceful fallback active): $e');
      if (mounted) {
        setState(() {
          _isCameraAvailable = false;
        });
      }
    }
  }

  /// Pauses camera preview and frame processing to conserve device battery.
  Future<void> _pauseScanning({bool pausePreview = true}) async {
    if (_isScanningPaused) return;

    _scanLineController.stop();

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
        if (pausePreview) {
          await _cameraController!.pausePreview();
        }
      } catch (e) {
        debugPrint('Error pausing camera: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isScanningPaused = true;
      });
    }
  }

  /// Resumes camera preview and live frame stream.
  Future<void> _resumeScanning({bool force = false}) async {
    if (!force && !_isScanningPaused && (_cameraController != null && _cameraController!.value.isStreamingImages)) {
      return;
    }

    _isProcessing = false;

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        await _cameraController!.resumePreview();
      } catch (e) {
        debugPrint('Error resuming preview: $e');
      }
      try {
        if (!_cameraController!.value.isStreamingImages) {
          await _cameraController!.startImageStream(_processCameraFrame);
          debugPrint('[Countr Scanner] Camera image stream resumed successfully.');
        }
      } catch (e) {
        debugPrint('Error restarting image stream: $e');
      }
    }

    _scanLineController.repeat(reverse: true);

    if (mounted) {
      setState(() {
        _isScanningPaused = false;
      });
    }
  }

  /// Toggles between active scanning and battery-saver paused state.
  Future<void> _togglePause() async {
    if (_isScanningPaused) {
      await _resumeScanning();
    } else {
      await _pauseScanning(pausePreview: true);
    }
  }

  /// Opens the Inbox screen while automatically stopping the camera
  /// to conserve battery, and cleanly resuming upon return.
  Future<void> _openInbox() async {
    final wasAlreadyPaused = _isScanningPaused;
    if (!_isScanningPaused) {
      await _pauseScanning(pausePreview: true);
    }
    if (!mounted) return;
    await InboxScreen.show(context);
    if (!wasAlreadyPaused && mounted) {
      await _resumeScanning(force: true);
    }
  }

  /// Evaluates each camera stream frame with deterministic frame skipping
  /// (1 in 10 frames, ~3-6 FPS) and strict asynchronous lock to prevent CPU/GPU choking
  /// and permanent camera stream freezes.
  Future<void> _processCameraFrame(CameraImage image) async {
    _frameCount++;
    if (_frameCount % 10 != 0 || _isProcessing || _isScanningPaused) {
      return;
    }
    _isProcessing = true;

    try {
      final camera = _cameraController?.description;
      if (camera == null) return;

      final inputImage = CameraImageConverter.toInputImage(
        image: image,
        camera: camera,
        deviceOrientation: _cameraController?.value.deviceOrientation,
      );

      if (inputImage == null) return;

      // R2: Object-first detection gate before OCR
      Rect? detectedObjectBox;
      if (!_useObjectDetectionFallback) {
        try {
          final objects = await _objectDetector.processImage(inputImage);
          if (objects.isEmpty) {
            // Abort frame processing early if no card/object detected
            if (_lastCardDetectedTime == null ||
                DateTime.now().difference(_lastCardDetectedTime!) >
                    const Duration(milliseconds: 1200)) {
              _detectedCardBounds = null;
            }
            return;
          }
          detectedObjectBox = objects.first.boundingBox;
        } catch (e) {
          debugPrint(
              '[Countr Scanner] Object detection unavailable, falling back to CardPerimeterCalculator: $e');
          _useObjectDetectionFallback = true;
        }
      }

      final recognized = await _textRecognizer.processImage(inputImage);

      // Card bounding perimeter calculation
      if (detectedObjectBox != null && mounted) {
        final rawSize = inputImage.metadata?.size ??
            Size(image.width.toDouble(), image.height.toDouble());
        final uprightSize = CardPerimeterCalculator.getUprightImageSize(
          rawSize: rawSize,
          rotation: inputImage.metadata?.rotation,
        );
        final screenSize = MediaQuery.of(context).size;
        _detectedCardBounds = CardPerimeterCalculator.mapImageRectToScreen(
          imageRect: detectedObjectBox,
          imageSize: uprightSize,
          screenSize: screenSize,
        );
        _lastCardDetectedTime = DateTime.now();
      } else if (recognized.blocks.isNotEmpty && mounted) {
        final rawSize = inputImage.metadata?.size ??
            Size(image.width.toDouble(), image.height.toDouble());
        final uprightSize = CardPerimeterCalculator.getUprightImageSize(
          rawSize: rawSize,
          rotation: inputImage.metadata?.rotation,
        );

        final perimeter = CardPerimeterCalculator.calculatePerimeter(
          recognized.blocks,
          imageSize: uprightSize,
        );

        if (perimeter != null) {
          final screenSize = MediaQuery.of(context).size;
          _detectedCardBounds = CardPerimeterCalculator.mapImageRectToScreen(
            imageRect: perimeter,
            imageSize: uprightSize,
            screenSize: screenSize,
          );
          _lastCardDetectedTime = DateTime.now();
        }
      } else {
        if (_lastCardDetectedTime == null ||
            DateTime.now().difference(_lastCardDetectedTime!) >
                const Duration(milliseconds: 1200)) {
          _detectedCardBounds = null;
        }
      }

      final cleanedLines = OcrHeuristicMatcher.extractCleanedLines(recognized);
      final ocrResult = OcrHeuristicMatcher.parseRecognizedText(recognized);

      if (cleanedLines.isEmpty) {
        final now = DateTime.now();
        if (_lastIdleLogTime == null ||
            now.difference(_lastIdleLogTime!) > const Duration(seconds: 2)) {
          _lastIdleLogTime = now;
          debugPrint(
              '[Countr Scanner] Video stream active (${image.width}x${image.height}): awaiting card in frame...');
        }
        await _autoAdjustController?.onFrameResult(matched: false);
        return;
      }

      final dao = ref.read(vaultDaoProvider);
      final activeGame = ref.read(activeGameContextProvider);

      debugPrint(
          '[Countr Scanner OCR] Recognized ${cleanedLines.length} candidate lines: $cleanedLines (Active Game: $activeGame)');
      if (ocrResult.collectorNumber != null || ocrResult.setCode != null) {
        debugPrint(
            '[Countr Scanner OCR] Collector: ${ocrResult.collectorNumber}, Set: ${ocrResult.setCode}');
      }

      final card = await dao.matchScannedCard(
        cleanedLines,
        activeGame,
        collectorNumber: ocrResult.collectorNumber,
        setCode: ocrResult.setCode,
        enforceMultiFactor: true,
      );

      if (card != null) {
        // Debounce same card in frame (4 seconds) to avoid immediate re-trigger loop
        if (_lastMatchedCardId == card.id &&
            _lastMatchTimestamp != null &&
            DateTime.now().difference(_lastMatchTimestamp!) <
                const Duration(seconds: 4)) {
          return;
        }
        _lastMatchedCardId = card.id;
        _lastMatchTimestamp = DateTime.now();

        debugPrint(
            '>>> [Countr Scanner MATCH SUCCESS] Card "${card.name}" matched! Set: "${card.setOrSeries}", ID: "${card.id}" (Context: $activeGame)');

        HapticFeedback.mediumImpact();
        await _autoAdjustController?.onFrameResult(matched: true);
        await _onCardMatched(card);
      } else {
        debugPrint(
            '[Countr Scanner NO MATCH] No card in database matched lines: $cleanedLines in active context: "$activeGame"');
        await _autoAdjustController?.onFrameResult(matched: false);
      }
    } catch (e, stack) {
      debugPrint('[Countr Scanner ERROR] OCR stream exception: $e\n$stack');
    } finally {
      _isProcessing = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// Staged card handling: adds card to inbox in background,
  /// triggers animated top success toast, and keeps continuous camera scanning active.
  Future<void> _onCardMatched(VaultItem card) async {
    final dao = ref.read(vaultDaoProvider);

    debugPrint(
        '>>> [Countr Scanner CONTINUOUS SCAN] Adding "${card.name}" to Inbox and displaying success toast...');

    // Instant background UPSERT to Inbox
    await dao.upsertScannedCardToInbox(card, isFoil: _isFoilMode);

    if (mounted) {
      setState(() {
        _sessionScanCount++;
        _isGreenFlash = true;
        _scannedToastCard = card;
      });

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _isGreenFlash = false;
          });
        }
      });
    }
  }

  Future<void> _toggleTorch() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      setState(() => _flashOn = !_flashOn);
      return;
    }

    try {
      final newFlash = !_flashOn;
      await _cameraController!.setFlashMode(
        newFlash ? FlashMode.torch : FlashMode.off,
      );
      setState(() => _flashOn = newFlash);
    } catch (_) {
      setState(() => _flashOn = !_flashOn);
    }
  }

  Future<void> _toggleExposureLock() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      setState(() => _isExposureLocked = !_isExposureLocked);
      return;
    }

    try {
      final newLock = !_isExposureLocked;
      await _cameraController!.setExposureMode(
        newLock ? ExposureMode.locked : ExposureMode.auto,
      );
      setState(() => _isExposureLocked = newLock);
    } catch (_) {
      setState(() => _isExposureLocked = !_isExposureLocked);
    }
  }

  /// Test helper to simulate detection of a card in headless or widget test environments.
  @visibleForTesting
  Future<void> simulateCardDetection(VaultItem card) => _onCardMatched(card);

  @visibleForTesting
  int get frameCount => _frameCount;

  @visibleForTesting
  bool get isProcessing => _isProcessing;

  @visibleForTesting
  bool get isProcessingFrame => _isProcessing;

  @visibleForTesting
  Rect? get detectedCardBounds => _detectedCardBounds;

  @visibleForTesting
  void simulateDetectedBounds(Rect? bounds) =>
      setState(() => _detectedCardBounds = bounds);

  @visibleForTesting
  Future<void> processCameraFrameForTesting(CameraImage image) =>
      _processCameraFrame(image);

  @visibleForTesting
  bool get useObjectDetectionFallback => _useObjectDetectionFallback;

  @visibleForTesting
  set useObjectDetectionFallback(bool value) =>
      _useObjectDetectionFallback = value;

  @visibleForTesting
  VaultItem? get scannedToastCard => _scannedToastCard;

  @override
  void dispose() {
    _scanLineController.dispose();
    _cameraController?.dispose();
    _autoAdjustController?.dispose();
    _objectDetector.close();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera Feed or Dark Sensor Grid
            if (_isCameraAvailable &&
                _cameraController != null &&
                _cameraController!.value.isInitialized)
              Center(
                child: CameraPreview(_cameraController!),
              )
            else
              Container(
                color: const Color(0xFF07090C),
                child: CustomPaint(painter: _CameraGridPainter()),
              ),

            // Dynamic ManaBox-Style Reactive Scanner Overlay
            DynamicScannerOverlay(
              cardBounds: _detectedCardBounds,
              isGreenFlash: _isGreenFlash,
              isPaused: _isScanningPaused,
              scanLineAnimation: _scanLineController,
            ),

            // Center Pause Overlay (Only rendered when scanning is paused for battery saving)
            if (_isScanningPaused)
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.accentAmber,
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentAmber.withValues(alpha: 0.2),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pause_circle_filled_rounded,
                        color: AppColors.accentAmber,
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'SCANNING PAUSED',
                        style: TextStyle(
                          color: AppColors.accentAmber,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Battery Saver Active • Camera Idle',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _resumeScanning,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentEmerald,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                size: 16,
                                color: AppColors.textDark,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Resume Scanner',
                                style: TextStyle(
                                  color: AppColors.textDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Top Control Bar with Inbox Floating Button & Session Badge
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close Modal Button
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                    ),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),

                  // Header Badge: AI Engine Ready / Paused
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isScanningPaused
                                ? AppColors.accentAmber
                                : AppColors.surfaceBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isScanningPaused
                                    ? AppColors.accentAmber
                                    : (_isCameraAvailable
                                        ? AppColors.accentEmerald
                                        : AppColors.accentAmber),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isScanningPaused
                                  ? 'PAUSED (BATTERY SAVER)'
                                  : (_isCameraAvailable
                                      ? 'AI ENGINE LIVE'
                                      : 'SIMULATOR ACTIVE'),
                              style: TextStyle(
                                color: _isScanningPaused
                                    ? AppColors.accentAmber
                                    : AppColors.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Floating Inbox Button with Live Session Badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor:
                              AppColors.accentCyan.withValues(alpha: 0.2),
                          side: const BorderSide(
                              color: AppColors.accentCyan, width: 1),
                        ),
                        icon: const Icon(Icons.inbox_rounded,
                            color: AppColors.accentCyan),
                        onPressed: _openInbox,
                      ),
                      if (_sessionScanCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accentEmerald,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Center(
                              child: Text(
                                '$_sessionScanCount',
                                style: const TextStyle(
                                  color: AppColors.textDark,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Floating Controls Bar (Foil Toggle, Auto-Adjust, Torch, Exposure Lock)
            Positioned(
              top: 70,
              left: 16,
              right: 16,
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Foil / Variant Toggle
                      FilterChip(
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: _isFoilMode ? AppColors.textDark : AppColors.accentAmber,
                        ),
                        label: const Text('Foil/Variant'),
                        selected: _isFoilMode,
                        onSelected: (val) => setState(() => _isFoilMode = val),
                        selectedColor: AppColors.accentAmber,
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _isFoilMode ? AppColors.textDark : Colors.white,
                        ),
                        side: BorderSide(
                          color: _isFoilMode
                              ? AppColors.accentAmber
                              : AppColors.surfaceBorder,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Auto-Adjust Glare Reduction Toggle
                      if (_autoAdjustController != null)
                        ValueListenableBuilder<bool>(
                          valueListenable: _autoAdjustController!.isEnabledNotifier,
                          builder: (context, autoAdjustEnabled, _) {
                            return ValueListenableBuilder<double>(
                              valueListenable:
                                  _autoAdjustController!.exposureOffsetNotifier,
                              builder: (context, exposureOffset, _) {
                                final label = autoAdjustEnabled
                                    ? (exposureOffset < 0
                                        ? 'Auto: ${exposureOffset.toStringAsFixed(1)}'
                                        : 'Auto: ON')
                                    : 'Auto: OFF';

                                return FilterChip(
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  avatar: Icon(
                                    Icons.wb_incandescent_outlined,
                                    size: 14,
                                    color: autoAdjustEnabled
                                        ? AppColors.textDark
                                        : AppColors.textSecondary,
                                  ),
                                  label: Text(label),
                                  selected: autoAdjustEnabled,
                                  onSelected: (_) {
                                    _autoAdjustController?.toggle();
                                    setState(() {});
                                  },
                                  selectedColor: AppColors.accentCyan,
                                  backgroundColor:
                                      Colors.black.withValues(alpha: 0.6),
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: autoAdjustEnabled
                                        ? AppColors.textDark
                                        : Colors.white,
                                  ),
                                  side: BorderSide(
                                    color: autoAdjustEnabled
                                        ? AppColors.accentCyan
                                        : AppColors.surfaceBorder,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      if (_autoAdjustController != null) const SizedBox(width: 8),

                      // Torch Toggle
                      IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: _flashOn
                              ? AppColors.accentAmber.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.6),
                          side: BorderSide(
                            color: _flashOn
                                ? AppColors.accentAmber
                                : AppColors.surfaceBorder,
                          ),
                        ),
                        icon: Icon(
                          _flashOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          size: 18,
                          color: _flashOn ? AppColors.accentAmber : Colors.white,
                        ),
                        onPressed: _toggleTorch,
                      ),
                      const SizedBox(width: 6),

                      // Exposure Lock Toggle
                      IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: _isExposureLocked
                              ? AppColors.accentRose.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.6),
                          side: BorderSide(
                            color: _isExposureLocked
                                ? AppColors.accentRose
                                : AppColors.surfaceBorder,
                          ),
                        ),
                        icon: Icon(
                          _isExposureLocked
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          size: 18,
                          color: _isExposureLocked
                              ? AppColors.accentRose
                              : Colors.white,
                        ),
                        onPressed: _toggleExposureLock,
                      ),
                      const SizedBox(width: 6),

                      // Battery-Saver Pause / Resume Toggle
                      IconButton.filledTonal(
                        key: const Key('scanner_pause_toggle'),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: _isScanningPaused
                              ? AppColors.accentAmber.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.6),
                          side: BorderSide(
                            color: _isScanningPaused
                                ? AppColors.accentAmber
                                : AppColors.surfaceBorder,
                          ),
                        ),
                        icon: Icon(
                          _isScanningPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          size: 18,
                          color: _isScanningPaused
                              ? AppColors.accentAmber
                              : Colors.white,
                        ),
                        tooltip: _isScanningPaused
                            ? 'Resume Scanner'
                            : 'Pause Scanner (Save Battery)',
                        onPressed: _togglePause,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Scan Controls & Modes
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mode Selector Tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_scanModes.length, (index) {
                        final isSelected = _selectedModeIndex == index;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(_scanModes[index]),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedModeIndex = index;
                                });
                              }
                            },
                            labelStyle: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: isSelected
                                  ? AppColors.textDark
                                  : AppColors.textSecondary,
                            ),
                            selectedColor: AppColors.accentCyan,
                            backgroundColor:
                                AppColors.surface.withValues(alpha: 0.8),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.accentCyan
                                  : AppColors.surfaceBorder,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Continuous Streaming Live Indicator (Zero Keystrokes)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _isScanningPaused
                              ? AppColors.accentAmber
                              : (_isGreenFlash
                                  ? AppColors.accentEmerald
                                  : AppColors.accentCyan.withValues(alpha: 0.6)),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isGreenFlash
                                    ? AppColors.accentEmerald
                                    : AppColors.accentCyan)
                                .withValues(alpha: 0.15),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isScanningPaused
                                    ? AppColors.accentAmber
                                    : AppColors.accentEmerald,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isScanningPaused
                                  ? 'SCANNER PAUSED (BATTERY SAVER)'
                                  : 'CONTINUOUS STREAM ACTIVE • AUTO-DETECTING',
                              style: TextStyle(
                                color: _isScanningPaused
                                    ? AppColors.accentAmber
                                    : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'ALIGN CARD WITHIN FRAME TO AUTO-CAPTURE & STAGE',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 1.0,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ManaBox-Style Animated Floating Top Success Toast (rendered last in Stack so it paints on top of all controls and receives taps)
            if (_scannedToastCard != null)
              Positioned(
                top: 64,
                left: 0,
                right: 0,
                child: ScannerSuccessToast(
                  key: ValueKey('toast_${_scannedToastCard!.id}_$_sessionScanCount'),
                  card: _scannedToastCard!,
                  isFoil: _isFoilMode,
                  onTap: _openInbox,
                  onDismissed: () {
                    if (mounted) {
                      setState(() {
                        _scannedToastCard = null;
                      });
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CameraGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.8;

    final dx = size.width / 3;
    final dy = size.height / 3;

    canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
    canvas.drawLine(Offset(dx * 2, 0), Offset(dx * 2, size.height), paint);
    canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    canvas.drawLine(Offset(0, dy * 2), Offset(size.width, dy * 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

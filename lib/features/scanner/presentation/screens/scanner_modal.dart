import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/state/app_state.dart';
import '../../../vault/presentation/providers/vault_providers.dart';
import '../../domain/adaptive_auto_adjust_controller.dart';
import '../../domain/ocr_heuristic_matcher.dart';
import '../../utils/camera_image_converter.dart';
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

  int _selectedModeIndex = 0;
  bool _flashOn = false;
  bool _isFoilMode = false;
  bool _isExposureLocked = false;
  bool _isGreenFlash = false;
  bool _isProcessingFrame = false;
  bool _isCameraAvailable = false;
  bool _isScanningPaused = false;
  int _sessionScanCount = 0;

  String? _lastMatchedCardName;
  DateTime? _lastMatchTimestamp;

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
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

      await controller.initialize();

      if (!mounted) return;

      _cameraController = controller;
      _autoAdjustController = AdaptiveAutoAdjustController(
        cameraController: controller,
      );

      // Start the live frame stream for on-device OCR
      await controller.startImageStream(_processCameraFrame);

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
  Future<void> _resumeScanning() async {
    if (!_isScanningPaused) return;

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        await _cameraController!.resumePreview();
      } catch (e) {
        debugPrint('Error resuming preview: $e');
      }
      try {
        if (!_cameraController!.value.isStreamingImages) {
          await _cameraController!.startImageStream(_processCameraFrame);
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
      await _resumeScanning();
    }
  }

  /// Evaluates each camera stream frame with performance lock dropping frames
  /// while ML Kit or SQLite processing is busy, or while scanner is paused.
  Future<void> _processCameraFrame(CameraImage image) async {
    if (_isProcessingFrame || _isScanningPaused) return; // Strict frame drop lock for 60fps UI & battery
    _isProcessingFrame = true;

    try {
      final camera = _cameraController?.description;
      if (camera == null) return;

      final inputImage = CameraImageConverter.toInputImage(
        image: image,
        camera: camera,
      );

      if (inputImage == null) return;

      final recognized = await _textRecognizer.processImage(inputImage);
      final ocrResult = OcrHeuristicMatcher.parseRecognizedText(recognized);

      bool matched = false;
      final dao = ref.read(vaultDaoProvider);
      final activeGame = ref.read(activeGameContextProvider);

      for (final candidate in ocrResult.candidateNames) {
        final card = await dao.matchScannedCard(
          candidateName: candidate,
          collectorNumber: ocrResult.collectorNumber,
          setCode: ocrResult.setCode,
          collectionType: activeGame,
        );

        if (card != null) {
          // Debounce same card scan within 2.5 seconds
          final now = DateTime.now();
          if (_lastMatchedCardName == card.name &&
              _lastMatchTimestamp != null &&
              now.difference(_lastMatchTimestamp!).inMilliseconds < 2500) {
            matched = true;
            break;
          }

          matched = true;
          _lastMatchedCardName = card.name;
          _lastMatchTimestamp = now;

          await _onCardMatched(card);
          break;
        }
      }

      await _autoAdjustController?.onFrameResult(matched: matched);
    } catch (e) {
      debugPrint('OCR stream exception: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _onCardMatched(VaultItem card) async {
    final dao = ref.read(vaultDaoProvider);

    // Instant UPSERT to Inbox
    await dao.upsertScannedCardToInbox(card, isFoil: _isFoilMode);

    // Haptic pulse & visual feedback
    HapticFeedback.mediumImpact();

    if (mounted) {
      setState(() {
        _sessionScanCount++;
        _isGreenFlash = true;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.accentEmerald, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Added to Inbox: ${card.name} ${_isFoilMode ? "(Foil)" : ""}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.surfaceRaised,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1800),
        ),
      );

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

  /// Shutter trigger: in live mode or simulated mode, scans the top card
  /// or first available card to verify pipeline on simulator/test environments.
  Future<void> _triggerManualScan() async {
    final dao = ref.read(vaultDaoProvider);
    final activeGame = ref.read(activeGameContextProvider);

    // Look for any card in current collection
    final items = await dao.getItemsByCollection(activeGame, limit: 1);
    if (items.isNotEmpty) {
      await _onCardMatched(items.first);
    } else {
      // Fallback: create mock card and add to inbox
      final mock = VaultItem(
        id: 'manual-scan-${DateTime.now().millisecondsSinceEpoch}',
        collectionType: activeGame == 'all' ? 'mtg' : activeGame,
        name: 'Black Lotus (Scanned)',
        setOrSeries: 'Limited Edition Alpha',
        imageUrl: '',
        acquiredPrice: 25000.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: _isFoilMode ? 'NM (Foil)' : 'NM',
        isGraded: false,
        personalNotes: _isFoilMode ? 'Scanned Foil / Variant' : 'Edge Scanned',
        currentMarketPrice: 27500.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{"collector_number":"232","rarity":"rare"}',
        primaryBinderId: null,
      );
      await _onCardMatched(mock);
    }
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _cameraController?.dispose();
    _autoAdjustController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeGame = ref.watch(activeGameContextProvider);

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

            // Viewfinder & Scanning Reticle
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: AspectRatio(
                  aspectRatio: 0.70, // Standard card ratio ~2.5 x 3.5
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isScanningPaused
                            ? AppColors.accentAmber
                            : (_isGreenFlash
                                ? AppColors.accentEmerald
                                : AppColors.accentCyan.withValues(alpha: 0.6)),
                        width: _isGreenFlash ? 3.0 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isScanningPaused
                              ? AppColors.accentAmber.withValues(alpha: 0.3)
                              : (_isGreenFlash
                                  ? AppColors.accentEmerald.withValues(alpha: 0.4)
                                  : AppColors.accentCyan.withValues(alpha: 0.15)),
                          blurRadius: _isGreenFlash ? 30 : 20,
                          spreadRadius: _isGreenFlash ? 4 : 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Reticle Corners
                        _ReticleCorner(
                          top: 0,
                          left: 0,
                          isTop: true,
                          isLeft: true,
                          color: _isGreenFlash
                              ? AppColors.accentEmerald
                              : AppColors.accentCyan,
                        ),
                        _ReticleCorner(
                          top: 0,
                          right: 0,
                          isTop: true,
                          isLeft: false,
                          color: _isGreenFlash
                              ? AppColors.accentEmerald
                              : AppColors.accentCyan,
                        ),
                        _ReticleCorner(
                          bottom: 0,
                          left: 0,
                          isTop: false,
                          isLeft: true,
                          color: _isGreenFlash
                              ? AppColors.accentEmerald
                              : AppColors.accentCyan,
                        ),
                        _ReticleCorner(
                          bottom: 0,
                          right: 0,
                          isTop: false,
                          isLeft: false,
                          color: _isGreenFlash
                              ? AppColors.accentEmerald
                              : AppColors.accentCyan,
                        ),

                        // Animated Scanning Line (Active only when scanning)
                        if (!_isScanningPaused)
                          AnimatedBuilder(
                            animation: _scanLineController,
                            builder: (context, child) {
                              return Align(
                                alignment: Alignment(
                                  0.0,
                                  (_scanLineController.value * 2) - 1.0,
                                ),
                                child: Container(
                                  height: 2.5,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        (_isGreenFlash
                                                ? AppColors.accentEmerald
                                                : AppColors.accentCyan)
                                            .withValues(alpha: 0.8),
                                        Colors.white,
                                        (_isGreenFlash
                                                ? AppColors.accentEmerald
                                                : AppColors.accentCyan)
                                            .withValues(alpha: 0.8),
                                        Colors.transparent,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isGreenFlash
                                                ? AppColors.accentEmerald
                                                : AppColors.accentCyan)
                                            .withValues(alpha: 0.7),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                        // Center Status Banner
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _isScanningPaused
                                    ? AppColors.accentAmber
                                    : (_isGreenFlash
                                        ? AppColors.accentEmerald
                                        : AppColors.accentCyan),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isScanningPaused
                                          ? AppColors.accentAmber
                                          : (_isGreenFlash
                                              ? AppColors.accentEmerald
                                              : AppColors.accentCyan))
                                      .withValues(alpha: 0.2),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isScanningPaused
                                      ? Icons.pause_circle_filled_rounded
                                      : (_isGreenFlash
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.camera_alt_rounded),
                                  color: _isScanningPaused
                                      ? AppColors.accentAmber
                                      : (_isGreenFlash
                                          ? AppColors.accentEmerald
                                          : AppColors.accentCyan),
                                  size: 28,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isScanningPaused
                                      ? 'SCANNING PAUSED'
                                      : (_isGreenFlash
                                          ? 'CARD IDENTIFIED!'
                                          : 'Scanner Camera Active'),
                                  style: TextStyle(
                                    color: _isScanningPaused
                                        ? AppColors.accentAmber
                                        : (_isGreenFlash
                                            ? AppColors.accentEmerald
                                            : Colors.white),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _isScanningPaused
                                      ? 'Battery Saver Active • Camera Idle'
                                      : (_isCameraAvailable
                                          ? 'Point at card in ${activeGame.toUpperCase()} collection'
                                          : 'Simulation Mode (Ready)'),
                                  style: TextStyle(
                                    color: AppColors.textSecondary
                                        .withValues(alpha: 0.9),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (_isScanningPaused) ...[
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
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  Container(
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Foil / Variant Toggle
                  FilterChip(
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
                  const SizedBox(width: 8),

                  // Torch Toggle
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
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
                    style: IconButton.styleFrom(
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
                    style: IconButton.styleFrom(
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

                  const SizedBox(height: 18),

                  // Shutter Button
                  GestureDetector(
                    onTap: _triggerManualScan,
                    child: Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isGreenFlash
                              ? AppColors.accentEmerald
                              : AppColors.accentCyan,
                          width: 3,
                        ),
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Color(0xFF090B0E),
                          size: 32,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  Text(
                    'TAP TO CAPTURE & STAGE TO INBOX',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReticleCorner extends StatelessWidget {
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final bool isTop;
  final bool isLeft;
  final Color color;

  const _ReticleCorner({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.isTop,
    required this.isLeft,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    const double length = 24.0;
    const double thickness = 3.0;

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: SizedBox(
        width: length,
        height: length,
        child: CustomPaint(
          painter: _CornerPainter(
            isTop: isTop,
            isLeft: isLeft,
            thickness: thickness,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;
  final double thickness;
  final Color color;

  _CornerPainter({
    required this.isTop,
    required this.isLeft,
    required this.thickness,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(size.width, size.height);
      path.lineTo(size.width, 0);
      path.lineTo(0, 0);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) =>
      oldDelegate.color != color;
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

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/app_database.dart';

/// ManaBox-style animated floating top success prompt that smoothly slides in
/// from the top edge upon successful card scan match and auto-dismisses after
/// 1.5 seconds without interrupting continuous camera scanning.
class ScannerSuccessToast extends StatefulWidget {
  final VaultItem card;
  final String? setCode;
  final bool isFoil;
  final VoidCallback? onTap;
  final VoidCallback? onDismissed;
  final Duration autoDismissDuration;
  final bool autoDismiss;
  final Animation<double>? animation;

  const ScannerSuccessToast({
    super.key,
    required this.card,
    this.setCode,
    this.isFoil = false,
    this.onTap,
    this.onDismissed,
    this.autoDismissDuration = const Duration(milliseconds: 1500),
    this.autoDismiss = true,
    this.animation,
  });

  @override
  State<ScannerSuccessToast> createState() => _ScannerSuccessToastState();
}

class _ScannerSuccessToastState extends State<ScannerSuccessToast>
    with SingleTickerProviderStateMixin {
  AnimationController? _internalController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _startDismissTimer();
  }

  void _initAnimation() {
    if (widget.animation != null) {
      _slideAnimation = Tween<Offset>(
        begin: const Offset(0.0, -1.2),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: widget.animation!,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ));
      _fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: widget.animation!,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ));
    } else {
      _internalController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250),
        reverseDuration: const Duration(milliseconds: 200),
      );
      _slideAnimation = Tween<Offset>(
        begin: const Offset(0.0, -1.2),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _internalController!,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ));
      _fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _internalController!,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ));
      _internalController!.forward();
    }
  }

  void _startDismissTimer() {
    _dismissTimer?.cancel();
    if (widget.autoDismiss) {
      _dismissTimer = Timer(widget.autoDismissDuration, () {
        if (!mounted) return;
        if (_internalController != null) {
          _internalController!.reverse().then((_) {
            if (mounted) {
              widget.onDismissed?.call();
            }
          });
        } else {
          widget.onDismissed?.call();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant ScannerSuccessToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id ||
        oldWidget.isFoil != widget.isFoil) {
      if (_internalController != null) {
        _internalController!.reset();
        _internalController!.forward();
      }
      _startDismissTimer();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _internalController?.dispose();
    super.dispose();
  }

  String get _resolvedSetCode {
    if (widget.setCode != null && widget.setCode!.trim().isNotEmpty) {
      return widget.setCode!.trim();
    }
    try {
      if (widget.card.dynamicData.isNotEmpty) {
        final decoded = jsonDecode(widget.card.dynamicData);
        if (decoded is Map<String, dynamic>) {
          final code = decoded['set_code'] ??
              decoded['set'] ??
              decoded['code'] ??
              decoded['setCode'];
          if (code != null && code.toString().trim().isNotEmpty) {
            return code.toString().trim();
          }
        }
      }
    } catch (_) {}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final setCode = _resolvedSetCode;
    final formattedPrice =
        '\$${widget.card.currentMarketPrice.toStringAsFixed(2)}';

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xF013171F),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.accentEmerald.withValues(alpha: 0.6),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentEmerald.withValues(alpha: 0.25),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Miniaturized card image / placeholder (left, 36x50 rounded rect)
                    Container(
                      key: const Key('scanner_toast_thumbnail'),
                      width: 36,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.accentEmerald.withValues(alpha: 0.4),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: widget.card.imageUrl.isNotEmpty
                          ? Image.network(
                              widget.card.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _buildThumbnailPlaceholder(),
                            )
                          : _buildThumbnailPlaceholder(),
                    ),

                    const SizedBox(width: 12),

                    // Middle: Bold Card Name (top right) & Set Name / Code (bottom right)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.card.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              if (widget.isFoil) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 13,
                                  color: AppColors.accentAmber,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: widget.card.setOrSeries,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (setCode.isNotEmpty &&
                                    setCode.toLowerCase() !=
                                        widget.card.setOrSeries.toLowerCase()) ...[
                                  const TextSpan(
                                    text: ' • ',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  TextSpan(
                                    text: setCode.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.accentCyan,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Far Right: Current Market Price formatted with currency symbol in green
                    Container(
                      key: const Key('scanner_toast_price'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentEmerald.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.accentEmerald.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        formattedPrice,
                        style: const TextStyle(
                          color: AppColors.accentEmerald,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailPlaceholder() {
    return Container(
      color: const Color(0xFF161B22),
      child: const Center(
        child: Icon(
          Icons.style_rounded,
          size: 18,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

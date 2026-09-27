// Copyright (c) 2026 Countr. All rights reserved.
// Production implementation of direct connection and QR code fallback.

import 'dart:math';
import 'package:flutter/foundation.dart';

/// Unambiguous 6-character room code generator.
///
/// Excludes confusing characters: '0', 'O', '1', 'I', 'L'.
abstract class RoomCodeGenerator {
  /// 32-character unambiguous alphanumeric charset (5 bits of entropy per character).
  static const String charset = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const int defaultLength = 6;

  /// Generates a random uppercase room code of the specified length.
  static String generate([int length = defaultLength, Random? random]) {
    final rand = random ?? Random.secure();
    return List.generate(length, (_) => charset[rand.nextInt(charset.length)])
        .join();
  }

  /// Normalizes user-entered room code: trims, uppercases, strips spaces & dashes.
  static String normalize(String code) {
    return code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// Checks if the provided code is a valid room code format.
  static bool isValid(String code) {
    final clean = normalize(code);
    if (clean.length != defaultLength) return false;
    for (int i = 0; i < clean.length; i++) {
      final char = clean[i];
      if (!charset.contains(char) && char != 'L') return false;
    }
    return true;
  }
}

/// Parsed metadata for connecting directly to an MTG pod session.
@immutable
class PodJoinInfo {
  final String host;
  final int port;
  final String roomCode;
  final String sessionId;

  const PodJoinInfo({
    required this.host,
    this.port = 40407,
    required this.roomCode,
    required this.sessionId,
  }) : assert(port >= 1 && port <= 65535, 'Port must be between 1 and 65535');

  /// The WebSocket connection URL for this pod.
  String get websocketUrl => 'ws://$host:$port/pod';

  /// Generates the standard QR code URI string.
  String toQrUri() => PodDirectConnect.generateQrUri(
        host: host,
        port: port,
        roomCode: roomCode,
        sessionId: sessionId,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PodJoinInfo &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port &&
          roomCode == other.roomCode &&
          sessionId == other.sessionId;

  @override
  int get hashCode => Object.hash(host, port, roomCode, sessionId);

  @override
  String toString() =>
      'PodJoinInfo(host: $host:$port, roomCode: $roomCode, session: $sessionId)';
}

/// QR Code URI generator and direct connection fallback parser.
///
/// Follows the schema:
/// `countr://pod/join?host=<ip>&port=40407&code=<code>&session=<id>`
abstract class PodDirectConnect {
  static const String uriScheme = 'countr';
  static const String uriHost = 'pod';
  static const String uriPath = '/join';
  static const int defaultPort = 40407;

  /// Generates a standardized QR code URI string.
  static String generateQrUri({
    required String host,
    int port = defaultPort,
    required String roomCode,
    required String sessionId,
  }) {
    if (port < 1 || port > 65535) {
      throw ArgumentError.value(port, 'port', 'Port must be between 1 and 65535');
    }
    final cleanCode = RoomCodeGenerator.normalize(roomCode);
    final uri = Uri(
      scheme: uriScheme,
      host: uriHost,
      path: uriPath,
      queryParameters: {
        'host': host,
        'port': port.toString(),
        'code': cleanCode,
        'session': sessionId,
      },
    );
    return uri.toString();
  }

  /// Parses a raw QR scan string into a typed [PodJoinInfo].
  ///
  /// Returns `null` if the URI is invalid, has an unsupported scheme, or is missing parameters.
  static PodJoinInfo? parseQrUri(String rawUri) {
    final uri = Uri.tryParse(rawUri.trim());
    if (uri == null) return null;
    if (uri.scheme != uriScheme || uri.host != uriHost || uri.path != uriPath) {
      return null;
    }

    final host = uri.queryParameters['host'];
    final code = uri.queryParameters['code'];
    final session = uri.queryParameters['session'];
    final portStr = uri.queryParameters['port'];
    final int port;
    if (portStr != null) {
      final parsedPort = int.tryParse(portStr);
      if (parsedPort == null || parsedPort < 1 || parsedPort > 65535) {
        return null;
      }
      port = parsedPort;
    } else {
      port = defaultPort;
    }

    if (host == null ||
        host.isEmpty ||
        code == null ||
        code.isEmpty ||
        session == null ||
        session.isEmpty) {
      return null;
    }

    return PodJoinInfo(
      host: host,
      port: port,
      roomCode: RoomCodeGenerator.normalize(code),
      sessionId: session,
    );
  }

  /// Fallback parser for manual user entry (e.g. "192.168.1.150:40407" or "192.168.1.150").
  static PodJoinInfo? parseDirectAddress(
    String input, {
    String roomCode = '',
    String sessionId = '',
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final parts = trimmed.split(':');
    final host = parts[0].trim();
    if (host.isEmpty) return null;

    final int port;
    if (parts.length > 1) {
      if (parts.length > 2) return null;
      final parsedPort = int.tryParse(parts[1].trim());
      if (parsedPort == null || parsedPort < 1 || parsedPort > 65535) {
        return null;
      }
      port = parsedPort;
    } else {
      port = defaultPort;
    }

    return PodJoinInfo(
      host: host,
      port: port,
      roomCode: RoomCodeGenerator.normalize(roomCode),
      sessionId: sessionId,
    );
  }
}

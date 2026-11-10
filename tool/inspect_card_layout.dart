// ignore_for_file: avoid_print, use_null_aware_elements

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const String vmUri = 'ws://127.0.0.1:54057/UPbP8bIIHx8=/ws';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: inspect_card_layout <query>');
    exit(1);
  }

  final query = args.join(' ');
  final ws = await WebSocket.connect(vmUri);
  int reqId = 1;
  final pending = <int, Completer<Map<String, dynamic>>>{};

  Future<Map<String, dynamic>> rpc(String method, [Map<String, dynamic>? params]) {
    final id = reqId++;
    final c = Completer<Map<String, dynamic>>();
    pending[id] = c;
    ws.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    }));
    return c.future;
  }

  ws.listen((data) {
    final msg = jsonDecode(data as String) as Map<String, dynamic>;
    final id = msg['id'] as int?;
    if (id != null && pending.containsKey(id)) {
      final c = pending.remove(id)!;
      if (msg['error'] != null) {
        c.completeError(msg['error'] as Object);
      } else {
        c.complete(msg['result'] as Map<String, dynamic>? ?? {});
      }
    }
  });

  final vm = await rpc('getVM');
  final isolates = vm['isolates'] as List;
  final mainIsolate = isolates.firstWhere((i) => i['name'] == 'main');
  final isoId = mainIsolate['id'] as String;

  final iso = await rpc('getIsolate', {'isolateId': isoId});
  final libs = iso['libraries'] as List;
  final gLib = libs.firstWhere((l) => l['uri'] == 'package:flutter/src/gestures/binding.dart');
  final gLibId = gLib['id'] as String;
  final sLib = libs.firstWhere((l) => l['uri'] == 'package:flutter/src/services/binding.dart');
  final sLibId = sLib['id'] as String;
  final tLib = libs.firstWhere((l) => l['uri'] == 'package:flutter/src/services/text_input.dart');
  final tLibId = tLib['id'] as String;
  final fLib = libs.firstWhere((l) => l['uri'] == 'package:flutter/src/widgets/focus_manager.dart');
  final fLibId = fLib['id'] as String;

  Future<dynamic> eval(String targetId, String expression) async {
    return await rpc('evaluate', {
      'isolateId': isoId,
      'targetId': targetId,
      'expression': expression,
    });
  }

  Future<void> tap(double x, double y) async {
    await eval(gLibId, 'GestureBinding.instance.handlePointerEvent(PointerDownEvent(position: const Offset($x, $y)))');
    await Future.delayed(const Duration(milliseconds: 60));
    await eval(gLibId, 'GestureBinding.instance.handlePointerEvent(PointerUpEvent(position: const Offset($x, $y)))');
  }

  print('1. Tapping search field at (170, 309)...');
  await tap(170, 309);
  await Future.delayed(const Duration(milliseconds: 200));

  final connRes = await eval(tLibId, 'TextInput._instance._currentConnection?._id.toString()');
  final clientIdStr = connRes['valueAsString'] as String?;
  final clientId = int.tryParse(clientIdStr ?? '') ?? 1;
  print('2. Active TextInput clientId: $clientId');

  print('3. Injecting text "$query"...');
  final jsonEscaped = jsonEncode(query);
  final updateExpr = 'ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage('
      'SystemChannels.textInput.name, '
      'SystemChannels.textInput.codec.encodeMethodCall(MethodCall("TextInputClient.updateEditingState", '
      '[$clientId, {"text": $jsonEscaped, "selectionBase": ${query.length}, "selectionExtent": ${query.length}}]'
      ')), null)';
  await eval(sLibId, updateExpr);

  print('4. Waiting 600ms for debounce and database fetch...');
  await Future.delayed(const Duration(milliseconds: 600));

  print('5. Unfocusing keyboard...');
  await eval(fLibId, 'FocusManager.instance.primaryFocus?.unfocus()');
  await Future.delayed(const Duration(milliseconds: 500));

  print('6. Tapping first card at (67, 600)...');
  await tap(67, 600);
  await Future.delayed(const Duration(milliseconds: 600));

  print('Done opening card detail for "$query"');
  await ws.close();
  exit(0);
}

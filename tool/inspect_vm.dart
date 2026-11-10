// ignore_for_file: avoid_print, use_null_aware_elements

import 'dart:convert';
import 'dart:io';
import 'sim_driver.dart';

void main() async {
  final uri = await getVmUri();
  print('Connecting to $uri');
  final ws = await WebSocket.connect(uri);

  int reqId = 1;
  void send(String method, [Map<String, dynamic>? params]) {
    final id = reqId++;
    ws.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    }));
  }

  send('getVM');
  ws.listen((data) {
    final msg = jsonDecode(data as String) as Map<String, dynamic>;
    final id = msg['id'] as int?;
    if (id == 1) {
      final vm = msg['result'] as Map<String, dynamic>;
      final isolates = vm['isolates'] as List;
      final mainIso = isolates.firstWhere((i) => i['name'] == 'main');
      print('Main isolate: ${mainIso['id']}');
      send('getIsolate', {'isolateId': mainIso['id']});
    } else if (id == 2) {
      final iso = msg['result'] as Map<String, dynamic>;
      final rpcs = iso['extensionRPCs'] as List?;
      print('Isolate extensionRPCs:');
      rpcs?.forEach(print);
      ws.close();
      exit(0);
    }
  });
}

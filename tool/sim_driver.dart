// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings, use_null_aware_elements

import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<String> getVmUri() async {
  final env = Platform.environment['VM_URI'];
  if (env != null && env.isNotEmpty) return env;
  final pr = await Process.run('ps', ['aux']);
  final lines = pr.stdout.toString().split('\n');
  for (final line in lines) {
    if (line.contains('development-service') && line.contains('--vm-service-uri=')) {
      final match = RegExp(r'--vm-service-uri=(http://[^\s]+)').firstMatch(line);
      if (match != null) {
        var uri = match.group(1)!;
        if (uri.endsWith('/')) {
          uri = uri.replaceFirst('http://', 'ws://') + 'ws';
        } else {
          uri = uri.replaceFirst('http://', 'ws://') + '/ws';
        }
        return uri;
      }
    }
  }
  return 'ws://127.0.0.1:55303/eHB8ps2VpH4=/ws';
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: sim_driver <command> [args]');
    exit(1);
  }

  final command = args[0];
  final activeUri = await getVmUri();
  final ws = await WebSocket.connect(activeUri);
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

  // Initialize VM and isolate
  final vm = await rpc('getVM');
  final isolates = vm['isolates'] as List;
  final mainIsolate = isolates.firstWhere((i) => i['name'] == 'main');
  final isoId = mainIsolate['id'] as String;

  final iso = await rpc('getIsolate', {'isolateId': isoId});
  final libs = iso['libraries'] as List;
  final gLib = libs.firstWhere((l) => l['uri'] == 'package:flutter/src/gestures/binding.dart');
  final gLibId = gLib['id'] as String;

  final vLib = libs.firstWhere((l) => (l['uri'] as String).contains('vault_screen.dart'));
  final vLibId = vLib['id'] as String;

  final pLib = libs.firstWhere((l) => (l['uri'] as String).contains('user_profile_screen.dart'), orElse: () => vLib);
  final pLibId = pLib['id'] as String;

  final rLib = libs.firstWhere((l) => (l['uri'] as String).contains('app_router.dart'), orElse: () => vLib);
  final rLibId = rLib['id'] as String;

  final mLib = libs.firstWhere((l) => (l['uri'] as String).contains('main.dart'), orElse: () => vLib);
  final mLibId = mLib['id'] as String;

  final ggLib = libs.firstWhere((l) => (l['uri'] as String).contains('group_game_card.dart'), orElse: () => vLib);
  final ggLibId = ggLib['id'] as String;

  Future<dynamic> eval(String targetId, String expression) async {
    return await rpc('evaluate', {
      'isolateId': isoId,
      'targetId': targetId,
      'expression': expression,
      'await': true,
    });
  }

  switch (command) {
    case 'restart':
      print('Restarting app via main()...');
      final res = await eval(mLibId, 'main()');
      print('Restart result: $res');
      break;

    case 'libs':
      for (final l in libs) {
        final uri = l['uri'] as String;
        if (uri.contains('countr')) {
          print(uri);
        }
      }
      break;

    case 'nav':
      final path = args[1];
      print('Navigating to $path...');
      final navRes = await eval(rLibId, 'appRouter.go("$path")');
      print('Nav result: $navRes');
      break;

    case 'push':
      final path = args[1];
      print('Pushing $path...');
      final pushRes = await eval(rLibId, 'appRouter.push("$path")');
      print('Push result: $pushRes');
      break;

    case 'show_quota':
      final qType = args.length > 1 ? args[1] : 'binder';
      print('Showing quota limit prompt sheet for $qType...');
      final qExpr = qType == 'deck'
          ? '((Element root) { Element? target; void walk(Element e) { if (target != null) return; if (e is StatefulElement && e.state is NavigatorState) { target = e; } e.visitChildren(walk); } walk(root); QuotaLimitPromptSheet.showForDecks(target!); return true; })(WidgetsBinding.instance.rootElement!)'
          : '((Element root) { Element? target; void walk(Element e) { if (target != null) return; if (e is StatefulElement && e.state is NavigatorState) { target = e; } e.visitChildren(walk); } walk(root); QuotaLimitPromptSheet.showForBinders(target!); return true; })(WidgetsBinding.instance.rootElement!)';
      final qRes = await eval(pLibId, qExpr);
      print('Quota sheet result: $qRes');
      break;

    case 'verify_quotas':
      print('Verifying Tier Quota limits...');
      final vExpr = '((Element root) async { Element? target; void walk(Element e) { if (target != null) return; if (e is StatefulElement && e.state is NavigatorState) { target = e; } e.visitChildren(walk); } walk(root); final container = ProviderScope.containerOf(target!); final quotaService = container.read(tierQuotaServiceProvider); final gbMax = quotaService.maxCustomBindersFor(AccountTier.guest); final gdMax = quotaService.maxDecksFor(AccountTier.guest); final fbMax = quotaService.maxCustomBindersFor(AccountTier.free); final fdMax = quotaService.maxDecksFor(AccountTier.free); return "guest:\$gbMax,\$gdMax;free:\$fbMax,\$fdMax"; })(WidgetsBinding.instance.rootElement!)';
      final vRes = await eval(pLibId, vExpr);
      print('Verify result: $vRes');
      break;

    case 'seed_profiles':
      print('Seeding default profiles into Drift SQLite database...');
      final sExpr = '((Element root) async { Element? target; void walk(Element e) { if (target != null) return; if (e is StatefulElement && e.state is NavigatorState) { target = e; } e.visitChildren(walk); } walk(root); final container = ProviderScope.containerOf(target!); final db = container.read(appDatabaseProvider); await db.userProfileDao.seedDefaultProfiles(); final profiles = await (db.select(db.userProfiles)).get(); return "profiles_count:\${profiles.length}"; })(WidgetsBinding.instance.rootElement!)';
      final sRes = await eval(pLibId, sExpr);
      print('Seed result: $sRes');
      break;

    case 'db_stats':
      final dbExpr = '((Element root) async { Element? target; void walk(Element e) { if (target != null) return; if (e is StatefulElement && e.state is NavigatorState) { target = e; } e.visitChildren(walk); } walk(root); final container = ProviderScope.containerOf(target!); final db = container.read(appDatabaseProvider); final notifs = await (db.select(db.notifications)).get(); final msgs = await (db.select(db.messages)).get(); final unreadNotifs = notifs.where((n) => !n.isRead && !n.isDeleted).length; final unreadMsgs = msgs.where((m) => !m.isRead && !m.isDeleted).length; return "notifs:\${notifs.length} (unread:\$unreadNotifs), msgs:\${msgs.length} (unread:\$unreadMsgs)"; })(WidgetsBinding.instance.rootElement!)';
      final dbRes = await eval(pLibId, dbExpr);
      print('DB stats: ${dbRes["valueAsString"] ?? dbRes}');
      break;

    case 'rotate_queue':
      final gId = args.length > 1 ? args[1] : 'game_tbs_table_1';
      print('Rotating queue into seats for $gId...');
      final rqExpr = '((Element root) { Element? target; void walk(Element e) { if (target != null) return; if (e is StatefulElement && e.state is NavigatorState) { target = e; } e.visitChildren(walk); } walk(root); final container = ProviderScope.containerOf(target!); final notifier = container.read(groupGamesProvider.notifier); final pod = notifier.rotateQueueIntoSeats("$gId"); return "rotated:players=\${pod?.players.map((p) => "\${p.name}(\${p.life})").toList()},queue=\${container.read(groupGamesProvider).firstWhere((g) => g.id == "$gId").waitlistCount}"; })(WidgetsBinding.instance.rootElement!)';
      final rqRes = await eval(ggLibId, rqExpr);
      print('Rotate result: ${rqRes["valueAsString"] ?? rqRes}');
      break;

    case 'seed_social':
      print('Seeding social data into Drift SQLite database...');
      final ssExpr = '((Element root) async { Element? target; void walk(Element e) { if (target != null) return; if (e is StatefulElement && e.state is NavigatorState) { target = e; } e.visitChildren(walk); } walk(root); final container = ProviderScope.containerOf(target!); final db = container.read(appDatabaseProvider); final notifs = await (db.select(db.notifications)).get(); final msgs = await (db.select(db.messages)).get(); return "pre_seed:notifs=\${notifs.length},msgs=\${msgs.length}"; })(WidgetsBinding.instance.rootElement!)';
      final ssRes = await eval(pLibId, ssExpr);
      print('Seed social result: $ssRes');
      break;

    case 'submit_comment':
      final text = args.length > 1 ? args[1] : 'Awesome brew! Ready for FNM!';
      print('Submitting comment: "$text"...');
      final cExpr = '((Element root) { Element? target; void walk(Element e) { if (target != null) return; if (e.widget is TextField && (e.widget as TextField).key == const Key("post_comment_input")) { target = e; } e.visitChildren(walk); } walk(root); if (target != null) { final tf = target!.widget as TextField; tf.controller?.text = "$text"; tf.onSubmitted?.call("$text"); return true; } return false; })(WidgetsBinding.instance.rootElement!)';
      final cRes = await eval(pLibId, cExpr);
      print('Submit comment result: $cRes');
      break;

    case 'seed_vault':
      print('Seeding starter vault items...');
      final svExpr = '((Element root) { Element? target; void walk(Element e) { if (target != null) return; if (e is StatefulElement && e.state is NavigatorState) { target = e; } e.visitChildren(walk); } walk(root); final container = ProviderScope.containerOf(target!); final db = container.read(appDatabaseProvider); db.vaultDao.seedDatabase(); return true; })(WidgetsBinding.instance.rootElement!)';
      final svRes = await eval(pLibId, svExpr);
      print('Seed vault result: $svRes');
      break;

    case 'vault':
      final sub = args[1];
      if (sub == 'catalog') {
        print('Switching to All Cards (Catalog)...');
        final res = await eval(vLibId, 'liveQASwitchToCatalog()');
        print('Result: $res');
      } else if (sub == 'owned') {
        print('Switching to Owned...');
        final res = await eval(vLibId, 'liveQASwitchToOwned()');
        print('Result: $res');
      } else if (sub == 'dismiss_hydration') {
        print('Dismissing hydration banner...');
        final res = await eval(vLibId, 'liveQADismissHydration()');
        print('Result: $res');
      } else if (sub == 'view') {
        final mode = args[2];
        print('Switching view mode to $mode...');
        final expr = mode == 'binders'
            ? 'liveQASetVaultViewMode(VaultViewMode.binders)'
            : mode == 'collections'
                ? 'liveQASetVaultViewMode(VaultViewMode.collections)'
                : 'liveQASetVaultViewMode(VaultViewMode.singles)';
        final res = await eval(vLibId, expr);
        print('Result: $res');
      } else if (sub == 'search') {
        final query = args.length > 2 ? args.sublist(2).join(' ') : '';
        print('Searching for: "$query"...');
        final res = await eval(vLibId, 'liveQASetSearch("$query")');
        print('Result: $res');
      } else if (sub == 'card') {
        final idx = int.parse(args[2]);
        print('Opening card details for index $idx...');
        final res = await eval(vLibId, 'liveQAOpenCardDetail($idx)');
        print('Result: $res');
      } else if (sub == 'filter_red_commander') {
        print('Applying Red + Commander filter...');
        final expr = 'liveQAApplyMtgFilter(MtgFilterState(colors: {"R"}, colorTarget: ColorTarget.cardColor, colorMatchMode: ColorMatchMode.including, formats: {"commander"}))';
        final res = await eval(vLibId, expr);
        print('Result: $res');
      } else if (sub == 'reset_filter') {
        print('Resetting filter...');
        final res = await eval(vLibId, 'liveQAApplyMtgFilter(const MtgFilterState())');
        print('Result: $res');
      }
      break;

    case 'tap':
      final x = double.parse(args[1]);
      final y = double.parse(args[2]);
      print('Tapping ($x, $y)...');
      await eval(gLibId, 'GestureBinding.instance.handlePointerEvent(PointerDownEvent(position: const Offset($x, $y)))');
      await Future.delayed(const Duration(milliseconds: 60));
      await eval(gLibId, 'GestureBinding.instance.handlePointerEvent(PointerUpEvent(position: const Offset($x, $y)))');
      print('Tap dispatched');
      break;

    case 'drag':
      final x1 = double.parse(args[1]);
      final y1 = double.parse(args[2]);
      final x2 = double.parse(args[3]);
      final y2 = double.parse(args[4]);
      final steps = args.length > 5 ? int.parse(args[5]) : 10;
      print('Dragging from ($x1, $y1) to ($x2, $y2) in $steps steps...');
      await eval(gLibId, 'GestureBinding.instance.handlePointerEvent(PointerDownEvent(position: const Offset($x1, $y1)))');
      for (int i = 1; i <= steps; i++) {
        final curX = x1 + (x2 - x1) * (i / steps);
        final curY = y1 + (y2 - y1) * (i / steps);
        await Future.delayed(const Duration(milliseconds: 25));
        await eval(gLibId, 'GestureBinding.instance.handlePointerEvent(PointerMoveEvent(position: const Offset($curX, $curY)))');
      }
      await Future.delayed(const Duration(milliseconds: 50));
      await eval(gLibId, 'GestureBinding.instance.handlePointerEvent(PointerUpEvent(position: const Offset($x2, $y2)))');
      print('Drag dispatched');
      break;

    case 'scroll':
      final dy = double.parse(args[1]);
      print('Scrolling dy: $dy...');
      await eval(gLibId, 'GestureBinding.instance.handlePointerEvent(PointerScrollEvent(position: const Offset(200, 400), scrollDelta: const Offset(0, $dy)))');
      print('Scroll dispatched');
      break;

    case 'reload':
      print('Triggering hot reload (ext.flutter.hotReload)...');
      try {
        final reloadRes = await rpc('ext.flutter.hotReload', {'isolateId': isoId});
        print('Reload result: $reloadRes');
      } catch (e) {
        print('Reload error: $e');
      }
      print('Triggering reassemble...');
      await rpc('ext.flutter.reassemble', {'isolateId': isoId});
      print('Hot reload complete');
      break;

    case 'pop':
      print('Popping navigation route...');
      final expr = '((Element root) { List<NavigatorState> navs = []; void walk(Element e) { if (e is StatefulElement && e.state is NavigatorState) { navs.add(e.state as NavigatorState); } e.visitChildren(walk); } walk(root); for (final nav in navs.reversed) { if (nav.canPop()) { nav.pop(); return true; } } return false; })(WidgetsBinding.instance.rootElement!)';
      final res = await eval(vLibId, expr);
      print('Pop result: $res');
      break;

    case 'find_key':
      final keyPattern = args[1];
      final findExpr = '((Element root) { Element? found; void walk(Element e) { if (found != null) return; if ((e.widget.key?.toString() ?? "").contains("$keyPattern")) { found = e; return; } e.visitChildren(walk); } walk(root); if (found != null) { final ro = found!.renderObject; if (ro is RenderBox && ro.hasSize) { final pt = ro.localToGlobal(Offset.zero); return "\${pt.dx},\${pt.dy},\${ro.size.width},\${ro.size.height}"; } return "no_renderbox"; } return "not_found"; })(WidgetsBinding.instance.rootElement!)';
      final findRes = await eval(vLibId, findExpr);
      print('Find key result: ${findRes["valueAsString"] ?? findRes}');
      break;

    case 'tap_key':
      final tapKeyPattern = args[1];
      final tapExpr = '((Element root) { Element? found; void walk(Element e) { if (found != null) return; if ((e.widget.key?.toString() ?? "").contains("$tapKeyPattern")) { found = e; return; } e.visitChildren(walk); } walk(root); if (found != null) { final ro = found!.renderObject; if (ro is RenderBox && ro.hasSize) { final pt = ro.localToGlobal(Offset.zero); final cx = pt.dx + ro.size.width / 2; final cy = pt.dy + ro.size.height / 2; return "\$cx,\$cy"; } } return null; })(WidgetsBinding.instance.rootElement!)';
      final tapRes = await eval(vLibId, tapExpr);
      final coords = tapRes['valueAsString'] as String?;
      if (coords != null && coords.contains(',')) {
        final parts = coords.split(',');
        final cx = double.parse(parts[0]);
        final cy = double.parse(parts[1]);
        print('Tapping key "$tapKeyPattern" at ($cx, $cy)...');
        await eval(gLibId, 'GestureBinding.instance.handlePointerEvent(PointerDownEvent(position: const Offset($cx, $cy)))');
        await Future.delayed(const Duration(milliseconds: 60));
        await eval(gLibId, 'GestureBinding.instance.handlePointerEvent(PointerUpEvent(position: const Offset($cx, $cy)))');
        print('Tap key dispatched');
      } else {
        print('Key "$tapKeyPattern" not found or not rendered: $tapRes');
      }
      break;

    case 'eval':
      final target = args[1];
      final expr = args.sublist(2).join(' ');
      final targetLibId = target == 'gesture' ? gLibId : (target == 'vault' ? vLibId : pLibId);
      final res = await eval(targetLibId, expr);
      print('Eval result: $res');
      break;

    default:
      print('Unknown command: $command');
  }

  await ws.close();
  exit(0);
}

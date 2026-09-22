import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

class DeckMetadataScreen extends ConsumerStatefulWidget {
  final Deck deck;
  
  const DeckMetadataScreen({super.key, required this.deck});

  @override
  ConsumerState<DeckMetadataScreen> createState() => _DeckMetadataScreenState();
}

class _DeckMetadataScreenState extends ConsumerState<DeckMetadataScreen> {
  late TextEditingController _primerController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _primerController = TextEditingController(text: widget.deck.description ?? '');
    _primerController.addListener(_onPrimerChanged);
  }

  void _onPrimerChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      final dao = ref.read(vaultDaoProvider);
      dao.updateDeckDescription(widget.deck.id, _primerController.text);
    });
  }

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      final dao = ref.read(vaultDaoProvider);
      dao.updateDeckDescription(widget.deck.id, _primerController.text);
    }
    _primerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchupsAsync = ref.watch(deckMatchupsProvider(widget.deck.id));
    final versionsAsync = ref.watch(deckVersionsProvider(widget.deck.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.deck.name} Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Deck Primer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _primerController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Write your deck primer here...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            
            const Text('Matchup & Sideboard Guides', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            matchupsAsync.when(
              data: (matchups) {
                if (matchups.isEmpty) {
                  return const Text('No matchup guides yet. Add one to keep track of sideboarding!');
                }
                return Column(
                  children: matchups.map((m) {
                    final ins = (m.swapInItemIds ?? '').split('\n').where((s) => s.isNotEmpty).toList();
                    final outs = (m.swapOutItemIds ?? '').split('\n').where((s) => s.isNotEmpty).toList();
                    return _buildMatchupGuide(m.opponentArchetype, ins, outs);
                  }).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, st) => Text('Error: $e'),
            ),
            
            const SizedBox(height: 24),
            const Text('Changelog (Version History)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            versionsAsync.when(
              data: (versions) {
                if (versions.isEmpty) {
                  return const Text('No version history.');
                }
                return Column(
                  children: versions.map((v) {
                    return ListTile(
                      leading: CircleAvatar(child: Text('v${v.versionNumber}')),
                      title: Text(v.versionNote ?? 'No notes'),
                      subtitle: Text(v.createdAt.toLocal().toString().split('.')[0]),
                      trailing: v.isActive ? const Chip(label: Text('Active')) : null,
                    );
                  }).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, st) => Text('Error: $e'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.content_paste),
              label: const Text('Import'),
              onPressed: () {},
            ),
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Export'),
              onPressed: () {},
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.style),
              label: const Text('Draw 7'),
              onPressed: () {}, // Implementation depends on if you want Fast Draw here too. 
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchupGuide(String opponent, List<String> ins, List<String> outs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(opponent, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: ins.map((e) => Text(e, style: const TextStyle(color: Colors.green))).toList(),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: outs.map((e) => Text(e, style: const TextStyle(color: Colors.red))).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


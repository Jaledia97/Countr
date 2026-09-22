import 'package:flutter/material.dart';

class ConflictResolutionModal extends StatelessWidget {
  final String cardName;
  final List<String> deckNames;
  final VoidCallback onMovePhysical;
  final VoidCallback onAddAsProxy;
  final VoidCallback onCancel;

  const ConflictResolutionModal({
    super.key,
    required this.cardName,
    required this.deckNames,
    required this.onMovePhysical,
    required this.onAddAsProxy,
    required this.onCancel,
  });

  static Future<void> show({
    required BuildContext context,
    required String cardName,
    required List<String> deckNames,
    required VoidCallback onMovePhysical,
    required VoidCallback onAddAsProxy,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ConflictResolutionModal(
        cardName: cardName,
        deckNames: deckNames,
        onMovePhysical: () {
          Navigator.of(ctx).pop();
          onMovePhysical();
        },
        onAddAsProxy: () {
          Navigator.of(ctx).pop();
          onAddAsProxy();
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Inventory Conflict', style: TextStyle(color: Colors.redAccent)),
      content: Text(
        'All your physical copies of "$cardName" are currently assigned to:\n\n'
        '${deckNames.join(", ")}\n\n'
        'How would you like to proceed?',
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: onAddAsProxy,
          child: const Text('Add as Proxy'),
        ),
        ElevatedButton(
          onPressed: onMovePhysical,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          child: const Text('Move Physical Here'),
        ),
      ],
    );
  }
}

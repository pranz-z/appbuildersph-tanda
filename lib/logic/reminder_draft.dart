import '../core/app_database.dart';

enum ReminderTone { malambing, diretso }

class ReminderDraftBuilder {
  String build(StoredMemory memory, ReminderTone tone) {
    if (!memory.confirmed ||
        memory.status != 'open' ||
        !const {'lent_item', 'lent_money', 'promise'}.contains(memory.kind)) {
      throw ArgumentError.value(
        memory.uid,
        'memory',
        'Not an eligible open loop',
      );
    }

    final person = _optional(memory.person);
    final item = _optional(memory.item);
    final due = _optional(memory.dueDateText);
    final amount = memory.amount == null ? null : _formatPhp(memory.amount!);
    final greeting = person == null ? '' : 'Hi $person, ';
    final String body;
    switch (memory.kind) {
      case 'lent_item':
        body = tone == ReminderTone.malambing
            ? 'Paalala lang${item == null ? '' : ' tungkol sa $item'}. '
                  'Maaari ba itong maibalik?'
            : 'Paki-balik ${item == null ? 'ito' : 'ang $item'}.';
      case 'lent_money':
        final amountText = amount == null ? '' : ' na ₱$amount';
        body = tone == ReminderTone.malambing
            ? 'Paalala lang tungkol sa utang$amountText. '
                  'Maaari ba itong maibalik?'
            : 'Paki-bayaran ang utang$amountText.';
      case 'promise':
        body = tone == ReminderTone.malambing
            ? 'Paalala lang tungkol sa pangako'
                  '${item == null ? '' : ': $item'}.'
            : 'Paki-tupad ang pangako'
                  '${item == null ? '' : ' tungkol sa $item'}.';
      default:
        throw ArgumentError.value(memory.kind, 'memory.kind');
    }
    final dueNote = due == null ? '' : ' Nabanggit na: $due.';
    final addressedBody = greeting.isEmpty
        ? body
        : '${body[0].toLowerCase()}${body.substring(1)}';
    return '$greeting$addressedBody$dueNote Salamat.';
  }

  String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _formatPhp(double amount) {
    final raw = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
    final parts = raw.split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return parts.length == 1 ? whole : '$whole.${parts.last}';
  }
}

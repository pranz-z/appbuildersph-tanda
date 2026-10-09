import '../notebook_theme.dart';
import '../localization.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/app_database.dart';
import '../../core/providers.dart';
import '../../logic/open_loops.dart';
import '../../logic/reminder_draft.dart';

class NakabinbinScreen extends ConsumerStatefulWidget {
  const NakabinbinScreen({super.key});

  @override
  ConsumerState<NakabinbinScreen> createState() => _NakabinbinScreenState();
}

class _NakabinbinScreenState extends ConsumerState<NakabinbinScreen> {
  final _doneUids = <String>{};
  final _savingUids = <String>{};
  String? _actionError;

  Future<void> _markDone(StoredMemory memory) async {
    final uid = memory.uid;
    if (_savingUids.contains(uid) || _doneUids.contains(uid)) return;
    setState(() {
      _doneUids.add(uid);
      _savingUids.add(uid);
      _actionError = null;
    });
    try {
      final changed = await ref.read(appDatabaseProvider).markMemoryDone(uid);
      if (changed == 0) throw StateError('This open loop was already updated.');
      ref.invalidate(openLoopsProvider);
    } catch (error) {
      if (mounted) {
        setState(() {
          _doneUids.remove(uid);
          _actionError = 'Could not mark this as done. Try again. ($error)';
        });
        ref.invalidate(openLoopsProvider);
      }
    } finally {
      if (mounted) setState(() => _savingUids.remove(uid));
    }
  }

  Future<void> _draftReminder(StoredMemory memory) => showDialog<void>(
    context: context,
    builder: (_) => ReminderDraftDialog(memory: memory),
  );

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(openLoopsProvider);
    return result.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const UiText('Could not load open loops.'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(openLoopsProvider),
                child: const UiText('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (memories) {
        final visible = memories
            .where((memory) => !_doneUids.contains(memory.uid))
            .toList(growable: false);
        final data = OpenLoopsData.fromMemories(visible);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const NotebookHeader(
              title: 'Open loops',
              subtitle: 'Mga bukas na hiram, utang, at pangako.',
              icon: Icons.checklist_rounded,
            ),
            if (_actionError != null) ...[
              const SizedBox(height: 12),
              UiText(
                _actionError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            _moneyTotals(context, data.lentMoneyTotals, visible),
            const SizedBox(height: 16),
            if (data.entries.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, size: 40),
                      SizedBox(height: 8),
                      UiText('No open loops right now.'),
                      UiText(
                        'Confirmed lent items, money, and promises will appear here.',
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final entry in data.entries)
                _OpenLoopCard(
                  key: ValueKey('loop-${entry.memory.uid}'),
                  entry: entry,
                  saving: _savingUids.contains(entry.memory.uid),
                  onDone: () => _markDone(entry.memory),
                  onDraft: () => _draftReminder(entry.memory),
                ),
          ],
        );
      },
    );
  }

  Widget _moneyTotals(
    BuildContext context,
    Map<String, double> totals,
    List<StoredMemory> memories,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UiText(
              'Open lent-money totals',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (totals.isEmpty)
              const UiText('No open money owed.')
            else
              for (final total in totals.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          total.key == 'Unknown person' &&
                                  !memories.any(
                                    (memory) =>
                                        memory.person?.trim() == total.key,
                                  )
                              ? tr(context, 'Unknown person')
                              : total.key,
                        ),
                      ),
                      UiText('₱${_formatAmount(total.value)}'),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _OpenLoopCard extends StatelessWidget {
  const _OpenLoopCard({
    super.key,
    required this.entry,
    required this.saving,
    required this.onDone,
    required this.onDraft,
  });

  final OpenLoopEntry entry;
  final bool saving;
  final VoidCallback onDone;
  final VoidCallback onDraft;

  String _title(BuildContext context) {
    final memory = entry.memory;
    return switch (memory.kind) {
      'lent_item' => _nonEmpty(memory.item) ?? tr(context, 'Item not recorded'),
      'lent_money' =>
        memory.amount == null
            ? tr(context, 'Amount not recorded')
            : uiFormat(context, '₱{1} owed', [_formatAmount(memory.amount!)]),
      'promise' =>
        _nonEmpty(memory.item) ?? tr(context, 'Promise details not recorded'),
      _ => memory.item ?? memory.kind,
    };
  }

  @override
  Widget build(BuildContext context) {
    final memory = entry.memory;
    final person = _nonEmpty(memory.person) ?? tr(context, 'Unknown person');
    final dueLabel = _dueLabel(entry);
    final dueColor = entry.isOverdue
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      key: ValueKey('loop-card-${memory.uid}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_iconFor(memory.kind)),
              title: Text(_title(context)),
              subtitle: Text('${kindLabel(context, memory.kind)} · $person'),
            ),
            UiText(
              dueLabel,
              style: TextStyle(color: dueColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: ValueKey('draft-reminder-${memory.uid}'),
                  onPressed: onDraft,
                  icon: const Icon(Icons.edit_note),
                  label: const UiText('Draft reminder'),
                ),
                FilledButton.tonalIcon(
                  key: ValueKey('done-${memory.uid}'),
                  onPressed: saving ? null : onDone,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: UiText(saving ? 'Saving...' : 'Mark as done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReminderDraftDialog extends StatefulWidget {
  const ReminderDraftDialog({super.key, required this.memory});

  final StoredMemory memory;

  @override
  State<ReminderDraftDialog> createState() => _ReminderDraftDialogState();
}

class _ReminderDraftDialogState extends State<ReminderDraftDialog> {
  final _builder = ReminderDraftBuilder();
  late final TextEditingController _controller = TextEditingController(
    text: _builder.build(widget.memory, _tone),
  );
  ReminderTone _tone = ReminderTone.malambing;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectTone(ReminderTone tone) {
    setState(() {
      _tone = tone;
      final text = _builder.build(widget.memory, tone);
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  Future<void> _copyDraft() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: _controller.text));
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: UiText('Could not copy reminder. Try again.'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: UiText('Reminder copied. Not sent.')),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const UiText('Draft reminder'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<ReminderTone>(
              segments: const [
                ButtonSegment(
                  value: ReminderTone.malambing,
                  label: UiText('Malambing'),
                ),
                ButtonSegment(
                  value: ReminderTone.diretso,
                  label: UiText('Diretso'),
                ),
              ],
              selected: {_tone},
              onSelectionChanged: (selection) => _selectTone(selection.first),
            ),
            const SizedBox(height: 16),
            const UiText('Local and unsent. Edit before copying.'),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('reminder-draft-input'),
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: tr(context, 'Reminder draft'),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const UiText('Close'),
      ),
      FilledButton.icon(
        onPressed: _copyDraft,
        icon: const Icon(Icons.copy),
        label: const UiText('Copy'),
      ),
    ],
  );
}

String _dueLabel(OpenLoopEntry entry) {
  final text = entry.memory.dueDateText?.trim();
  if (!entry.hasDueText) return 'No due date';
  if (entry.isOverdue) return 'Overdue · $text';
  if (entry.dueDate != null) {
    final today = DateTime.now();
    if (entry.dueDate!.year == today.year &&
        entry.dueDate!.month == today.month &&
        entry.dueDate!.day == today.day) {
      return 'Due today · $text';
    }
  }
  return 'Due · $text';
}

IconData _iconFor(String kind) => switch (kind) {
  'lent_item' => Icons.handshake_outlined,
  'lent_money' => Icons.payments_outlined,
  'promise' => Icons.event_note_outlined,
  _ => Icons.pending_actions,
};

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _formatAmount(double amount) {
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

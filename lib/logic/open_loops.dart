import '../core/app_database.dart';

class OpenLoopEntry {
  const OpenLoopEntry({
    required this.memory,
    required this.dueDate,
    required this.hasDueText,
    required this.isOverdue,
  });

  final StoredMemory memory;
  final DateTime? dueDate;
  final bool hasDueText;
  final bool isOverdue;
}

class OpenLoopsData {
  OpenLoopsData._({required this.entries, required this.lentMoneyTotals});

  factory OpenLoopsData.fromMemories(
    Iterable<StoredMemory> memories, {
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final entries = memories
        .where(
          (memory) =>
              memory.confirmed &&
              memory.status == 'open' &&
              const {
                'lent_item',
                'lent_money',
                'promise',
              }.contains(memory.kind),
        )
        .map((memory) {
          final rawDue = memory.dueDateText?.trim();
          final dueDate = resolveDueDate(rawDue, today: today);
          return OpenLoopEntry(
            memory: memory,
            dueDate: dueDate,
            hasDueText: rawDue?.isNotEmpty == true,
            isOverdue: dueDate != null && dueDate.isBefore(today),
          );
        })
        .toList();

    entries.sort((a, b) {
      if (a.dueDate != null && b.dueDate != null) {
        final dueOrder = a.dueDate!.compareTo(b.dueDate!);
        if (dueOrder != 0) return dueOrder;
      } else if (a.dueDate != null) {
        return -1;
      } else if (b.dueDate != null) {
        return 1;
      } else if (a.hasDueText != b.hasDueText) {
        return a.hasDueText ? -1 : 1;
      }
      final createdOrder = b.memory.createdAt.compareTo(a.memory.createdAt);
      return createdOrder != 0
          ? createdOrder
          : a.memory.uid.compareTo(b.memory.uid);
    });

    final totals = <String, double>{};
    final personNames = <String, String>{};
    for (final entry in entries) {
      final memory = entry.memory;
      if (memory.kind != 'lent_money' || memory.amount == null) continue;
      final person = memory.person?.trim();
      final displayName = person == null || person.isEmpty
          ? 'Unknown person'
          : person;
      final key = displayName.toLowerCase();
      personNames.putIfAbsent(key, () => displayName);
      totals.update(
        key,
        (total) => total + memory.amount!,
        ifAbsent: () => memory.amount!,
      );
    }
    final orderedTotals = totals.keys.toList()
      ..sort(
        (a, b) => personNames[a]!.toLowerCase().compareTo(
          personNames[b]!.toLowerCase(),
        ),
      );

    return OpenLoopsData._(
      entries: List.unmodifiable(entries),
      lentMoneyTotals: Map.unmodifiable({
        for (final key in orderedTotals) personNames[key]!: totals[key]!,
      }),
    );
  }

  final List<OpenLoopEntry> entries;
  final Map<String, double> lentMoneyTotals;
}

DateTime? resolveDueDate(String? raw, {required DateTime today}) {
  if (raw == null || raw.trim().isEmpty) return null;
  final value = raw.trim();
  final isoDate = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(value)?.group(0);
  if (isoDate != null) {
    final parsed = DateTime.tryParse(isoDate);
    if (parsed != null) return _dateOnly(parsed);
  }

  final normalized = value.toLowerCase().replaceAll('ñ', 'n');
  final tokens = normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toSet();
  if (tokens.contains('ngayon') || tokens.contains('today')) {
    return _dateOnly(today);
  }
  if (tokens.contains('bukas') || tokens.contains('tomorrow')) {
    return _dateOnly(today).add(const Duration(days: 1));
  }
  if (tokens.contains('kahapon') || tokens.contains('yesterday')) {
    return _dateOnly(today).subtract(const Duration(days: 1));
  }

  const weekdays = <String, int>{
    'lunes': DateTime.monday,
    'monday': DateTime.monday,
    'mon': DateTime.monday,
    'martes': DateTime.tuesday,
    'tuesday': DateTime.tuesday,
    'tue': DateTime.tuesday,
    'miyerkules': DateTime.wednesday,
    'wednesday': DateTime.wednesday,
    'wed': DateTime.wednesday,
    'huwebes': DateTime.thursday,
    'thursday': DateTime.thursday,
    'thu': DateTime.thursday,
    'biyernes': DateTime.friday,
    'friday': DateTime.friday,
    'fri': DateTime.friday,
    'sabado': DateTime.saturday,
    'saturday': DateTime.saturday,
    'sat': DateTime.saturday,
    'linggo': DateTime.sunday,
    'sunday': DateTime.sunday,
    'sun': DateTime.sunday,
  };
  for (final token in tokens) {
    final weekday = weekdays[token];
    if (weekday == null) continue;
    var daysAhead =
        (weekday - today.weekday + DateTime.daysPerWeek) % DateTime.daysPerWeek;
    if (daysAhead == 0 &&
        (tokens.contains('susunod') || tokens.contains('next'))) {
      daysAhead = DateTime.daysPerWeek;
    }
    return _dateOnly(today).add(Duration(days: daysAhead));
  }
  return null;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

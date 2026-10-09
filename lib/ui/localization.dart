import 'package:flutter/material.dart';

import '../core/ui_language.dart';
import 'translations.dart';

class LocalizationScope extends InheritedWidget {
  const LocalizationScope({
    super.key,
    required this.language,
    required super.child,
  });
  final AppLanguage language;
  static AppLanguage of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<LocalizationScope>()
          ?.language ??
      AppLanguage.english;
  @override
  bool updateShouldNotify(LocalizationScope oldWidget) =>
      language != oldWidget.language;
}

/// Only interface strings enter this function. User content uses Text /
/// SelectableText directly, so a memory can never become a translation key.
String tr(BuildContext context, String source) =>
    translate(source, LocalizationScope.of(context));

String recordingError(String source) =>
    translate(source, AppLanguage.tagalog) == source
    ? 'Recording could not finish. Check microphone access, then try again.'
    : source;

String translate(String source, AppLanguage language) {
  final exact = uiTranslations[source];
  if (exact != null) {
    return language == AppLanguage.tagalog ? exact.$2 : exact.$1;
  }
  for (final entry in uiTemplates.entries) {
    final pieces = entry.key.split(RegExp(r'\{\d+\}'));
    final pattern = '^${pieces.map(RegExp.escape).join(r'([\s\S]*?)')}\$';
    final match = RegExp(pattern).firstMatch(source);
    if (match == null) continue;
    var result = language == AppLanguage.tagalog
        ? entry.value.$2
        : entry.value.$1;
    return result.replaceAllMapped(
      RegExp(r'\{(\d+)\}'),
      (token) => match.group(int.parse(token.group(1)!)) ?? '',
    );
  }
  return source; // Catalog keys are English; missing translations stay readable.
}

String uiFormat(BuildContext context, String key, List<String> values) {
  final pair = uiTemplates[key];
  final template = pair == null
      ? key
      : LocalizationScope.of(context) == AppLanguage.tagalog
      ? pair.$2
      : pair.$1;
  return template.replaceAllMapped(
    RegExp(r'\{(\d+)\}'),
    (match) => values[int.parse(match.group(1)!) - 1],
  );
}

class UiText extends StatelessWidget {
  const UiText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  @override
  Widget build(BuildContext context) => Text(
    tr(context, data),
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
  );
}

String kindLabel(BuildContext context, String kind) =>
    tr(context, switch (kind) {
      'lent_item' => 'Lent item',
      'lent_money' => 'Money owed',
      'item_location' => 'Item location',
      'promise' => 'Promise',
      _ => 'Memory',
    });
String statusLabel(BuildContext context, String status) =>
    tr(context, status == 'done' ? 'Done' : 'Open');

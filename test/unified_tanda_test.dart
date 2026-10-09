import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/core/app_database.dart';
import 'package:tanda/core/providers.dart';
import 'package:tanda/core/locality_meter.dart';
import 'package:tanda/core/ui_language.dart';
import 'package:tanda/services/audio/recorder_service.dart';
import 'package:tanda/services/llm/extractor.dart';
import 'package:tanda/services/llm/llm_service.dart';
import 'package:tanda/services/stt/stt_service.dart';
import 'package:tanda/ui/home_shell.dart';
import 'package:tanda/ui/localization.dart';
import 'package:tanda/ui/notebook_theme.dart';
import 'package:tanda/ui/grandma/grandma_avatar.dart';

class Recorder implements AudioCaptureRecorder {
  int starts = 0, stops = 0, cancels = 0;
  @override
  Future<bool> hasPermission({bool request = true}) async => true;
  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<String?> stop() async {
    stops++;
    return 'clip.wav';
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }
}

class Whisper implements SttService {
  String text = 'Sino may hawak ng drill ko?';
  Completer<SttResult>? pending;
  @override
  Future<void> init() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<SttResult> transcribeFile(String path) async => pending == null
      ? SttResult(text: text, elapsedMs: 1, audioMs: 1000)
      : pending!.future;
}

class Llm implements LlmService {
  int calls = 0;
  @override
  Future<void> init() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<LlmResult> complete(
    String prompt, {
    String? grammar,
    int maxTokens = 256,
  }) async {
    calls++;
    return LlmResult(
      text: jsonEncode({
        'understood': true,
        'cleaned_sentence': 'Hiniram ni Jun ang drill.',
        'memory': {
          'kind': 'lent_item',
          'person': 'Jun',
          'item': 'drill',
          'place': null,
          'amount': null,
          'due_date_text': null,
          'evidence': 'Hiniram ni Jun ang drill.',
          'uncertain_fields': [],
        },
      }),
      elapsedMs: 1,
      generatedTokens: 1,
    );
  }
}

Finder actionButton(String action) => find.descendant(
  of: find.byKey(ValueKey(action)),
  matching: find.byType(FilledButton),
);

void main() {
  late AppDatabase db;
  late Recorder recorder;
  late Whisper stt;
  late Llm llm;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    recorder = Recorder();
    stt = Whisper();
    llm = Llm();
  });
  tearDown(() async {
    await db.close();
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          networkStatusProvider.overrideWith(
            (ref) => Stream.value(NetworkStatus.offline),
          ),
          sessionTrafficBytesProvider.overrideWith((ref) => Stream.value(null)),
          recorderServiceProvider.overrideWithValue(recorder),
          sttServiceProvider.overrideWith((ref) async => stt),
          extractorProvider.overrideWith(
            (ref) async => Extractor(
              llm,
              promptTemplate: '{{TRANSCRIPT}}',
              grammar: 'root ::= x',
            ),
          ),
        ],
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> stop(WidgetTester tester, String action) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 330)),
    );
    await tester.tap(actionButton(action));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    'Grandma is 310 pixels on a V30-sized screen and actions stay visible',
    (tester) async {
      await mount(tester);
      tester.view.physicalSize = const Size(480, 1067);
      await tester.pump();
      expect(
        tester.widget<GrandmaAvatar>(find.byType(GrandmaAvatar)).height,
        310,
      );
      expect(actionButton('tell-tanda').hitTestable(), findsOneWidget);
      expect(actionButton('ask-tanda').hitTestable(), findsOneWidget);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pump();
      expect(
        tester.widget<GrandmaAvatar>(find.byType(GrandmaAvatar)).height,
        lessThan(310),
      );
      expect(actionButton('tell-tanda').hitTestable(), findsOneWidget);
      expect(actionButton('ask-tanda').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Ask tap/stop retrieves automatically; never extracts or saves', (
    tester,
  ) async {
    await db.saveConfirmedMemory(
      const ConfirmedMemory(
        uid: 'drill',
        createdAt: '2026',
        updatedAt: '2026',
        kind: 'lent_item',
        person: 'Jun',
        item: 'drill',
        place: null,
        amount: null,
        dueDateText: null,
        transcript: 'Hiniram ni Jun ang drill.',
        evidence: null,
        audioPath: null,
      ),
    );
    await mount(tester);
    expect(find.text('Tell Tanda'), findsOneWidget);
    expect(find.text('Ask Tanda'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(2));
    expect(find.byKey(const ValueKey('grandma-idle')), findsOneWidget);
    stt.pending = Completer<SttResult>();
    await tester.tap(actionButton('ask-tanda'));
    await tester.pump();
    expect(find.text('Stop'), findsOneWidget);
    expect(find.byKey(const ValueKey('grandma-listening')), findsOneWidget);
    await tester.tap(actionButton('tell-tanda'), warnIfMissed: false);
    expect(recorder.starts, 1);
    await stop(tester, 'ask-tanda');
    expect(find.byKey(const ValueKey('grandma-thinking')), findsOneWidget);
    stt.pending!.complete(
      const SttResult(
        text: 'Sino may hawak ng drill ko?',
        elapsedMs: 1,
        audioMs: 1000,
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.text('Jun borrowed drill.'), findsOneWidget);
    expect(find.byKey(const ValueKey('grandma-speaking')), findsOneWidget);
    expect(llm.calls, 0);
    expect(await db.allMemories(), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Tell routes to editable review and only explicit confirmation saves',
    (tester) async {
      stt.text = 'Hiniram ni Jun ang drill.';
      await mount(tester);
      await tester.tap(actionButton('tell-tanda'));
      await tester.pump();
      expect(find.byKey(const ValueKey('grandma-listening')), findsOneWidget);
      await stop(tester, 'tell-tanda');
      expect(llm.calls, 1);
      expect(find.text('Did Tanda hear that right?'), findsOneWidget);
      expect(await db.allMemories(), isEmpty);
      await tester.ensureVisible(find.byKey(const ValueKey('review-edit')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('review-edit')));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('review-transcript-1')),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.ensureVisible(find.text('Yes, save it'));
      await tester.pump();
      await tester.tap(find.text('Yes, save it'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(await db.allMemories(), hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('noise Ask repeats without a review or database write', (
    tester,
  ) async {
    stt.text = '[Buzzing]';
    await mount(tester);
    await tester.tap(actionButton('ask-tanda'));
    await tester.pump();
    await stop(tester, 'ask-tanda');
    expect(
      find.text('I couldn’t understand. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Did Tanda hear that right?'), findsNothing);
    expect(llm.calls, 0);
    expect(await db.allMemories(), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  test('new interface labels have natural Tagalog translations', () {
    expect(
      translate('Tell Tanda', AppLanguage.tagalog),
      'Magkuwento kay Tanda',
    );
    expect(translate('Ask Tanda', AppLanguage.tagalog), 'Magtanong kay Tanda');
    expect(
      translate('Did Tanda hear that right?', AppLanguage.tagalog),
      'Tama ba ang pagkaintindi ni Tanda?',
    );
    expect(translate('Yes, save it', AppLanguage.tagalog), 'Oo, i-save');
  });

  testWidgets(
    'late Ask transcript cannot replace newer typed input or cross into Tell',
    (tester) async {
      stt.pending = Completer<SttResult>();
      await mount(tester);
      await tester.tap(actionButton('ask-tanda'));
      await tester.pump();
      await stop(tester, 'ask-tanda');
      await tester.enterText(
        find.byKey(const ValueKey('tanong-question')),
        'Where is my passport?',
      );
      stt.pending!.complete(
        const SttResult(
          text: 'Sino may hawak ng drill?',
          elapsedMs: 1,
          audioMs: 1000,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('tanong-answer')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('tanong-question')))
            .controller!
            .text,
        'Where is my passport?',
      );
      expect(llm.calls, 0);
      expect(await db.allMemories(), isEmpty);
      await tester.tap(find.byKey(const ValueKey('type-memory')));
      await tester.pump();
      expect(find.byKey(const ValueKey('tala-typed-input')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('leaving Tanda cancels tap recording and does not transcribe', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(actionButton('tell-tanda'));
    await tester.pump();
    await tester.tap(find.text('Open loops'));
    await tester.pump();
    await tester.pump();
    expect(recorder.cancels, 1);
    expect(recorder.stops, 0);
    expect(llm.calls, 0);
    expect(await db.allMemories(), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'small screen and keyboard retain usable controls without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            recorderServiceProvider.overrideWithValue(recorder),
            sttServiceProvider.overrideWith((ref) async => stt),
            networkStatusProvider.overrideWith(
              (ref) => Stream.value(NetworkStatus.offline),
            ),
            sessionTrafficBytesProvider.overrideWith(
              (ref) => Stream.value(null),
            ),
          ],
          child: MaterialApp(
            theme: tandaTheme(),
            home: const LocalizationScope(
              language: AppLanguage.tagalog,
              child: MediaQuery(
                data: MediaQueryData(
                  size: Size(320, 640),
                  viewInsets: EdgeInsets.only(bottom: 270),
                  disableAnimations: true,
                  textScaler: TextScaler.linear(1.2),
                ),
                child: HomeShell(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'character has a static reduced-motion fallback for every state',
    (tester) async {
      for (final state in GrandmaState.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: GrandmaAvatar(state: state),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsOneWidget);
        expect(
          (tester.widget<Image>(find.byType(Image)).image as AssetImage)
              .assetName,
          'assets/grandma/idle_still.png',
        );
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}

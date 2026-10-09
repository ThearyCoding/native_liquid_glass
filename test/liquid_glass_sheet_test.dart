import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

const _presenterChannel = MethodChannel('liquid-glass-presenter');
const _contentChannel = MethodChannel('liquid-glass-sheet-content');

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

/// Pumps an app and returns a context that can show sheets.
Future<BuildContext> _pumpHost(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox.expand();
          },
        ),
      ),
    ),
  );
  return context;
}

/// Records what a handle's `result` completes with, so tests can check it
/// after pumping instead of awaiting under the fake test clock.
class _Outcome<T> {
  bool done = false;
  T? value;
  Object? error;

  _Outcome(LiquidGlassSheetHandle<T> handle) {
    handle.result.then(
      (v) {
        done = true;
        value = v;
      },
      onError: (Object e) {
        done = true;
        error = e;
      },
    );
  }
}

class _SampleSheet extends StatelessWidget {
  const _SampleSheet();

  @override
  Widget build(BuildContext context) {
    final scope = LiquidGlassSheetScope.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('language: ${scope.arguments['language']}'),
        TextButton(
          onPressed: () => scope.dismiss('Khmer'),
          child: const Text('pick'),
        ),
      ],
    );
  }
}

final _builders = <String, LiquidGlassSheetBuilder>{
  'sample': (context, arguments) => const _SampleSheet(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('native sheet (iOS 15+)', () {
    late List<MethodCall> calls;
    late Completer<Object?> nativeResult;

    setUp(() {
      NativeLiquidGlassUtils.debugSupportsNativeSheetOverride = true;
      calls = [];
      _messenger.setMockMethodCallHandler(_presenterChannel, (call) {
        calls.add(call);
        // Created here, inside the test's fake-async zone; a completer made
        // in setUp never delivers its value under the fake clock.
        if (call.method == 'showSheet') {
          nativeResult = Completer<Object?>();
          return nativeResult.future;
        }
        return Future.value();
      });
    });

    tearDown(() {
      NativeLiquidGlassUtils.debugSupportsNativeSheetOverride = null;
      _messenger.setMockMethodCallHandler(_presenterChannel, null);
    });

    testWidgets('sends default arguments to native', (tester) async {
      final context = await _pumpHost(tester);

      LiquidGlassSheet.show<String>(
        context: context,
        name: 'sample',
        arguments: {'language': 'English', 'count': 2},
      );
      await tester.pump();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'showSheet');
      final args = calls.single.arguments as Map;
      expect(args['id'], isA<int>());
      expect(args['name'], 'sample');
      expect(jsonDecode(args['arguments'] as String), {
        'language': 'English',
        'count': 2,
      });
      expect(args['entrypoint'], 'bottomSheetMain');
      expect(args['libraryUri'], isNull);
      expect(args['detents'], [
        {'type': 'medium', 'value': null},
        {'type': 'large', 'value': null},
      ]);
      expect(args['prefersGrabberVisible'], isTrue);
      expect(args['isModal'], isFalse);
      expect(args['cornerRadius'], isNull);
    });

    testWidgets('sends custom options to native', (tester) async {
      final context = await _pumpHost(tester);

      LiquidGlassSheet.show<void>(
        context: context,
        name: 'sample',
        detents: const [
          LiquidGlassSheetDetent.height(320),
          LiquidGlassSheetDetent.fraction(0.4),
        ],
        prefersGrabberVisible: false,
        isModal: true,
        cornerRadius: 24,
        entrypoint: 'customSheetMain',
        libraryUri: 'package:my_app/sheets.dart',
      );
      await tester.pump();

      final args = calls.single.arguments as Map;
      expect(args['arguments'], '{}');
      expect(args['detents'], [
        {'type': 'height', 'value': 320.0},
        {'type': 'fraction', 'value': 0.4},
      ]);
      expect(args['prefersGrabberVisible'], isFalse);
      expect(args['isModal'], isTrue);
      expect(args['cornerRadius'], 24.0);
      expect(args['entrypoint'], 'customSheetMain');
      expect(args['libraryUri'], 'package:my_app/sheets.dart');
    });

    testWidgets('each sheet gets a new id', (tester) async {
      final context = await _pumpHost(tester);

      LiquidGlassSheet.show<void>(context: context, name: 'a');
      LiquidGlassSheet.show<void>(context: context, name: 'b');
      await tester.pump();

      final first = (calls[0].arguments as Map)['id'] as int;
      final second = (calls[1].arguments as Map)['id'] as int;
      expect(second, first + 1);
    });

    testWidgets('result completes with the value native returns', (
      tester,
    ) async {
      final context = await _pumpHost(tester);

      final handle = LiquidGlassSheet.show<String>(
        context: context,
        name: 'sample',
      );
      final outcome = _Outcome(handle);
      await tester.pump();
      expect(handle.isShowing, isTrue);

      nativeResult.complete('Khmer');
      await tester.pump();

      expect(outcome.value, 'Khmer');
      expect(handle.isShowing, isFalse);
    });

    testWidgets('swipe dismissal completes result with null', (tester) async {
      final context = await _pumpHost(tester);

      final handle = LiquidGlassSheet.show<String>(
        context: context,
        name: 'sample',
      );
      final outcome = _Outcome(handle);
      await tester.pump();

      nativeResult.complete(null);
      await tester.pump();

      expect(outcome.done, isTrue);
      expect(outcome.value, isNull);
      expect(handle.isShowing, isFalse);
    });

    testWidgets('native error completes result with an error', (tester) async {
      final context = await _pumpHost(tester);

      final handle = LiquidGlassSheet.show<String>(
        context: context,
        name: 'sample',
      );
      final outcome = _Outcome(handle);
      await tester.pump();

      nativeResult.completeError(PlatformException(code: 'NO_HOST'));
      await tester.pump();

      expect(outcome.error, isA<PlatformException>());
    });

    testWidgets('prewarm asks native to start a spare engine', (tester) async {
      await LiquidGlassSheet.prewarm(libraryUri: 'package:app/sheets.dart');

      expect(calls.single.method, 'prewarmSheet');
      expect(calls.single.arguments, {
        'entrypoint': 'bottomSheetMain',
        'libraryUri': 'package:app/sheets.dart',
      });
    });

    testWidgets('dismiss sends id and value to native', (tester) async {
      final context = await _pumpHost(tester);

      final handle = LiquidGlassSheet.show<String>(
        context: context,
        name: 'sample',
      );
      await tester.pump();
      final id = (calls.single.arguments as Map)['id'];

      await handle.dismiss('French');

      expect(calls.last.method, 'dismissSheet');
      expect(calls.last.arguments, {'id': id, 'result': 'French'});
    });

    testWidgets('dismiss after the sheet closed does nothing', (tester) async {
      final context = await _pumpHost(tester);

      final handle = LiquidGlassSheet.show<String>(
        context: context,
        name: 'sample',
      );
      await tester.pump();
      nativeResult.complete(null);
      await tester.pump();
      expect(handle.isShowing, isFalse);

      await handle.dismiss('late');

      expect(calls.map((c) => c.method), ['showSheet']);
    });
  });

  group('fallback sheet (no native sheet)', () {
    setUpAll(() => LiquidGlassSheet.registerBuilders(_builders));

    setUp(() {
      NativeLiquidGlassUtils.debugSupportsNativeSheetOverride = false;
    });

    tearDown(() {
      NativeLiquidGlassUtils.debugSupportsNativeSheetOverride = null;
    });

    testWidgets('does not call native', (tester) async {
      final calls = <MethodCall>[];
      _messenger.setMockMethodCallHandler(_presenterChannel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(
        () => _messenger.setMockMethodCallHandler(_presenterChannel, null),
      );
      final context = await _pumpHost(tester);

      LiquidGlassSheet.show<String>(context: context, name: 'sample');
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
    });

    testWidgets('prewarm does nothing without native sheets', (tester) async {
      final calls = <MethodCall>[];
      _messenger.setMockMethodCallHandler(_presenterChannel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(
        () => _messenger.setMockMethodCallHandler(_presenterChannel, null),
      );

      await LiquidGlassSheet.prewarm();

      expect(calls, isEmpty);
    });

    testWidgets('renders the registered builder with arguments', (
      tester,
    ) async {
      final context = await _pumpHost(tester);

      LiquidGlassSheet.show<String>(
        context: context,
        name: 'sample',
        arguments: {'language': 'English'},
      );
      await tester.pumpAndSettle();

      expect(find.text('language: English'), findsOneWidget);
    });

    testWidgets('scope.dismiss closes the sheet and returns the value', (
      tester,
    ) async {
      final context = await _pumpHost(tester);

      final handle = LiquidGlassSheet.show<String>(
        context: context,
        name: 'sample',
      );
      await tester.pumpAndSettle();

      final outcome = _Outcome(handle);

      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();

      expect(find.byType(_SampleSheet), findsNothing);
      expect(outcome.value, 'Khmer');
      expect(handle.isShowing, isFalse);
    });

    testWidgets('handle.dismiss closes the sheet with the value', (
      tester,
    ) async {
      final context = await _pumpHost(tester);

      final handle = LiquidGlassSheet.show<String>(
        context: context,
        name: 'sample',
      );
      await tester.pumpAndSettle();

      final outcome = _Outcome(handle);

      await handle.dismiss('Spanish');
      await tester.pumpAndSettle();

      expect(find.byType(_SampleSheet), findsNothing);
      expect(outcome.value, 'Spanish');
    });

    testWidgets('tapping the barrier dismisses with null', (tester) async {
      final context = await _pumpHost(tester);

      final handle = LiquidGlassSheet.show<String>(
        context: context,
        name: 'sample',
      );
      await tester.pumpAndSettle();

      final outcome = _Outcome(handle);

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.byType(_SampleSheet), findsNothing);
      expect(outcome.done, isTrue);
      expect(outcome.value, isNull);
    });

    testWidgets('modal sheet ignores barrier taps', (tester) async {
      final context = await _pumpHost(tester);

      final handle = LiquidGlassSheet.show<String>(
        context: context,
        name: 'sample',
        isModal: true,
      );
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.byType(_SampleSheet), findsOneWidget);
      expect(handle.isShowing, isTrue);
    });

    testWidgets('unknown name shows a placeholder', (tester) async {
      final context = await _pumpHost(tester);

      LiquidGlassSheet.show<void>(context: context, name: 'missing');
      await tester.pumpAndSettle();

      expect(
        find.text('No bottom sheet registered for "missing"'),
        findsOneWidget,
      );
    });
  });

  group('LiquidGlassSheetScope', () {
    testWidgets('maybeOf is null outside a sheet', (tester) async {
      LiquidGlassSheetScope? scope;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            scope = LiquidGlassSheetScope.maybeOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(scope, isNull);
    });

    testWidgets('of asserts outside a sheet', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            LiquidGlassSheetScope.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(tester.takeException(), isA<AssertionError>());
    });

    testWidgets('dismiss forwards the value', (tester) async {
      Object? dismissed;
      await tester.pumpWidget(
        MaterialApp(
          home: LiquidGlassSheetScope(
            arguments: const {'language': 'English'},
            onDismiss: (value) => dismissed = value,
            child: const Material(child: _SampleSheet()),
          ),
        ),
      );

      await tester.tap(find.text('pick'));
      expect(dismissed, 'Khmer');
    });
  });

  group('runLiquidGlassSheet (sheet engine entry point)', () {
    late List<MethodCall> contentCalls;

    setUp(() {
      contentCalls = [];
      _messenger.setMockMethodCallHandler(_contentChannel, (call) async {
        contentCalls.add(call);
        return null;
      });
    });

    tearDown(() {
      _messenger.setMockMethodCallHandler(_contentChannel, null);
    });

    testWidgets('renders the builder named in args with decoded arguments', (
      tester,
    ) async {
      runLiquidGlassSheet([
        '0',
        'sample',
        jsonEncode({'language': 'English'}),
      ], builders: _builders);
      await tester.pump();

      expect(find.text('language: English'), findsOneWidget);
    });

    testWidgets('prewarmed engine waits for configure, then shows the sheet', (
      tester,
    ) async {
      runLiquidGlassSheet(['__liquid_glass_prewarm__'], builders: _builders);
      await tester.pump();
      expect(find.byType(_SampleSheet), findsNothing);
      expect(contentCalls.map((c) => c.method), ['warm']);

      await _messenger.handlePlatformMessage(
        _contentChannel.name,
        _contentChannel.codec.encodeMethodCall(
          MethodCall('configure', {
            'id': 4,
            'name': 'sample',
            'arguments': jsonEncode({'language': 'Khmer'}),
          }),
        ),
        (_) {},
      );
      await tester.pump();

      expect(find.text('language: Khmer'), findsOneWidget);
      expect(contentCalls.map((c) => c.method), ['warm', 'ready']);
    });

    testWidgets('reports ready once the widget tree is attached', (
      tester,
    ) async {
      runLiquidGlassSheet(['0', 'sample', '{}'], builders: _builders);
      await tester.pump();

      expect(contentCalls.map((c) => c.method), ['ready']);
      expect(find.byType(_SampleSheet), findsOneWidget);
    });

    testWidgets('dismiss sends the value over the content channel', (
      tester,
    ) async {
      runLiquidGlassSheet(['3', 'sample', '{}'], builders: _builders);
      await tester.pump();

      await tester.tap(find.text('pick'));
      await tester.pump();

      expect(contentCalls.map((c) => c.method), ['ready', 'dismiss']);
      expect(contentCalls.last.arguments, {'result': 'Khmer'});
    });

    testWidgets('missing arguments default to an empty map', (tester) async {
      runLiquidGlassSheet(['0', 'sample'], builders: _builders);
      await tester.pump();

      expect(find.text('language: null'), findsOneWidget);
    });

    testWidgets('unknown name shows a placeholder', (tester) async {
      runLiquidGlassSheet(['0', 'missing', '{}'], builders: _builders);
      await tester.pump();

      expect(
        find.text('No bottom sheet registered for "missing"'),
        findsOneWidget,
      );
    });

    testWidgets('uses a transparent background so the native sheet shows', (
      tester,
    ) async {
      runLiquidGlassSheet(['0', 'sample', '{}'], builders: _builders);
      await tester.pump();

      final context = tester.element(find.byType(_SampleSheet));
      final theme = Theme.of(context);
      expect(theme.scaffoldBackgroundColor, Colors.transparent);
      expect(theme.canvasColor, Colors.transparent);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.color, Colors.transparent);
    });

    testWidgets('applies a custom theme', (tester) async {
      runLiquidGlassSheet(
        ['0', 'sample', '{}'],
        builders: _builders,
        theme: ThemeData(primaryColor: Colors.purple),
      );
      await tester.pump();

      final context = tester.element(find.byType(_SampleSheet));
      expect(Theme.of(context).primaryColor, Colors.purple);
    });
  });
}

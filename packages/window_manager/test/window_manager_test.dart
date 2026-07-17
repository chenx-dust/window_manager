import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

class _RecordingListener with WindowListener {
  final List<String> events = <String>[];

  @override
  void onWindowEvent(String eventName) => events.add('event:$eventName');

  @override
  void onWindowShouldTerminate() => events.add('shouldTerminate');
}

void main() {
  const MethodChannel channel = MethodChannel('window_manager');
  const StandardMethodCodec codec = StandardMethodCodec();

  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  Future<void> emitEvent(String eventName) {
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          codec.encodeMethodCall(
            MethodCall('onEvent', <String, dynamic>{'eventName': eventName}),
          ),
          (_) {},
        );
  }

  setUp(() {
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          calls.add(methodCall);
          if (methodCall.method == 'isMinimized' ||
              methodCall.method == 'isPositionSupported') {
            return false;
          }
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('focus forwards a Linux activation timestamp', () async {
    await windowManager.focus(activationTimestamp: 1234);

    expect(calls.single.method, 'focus');
    expect(calls.single.arguments, {'activationTimestamp': 1234});
  });

  test('show forwards a Linux activation timestamp', () async {
    await windowManager.show(activationTimestamp: 1234);

    expect(calls.map((call) => call.method), ['isMinimized', 'show']);
    expect(calls.last.arguments, {
      'inactive': false,
      'activationTimestamp': 1234,
    });
  });

  test('restore forwards a Linux activation timestamp', () async {
    await windowManager.restore(activationTimestamp: 1234);

    expect(calls.single.method, 'restore');
    expect(calls.single.arguments, {'activationTimestamp': 1234});
  });

  test('setWindowCornerPreference passes the requested rounding', () async {
    await windowManager.setWindowCornerPreference(round: true);
    await windowManager.setWindowCornerPreference(round: false);

    expect(
      calls.map((call) => call.method),
      everyElement('setWindowCornerPreference'),
    );
    expect(calls.map((call) => (call.arguments as Map)['round']), <bool>[
      true,
      false,
    ]);
  });

  test('the terminate event reaches a listener', () async {
    final listener = _RecordingListener();
    windowManager.addListener(listener);
    addTearDown(() => windowManager.removeListener(listener));

    await emitEvent(kWindowEventShouldTerminate);

    expect(listener.events, <String>[
      'event:$kWindowEventShouldTerminate',
      'shouldTerminate',
    ]);
  });

  test('isPositionSupported queries the platform capability', () async {
    expect(await windowManager.isPositionSupported(), isFalse);

    expect(calls.map((call) => call.method), <String>['isPositionSupported']);
  });
}

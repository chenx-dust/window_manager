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
  bool isMinimized = false;

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
    isMinimized = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          calls.add(methodCall);
          if (methodCall.method == 'isMinimized') {
            return isMinimized;
          }
          if (methodCall.method == 'isPositionSupported') {
            return false;
          }
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('focus forwards Linux activation details', () async {
    await windowManager.focus(
      activationTimestamp: 1234,
      activationToken: 'activation-token',
    );

    expect(calls.single.method, 'focus');
    expect(calls.single.arguments, {
      'activationTimestamp': 1234,
      'activationToken': 'activation-token',
    });
  });

  test('show forwards Linux activation details', () async {
    await windowManager.show(
      activationTimestamp: 1234,
      activationToken: 'activation-token',
    );

    expect(calls.map((call) => call.method), ['isMinimized', 'show']);
    expect(calls.last.arguments, {
      'inactive': false,
      'activationTimestamp': 1234,
      'activationToken': 'activation-token',
    });
  });

  test('show consumes a Wayland activation token only once', () async {
    isMinimized = true;

    await windowManager.show(activationToken: 'activation-token');

    expect(calls.map((call) => call.method), [
      'isMinimized',
      'restore',
      'show',
    ]);
    expect(calls[1].arguments, {'activationToken': 'activation-token'});
    expect(calls[2].arguments, {'inactive': false});
  });

  test('restore forwards Linux activation details', () async {
    await windowManager.restore(
      activationTimestamp: 1234,
      activationToken: 'activation-token',
    );

    expect(calls.single.method, 'restore');
    expect(calls.single.arguments, {
      'activationTimestamp': 1234,
      'activationToken': 'activation-token',
    });
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

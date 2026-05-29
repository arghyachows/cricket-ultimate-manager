# Flutter Riverpod Documentation

This document contains key concepts and implementation guides for Riverpod v3, specifically tailored for the state management in the **Cricket Ultimate Manager** application.

---

## 1. Basic Setup

To enable Riverpod, wrap the root widget in a `ProviderScope`:

```dart
void main() {
  runApp(
    // Enable Riverpod for the entire application
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

---

## 2. ConsumerWidget

`ConsumerWidget` is the reactive equivalent of `StatelessWidget`. It allows the widget tree to listen to providers and rebuild when state changes.

### Single Provider Example
```dart
final helloWorldProvider = Provider((_) => 'Hello world');

class Example extends ConsumerWidget {
  const Example({Key? key}): super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider for changes
    final value = ref.watch(helloWorldProvider);
    return Text(value); // Renders: Hello world
  }
}
```

### Multiple Providers Example
You can watch multiple providers in the same build method:
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final value = ref.watch(someProvider);
  final another = ref.watch(anotherProvider);
  return Text('$value $another');
}
```

---

## 3. StreamProvider (Highly Recommended for WebSockets)

`StreamProvider` is ideal for handling continuous streams of data, such as real-time socket connections.

### Setup and Auto-Dispose
Always use `.autoDispose` to ensure that socket connections are closed and resources are released when the UI stops watching them.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final messageProvider = StreamProvider.autoDispose<String>((ref) async* {
  // Connect to the WebSocket server
  final channel = WebSocketChannel.connect(Uri.parse('ws://localhost:3000'));

  // Ensure connection is closed when the provider is disposed/unwatched
  ref.onDispose(() => channel.sink.close());

  // Listen and yield incoming values
  await for (final value in channel.stream) {
    yield value.toString();
  }
});
```

### UI Consumption
```dart
Widget build(BuildContext context, WidgetRef ref) {
  final AsyncValue<String> message = ref.watch(messageProvider);

  return message.when(
    loading: () => const CircularProgressIndicator(),
    error: (err, stack) => Text('Error: $err'),
    data: (data) => Text('Received: $data'),
  );
}
```

---

## 4. StateNotifierProvider (Legacy / Action-oriented state)

Used to manage complex states that can change in response to user actions (like modifying a list, collection, or user points).

```dart
class TodosNotifier extends StateNotifier<List<Todo>> {
  TodosNotifier(): super([]);

  void add(Todo todo) {
    state = [...state, todo];
  }

  void remove(String todoId) {
    state = [
      for (final todo in state)
        if (todo.id != todoId) todo,
    ];
  }

  void toggle(String todoId) {
    state = [
      for (final todo in state)
        if (todo.id == todoId) todo.copyWith(completed: !todo.completed),
    ];
  }
}

// Defining the provider
final todosProvider = StateNotifierProvider<TodosNotifier, List<Todo>>((ref) => TodosNotifier());
```

---

## 5. FutureProvider

Useful for performing asynchronous actions (like a one-off HTTP request or fetching initial configuration).

```dart
final configProvider = FutureProvider<Configuration>((ref) async {
  final content = json.decode(
    await rootBundle.loadString('assets/configurations.json'),
  ) as Map<String, Object?>;

  return Configuration.fromJson(content);
});

// UI Integration
Widget build(BuildContext context, WidgetRef ref) {
  AsyncValue<Configuration> config = ref.watch(configProvider);

  return config.when(
    loading: () => const CircularProgressIndicator(),
    error: (err, stack) => Text('Error: $err'),
    data: (config) => Text('Backend host: ${config.host}'),
  );
}
```

---

## 6. Important Guidelines & Life-cycle Methods

### Listening to Providers Imperatively (`ref.listen`)
To show dialogs, snackbars, or navigate based on state changes, call `ref.listen` at the root of your `build` method:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  ref.listen<AsyncValue<String>>(someProvider, (previous, next) {
    if (next.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${next.error}')),
      );
    }
  });

  return const Text('State Listener Active');
}
```

### Resource Cleanup with `onDispose`
Clean up listeners, controllers, or HTTP clients individually:

```dart
final disposable1 = Disposable();
ref.onDispose(disposable1.dispose);

final disposable2 = Disposable();
ref.onDispose(disposable2.dispose);
```

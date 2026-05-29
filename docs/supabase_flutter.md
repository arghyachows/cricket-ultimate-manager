# Supabase Flutter SDK Documentation

This guide covers common integrations for the **Supabase Flutter** client in the frontend.

---

## 1. Authentication

### Sign Up with Email and Password
```dart
final AuthResponse res = await supabase.auth.signUp(
  email: 'example@email.com',
  password: 'example-password',
);
final Session? session = res.session;
final User? user = res.user;
```

### Sign In with Email and Password
```dart
final AuthResponse res = await supabase.auth.signInWithPassword(
  email: 'example@email.com',
  password: 'example-password',
);
```

### Sign Out
```dart
await supabase.auth.signOut();
```

---

## 2. Database Queries

### Simple Select and Range Filters
```dart
// Fetch name column and limit to first two elements (indices 0 and 1)
final List<Map<String, dynamic>> data = await supabase
  .from('instruments')
  .select('name')
  .range(0, 1);
```

### Conditional Filter Examples
```dart
// Filter: NOT null
final data = await supabase
  .from('countries')
  .select()
  .not('name', 'is', null);

// Filter: OR condition
final data = await supabase
  .from('instruments')
  .select('name')
  .or('id.eq.2,name.eq.cello');

// Generic raw filter
final data = await supabase
  .from('characters')
  .select()
  .filter('name', 'in', '("Ron","Dumbledore")');
```

### Fetching Postgres Execution Plan (EXPLAIN)
Useful for debugging slow database queries:
```dart
final String plan = await supabase
  .from('instruments')
  .select()
  .explain(analyze: true, verbose: true);

print(plan);
```

---

## 3. Realtime Database Subscriptions

To listen to real-time database changes (e.g. scorecard updates):
```dart
final subscription = supabase
  .from('matches')
  .stream(primaryKey: ['id'])
  .listen((List<Map<String, dynamic>> data) {
    // Process real-time match records
    print('Match data changed: $data');
  });

// Cancel when no longer needed
ref.onDispose(() => subscription.cancel());
```

---

## 4. Storage Bucket Operations

### Get Bucket details
```dart
// Note: Handled on storage server endpoint
final bucket = await supabase.storage.getBucket('my-bucket');
print(bucket.id);
```

### Upload a file
```dart
final File file = File('path/to/local/image.png');
await supabase.storage.from('avatars').upload(
  'public/avatar1.png',
  file,
);
```

### Download a file
```dart
final Uint8List fileBytes = await supabase.storage
  .from('avatars')
  .download('public/avatar1.png');
```

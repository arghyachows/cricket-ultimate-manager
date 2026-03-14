# Profanity Filter - PurgoMalum Implementation

## Overview
The app uses **PurgoMalum API** for profanity filtering - a free, unlimited, no-API-key-required service.

## Features
- ✅ Free & Unlimited requests
- ✅ No API key required
- ✅ Comprehensive profanity detection
- ✅ Automatic caching (up to 1000 results)
- ✅ 5-second timeout with graceful fallback
- ✅ Multiple validation methods

## Usage

### Check for Profanity
```dart
final hasProfanity = await ProfanityFilter.containsProfanity('your text');
// Returns: true or false
```

### Clean Text
```dart
// Replace with asterisks
final cleaned = await ProfanityFilter.cleanText('bad word here');
// Returns: "*** **** here"

// Custom replacement
final cleaned = await ProfanityFilter.cleanTextWithReplacement(
  'bad word here',
  '[censored]'
);
// Returns: "[censored] [censored] here"
```

### Validation Methods
```dart
// Username
final error = await ProfanityFilter.validateUsername('username');

// Team name
final error = await ProfanityFilter.validateTeamName('team name');

// Display name
final error = await ProfanityFilter.validateDisplayName('display name');

// Generic text
final error = await ProfanityFilter.validateText(
  'text',
  fieldName: 'Message',
  minLength: 1,
  maxLength: 200,
);
```

### Form Validators (Synchronous)
For TextFormField validators that need synchronous checks:
```dart
TextFormField(
  validator: ProfanityFilter.validateUsernameSync,
  // or
  validator: ProfanityFilter.validateTeamNameSync,
)
```

**Note:** Sync validators only check format/length. Always call the async version on submit for profanity check.

## Implementation Pattern

### Two-Step Validation
```dart
// Step 1: Form validation (instant, basic checks)
TextFormField(
  validator: ProfanityFilter.validateUsernameSync,
)

// Step 2: Submit validation (API check)
onPressed: () async {
  final error = await ProfanityFilter.validateUsername(username);
  if (error != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
    return;
  }
  // Proceed
}
```

## Caching
- Automatically caches up to 1000 results
- Repeated checks return instantly from cache
- Clear cache: `ProfanityFilter.clearCache()`

## Performance
- **API Response**: ~100-300ms
- **Cached Response**: <1ms
- **Timeout**: 5 seconds (returns false on timeout)

## PurgoMalum API
- **Website**: https://www.purgomalum.com/
- **Rate Limit**: None
- **Cost**: Free
- **API Key**: Not required

## Testing
```dart
// Test profanity check
final result = await ProfanityFilter.containsProfanity('hello world');
print(result); // false

// Test cleaning
final cleaned = await ProfanityFilter.cleanText('bad word');
print(cleaned); // "*** ****"
```

## Installation
The `http` package is already added to `pubspec.yaml`. Just run:
```bash
flutter pub get
```

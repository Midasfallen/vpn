# UX Improvements Implementation Guide

## Overview

This guide demonstrates how to integrate loading states, error handling, and refresh mechanisms into the VPN app for improved user experience.

## Components Created

### 1. LoadingWidget (`lib/widgets/loading_widget.dart`)

**Purpose**: Reusable loading indicators for different UI contexts

**Available Methods:**
```dart
LoadingWidget.fullScreen(message: 'Connecting to VPN...');
LoadingWidget.circular(size: 32);
LoadingWidget.linear(value: 0.5);
LoadingWidget.shimmer(width: 200, height: 20);
```

**Example Usage in Widget:**
```dart
if (isLoading) {
  return LoadingWidget.fullScreen(message: 'Loading subscription...');
}
```

### 2. ErrorWidget (`lib/widgets/error_widget.dart`)

**Purpose**: User-friendly error displays with retry options

**Available Widgets:**
```dart
ErrorWidget(
  message: 'Failed to connect',
  details: 'Check your connection and try again',
  onRetry: () { /* retry logic */ },
  icon: Icons.error_outline,
)

NetworkErrorWidget(onRetry: () { /* ... */ })
ServerErrorWidget(statusCode: '500', onRetry: () { /* ... */ })
TimeoutErrorWidget(onRetry: () { /* ... */ })
```

**Example Usage:**
```dart
if (errorMessage != null) {
  return ErrorWidget(
    message: errorMessage!,
    onRetry: _loadData,
  );
}
```

### 3. RefreshStateMixin (`lib/mixins/refresh_state_mixin.dart`)

**Purpose**: Manage async loading, refresh, and error states in StatefulWidget

**Methods:**
- `setLoading(bool)` — Set loading state
- `setError(String?)` — Set error message
- `clearError()` — Clear error
- `setLoaded()` — Mark as successfully loaded
- `executeWithErrorHandling(Future)` — Execute async operation with error handling
- `handleRefresh(Future)` — Handle pull-to-refresh

**Properties:**
- `isLoading` — Is data currently loading
- `errorMessage` — Current error message (null if no error)
- `isRefreshing` — Is user actively pulling to refresh
- `lastLoadTime` — When data was last successfully loaded
- `failureCount` — Number of consecutive failures

## Integration Examples

### Home Screen with Loading States

```dart
class HomeScreenState extends State<HomeScreen> with RefreshStateMixin {
  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    await executeWithErrorHandling(() async {
      final subscription = await vpnService.getActiveSubscription();
      setState(() {
        _subscription = subscription;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading
    if (isLoading) {
      return Scaffold(
        body: LoadingWidget.fullScreen(
          message: 'Loading subscription...',
        ),
      );
    }

    // Show error
    if (errorMessage != null) {
      return Scaffold(
        body: ErrorWidget(
          message: 'Failed to load subscription',
          details: errorMessage,
          onRetry: _loadSubscription,
        ),
      );
    }

    // Show content
    return Scaffold(
      body: _buildSubscriptionCard(),
    );
  }
}
```

### Subscription Screen with Pull-to-Refresh

```dart
class SubscriptionScreenState extends State<SubscriptionScreen> with RefreshStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => handleRefresh(() async {
          final tariffs = await vpnService.getTariffs();
          setState(() {
            _tariffs = tariffs;
          });
        }),
        child: isLoading
            ? LoadingWidget.fullScreen(message: 'Loading tariffs...')
            : errorMessage != null
                ? ErrorWidget(
                    message: 'Failed to load tariffs',
                    onRetry: () => executeWithErrorHandling(/* ... */),
                  )
                : _buildTariffList(),
      ),
    );
  }
}
```

### Skeleton Loader While Loading

```dart
if (isLoading && _tariffs.isEmpty) {
  return Column(
    children: List.generate(3, (i) => [
      LoadingWidget.shimmer(width: double.infinity, height: 80),
      SizedBox(height: 16),
    ]).expand((e) => e).toList(),
  );
}
```

## Error Handling Patterns

### Network Error Recovery

```dart
Future<void> _connectVpn(int peerId) async {
  await executeWithErrorHandling(() async {
    final config = await vpnService.fetchWgQuick(peerId);
    final success = await vpnManager.connect(peerId);
    
    if (!success) {
      throw Exception('VPN connection failed');
    }
  }).catchError((e) {
    // Handle specific error types
    if (e is TimeoutException) {
      setError('Connection timeout. Check your network.');
    } else if (e is SocketException) {
      setError('Network error. Check your connection.');
    } else {
      setError('Failed to connect: $e');
    }
  });
}
```

### Form Validation with Error Display

```dart
Column(
  children: [
    TextField(
      onChanged: (value) {
        // Clear field-specific error when user edits
        if (_fieldErrors.containsKey('email')) {
          setState(() => _fieldErrors.remove('email'));
        }
      },
    ),
    if (_fieldErrors.containsKey('email'))
      ErrorMessage(_fieldErrors['email']!),
  ],
)
```

## State Management Helpers

### Auto-Retry on Transient Failures

```dart
// RefreshStateMixin automatically retries up to 3 times
// Configure in mixin:
static const int maxRetries = 3;

// Check if should retry
if (shouldAutoRetry()) {
  // Automatically retry failed operations
  await Future.delayed(Duration(milliseconds: 500));
  await executeWithErrorHandling(operation);
}
```

### Check Data Freshness

```dart
// Check if data is stale
if (isDataStale(threshold: Duration(minutes: 5))) {
  // Data older than 5 minutes, should reload
  _loadData();
}

// Get time since last load
final timeSince = getTimeSinceLastLoad();
print('Data loaded ${timeSince?.inSeconds} seconds ago');
```

## Best Practices

✅ **DO**:
- Use `executeWithErrorHandling()` for all async operations
- Show loading indicator during data fetch
- Display user-friendly error messages (use i18n)
- Provide "Retry" button on errors
- Auto-retry transient failures (network timeouts)
- Use skeleton loaders while loading
- Clear errors when user retries

❌ **DON'T**:
- Show raw exception messages to users
- Leave users without feedback during loading
- Retry on permanent errors (401, 404, 422)
- Block UI while loading (use async/await)
- Ignore network state changes
- Mix exception handling with UI setState

## Testing Error Handling

```dart
test('shows error widget when loading fails', () async {
  // Arrange
  when(mockService.getData()).thenThrow(Exception('API error'));

  // Act
  await tester.pumpWidget(MyScreen());
  await tester.pumpAndSettle();

  // Assert
  expect(find.byType(ErrorWidget), findsOneWidget);
  expect(find.text('Failed to load data'), findsOneWidget);
});

test('retry button calls loadData again', () async {
  // Arrange
  int callCount = 0;
  when(mockService.getData()).thenAnswer((_) async {
    callCount++;
    if (callCount < 2) throw Exception('Error');
    return {'data': 'success'};
  });

  // Act
  final state = _ScreenState();
  await state.executeWithErrorHandling(() => mockService.getData());
  
  // Verify first call failed
  expect(state.errorMessage, isNotNull);
  
  // Tap retry
  await state.executeWithErrorHandling(() => mockService.getData());
  
  // Assert second call succeeded
  expect(state.errorMessage, isNull);
  expect(callCount, 2);
});
```

## Integration Roadmap

**Phase 1** (Completed):
✅ Create LoadingWidget and ErrorWidget components
✅ Create RefreshStateMixin for state management
✅ Create documentation and examples

**Phase 2** (Next):
- [ ] Integrate into HomeScreen (_loadSubscriptionStatus)
- [ ] Integrate into SubscriptionScreen (_loadTariffs)
- [ ] Add RefreshIndicator to both screens
- [ ] Add skeleton loaders during initial load

**Phase 3** (Testing):
- [ ] Unit tests for RefreshStateMixin
- [ ] Widget tests for error states
- [ ] Integration tests for retry flows

## References

- [Flutter Loading Pattern](https://flutter.dev/docs/development/ui/progress-indicators)
- [Error Handling Best Practices](https://dart.dev/guides/language/language-tour#exceptions)
- [State Management in Flutter](https://flutter.dev/docs/development/data-and-backend/state-mgmt)

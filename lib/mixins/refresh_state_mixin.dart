import 'package:flutter/material.dart';

/// Mixin for managing async data loading, refresh, and error states
mixin RefreshStateMixin<T extends StatefulWidget> on State<T> {
  /// Data loading state
  bool isLoading = false;
  
  /// Error message (null = no error)
  String? errorMessage;
  
  /// Whether user initiated a pull-to-refresh
  bool isRefreshing = false;
  
  /// Timestamp of last successful load
  DateTime? lastLoadTime;
  
  /// Number of consecutive failures
  int failureCount = 0;
  
  /// Max retries before giving up
  static const int maxRetries = 3;

  /// Start loading data
  void setLoading(bool value) {
    setState(() {
      isLoading = value;
    });
  }

  /// Set error message
  void setError(String? error) {
    setState(() {
      errorMessage = error;
      if (error != null) {
        failureCount++;
      }
    });
  }

  /// Clear error message
  void clearError() {
    setState(() {
      errorMessage = null;
    });
  }

  /// Mark data as loaded successfully
  void setLoaded() {
    setState(() {
      isLoading = false;
      isRefreshing = false;
      lastLoadTime = DateTime.now();
      failureCount = 0;
    });
  }

  /// Check if should auto-retry
  bool shouldAutoRetry() {
    return failureCount < maxRetries && errorMessage != null;
  }

  /// Get time since last successful load
  Duration? getTimeSinceLastLoad() {
    if (lastLoadTime == null) return null;
    return DateTime.now().difference(lastLoadTime!);
  }

  /// Check if data is stale (older than threshold)
  bool isDataStale({Duration threshold = const Duration(minutes: 5)}) {
    final timeSince = getTimeSinceLastLoad();
    if (timeSince == null) return true;
    return timeSince.compareTo(threshold) > 0;
  }

  /// Execute async operation with error handling
  Future<void> executeWithErrorHandling(
    Future<void> Function() operation, {
    Duration delay = const Duration(milliseconds: 300),
  }) async {
    try {
      setLoading(true);
      clearError();
      
      // Add small delay to prevent UI flicker
      await Future.delayed(delay);
      
      await operation();
      
      setLoaded();
    } catch (e) {
      setError(e.toString());
      
      // Auto-retry if not exceeded max retries
      if (shouldAutoRetry()) {
        await Future.delayed(const Duration(milliseconds: 500));
        await executeWithErrorHandling(operation, delay: Duration.zero);
      }
    }
  }

  /// Pull-to-refresh handler
  Future<void> handleRefresh(Future<void> Function() refreshOperation) async {
    try {
      setState(() {
        isRefreshing = true;
      });
      
      await refreshOperation();
      
      setLoaded();
    } catch (e) {
      setError(e.toString());
      setState(() {
        isRefreshing = false;
      });
    }
  }
}

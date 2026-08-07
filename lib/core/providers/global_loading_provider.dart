import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GlobalOverlayState { idle, loading, success, error, message }

class GlobalLoadingState {
  final GlobalOverlayState state;
  final String message;

  const GlobalLoadingState({required this.state, required this.message});

  const GlobalLoadingState.idle()
      : state = GlobalOverlayState.idle,
        message = '';

  bool get isLoading => state == GlobalOverlayState.loading;
  bool get isSuccess => state == GlobalOverlayState.success;
  bool get isError => state == GlobalOverlayState.error;
  bool get isMessage => state == GlobalOverlayState.message;

  GlobalLoadingState copyWith({GlobalOverlayState? state, String? message}) {
    return GlobalLoadingState(
      state: state ?? this.state,
      message: message ?? this.message,
    );
  }
}

class GlobalLoadingNotifier extends Notifier<GlobalLoadingState> {
  Timer? _timer;
  int _generation = 0;

  @override
  GlobalLoadingState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    return const GlobalLoadingState.idle();
  }

  /// Defer overlay mutations one frame so they never race modal route teardown
  /// (InheritedWidget descendant assertion during bottom-sheet pop).
  void _runNextFrame(void Function(int gen) apply) {
    final gen = ++_generation;
    _cancelTimer();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (gen != _generation) return;
      apply(gen);
    });
  }

  void showLoading([String message = 'Please wait...']) {
    _runNextFrame((_) {
      state = GlobalLoadingState(
        state: GlobalOverlayState.loading,
        message: message,
      );
    });
  }

  void showSuccess(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _runNextFrame((gen) {
      state = GlobalLoadingState(
        state: GlobalOverlayState.success,
        message: message,
      );
      _timer = Timer(duration, () {
        if (gen != _generation) return;
        _hideInternal();
      });
    });
  }

  void showError(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    final msg = message
        .replaceFirst('Exception:', '')
        .replaceFirst('Exception: ', '')
        .trim();
    _runNextFrame((gen) {
      state = GlobalLoadingState(
        state: GlobalOverlayState.error,
        message: msg,
      );
      _timer = Timer(duration, () {
        if (gen != _generation) return;
        _hideInternal();
      });
    });
  }

  void showMessage(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _runNextFrame((gen) {
      state = GlobalLoadingState(
        state: GlobalOverlayState.message,
        message: message,
      );
      _timer = Timer(duration, () {
        if (gen != _generation) return;
        _hideInternal();
      });
    });
  }

  void showApiError(Object e) {
    final msg = e.toString().replaceFirst('Exception: ', '').trim();
    showError(msg.isEmpty ? 'Something went wrong' : msg);
  }

  void hide() {
    _runNextFrame((_) => _hideInternal());
  }

  void reset() {
    _generation++;
    _cancelTimer();
    state = const GlobalLoadingState.idle();
  }

  void _hideInternal() {
    state = const GlobalLoadingState.idle();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

final globalLoadingProvider =
    NotifierProvider<GlobalLoadingNotifier, GlobalLoadingState>(
  GlobalLoadingNotifier.new,
);

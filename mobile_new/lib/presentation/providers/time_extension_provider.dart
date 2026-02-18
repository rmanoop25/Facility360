import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/time_extension_request_model.dart';
import '../../data/repositories/time_extension_repository.dart';

/// State for extension requests
class TimeExtensionState {
  final List<TimeExtensionRequestModel> requests;
  final bool isLoading;
  final String? error;

  TimeExtensionState({
    this.requests = const [],
    this.isLoading = false,
    this.error,
  });

  TimeExtensionState copyWith({
    List<TimeExtensionRequestModel>? requests,
    bool? isLoading,
    String? error,
  }) {
    return TimeExtensionState(
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Provider for SP's own requests
final myExtensionRequestsProvider =
    FutureProvider<List<TimeExtensionRequestModel>>((ref) async {
  final repository = ref.watch(timeExtensionRepositoryProvider);
  return repository.getMyRequests();
});

/// Provider for admin - all requests with optional filtering
final adminExtensionRequestsProvider = FutureProvider.family<
    List<TimeExtensionRequestModel>,
    String?>((ref, status) async {
  final repository = ref.watch(timeExtensionRepositoryProvider);
  return repository.getAllRequests(status: status);
});

/// Provider for pending requests count (for badges)
final pendingExtensionCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(timeExtensionRepositoryProvider);
  final pending = await repository.getAllRequests(status: 'pending');
  return pending.length;
});

/// Action provider for requests/approve/reject
class TimeExtensionActionsNotifier extends StateNotifier<TimeExtensionState> {
  final TimeExtensionRepository _repository;
  final Ref _ref;

  TimeExtensionActionsNotifier(this._repository, this._ref)
      : super(TimeExtensionState());

  Future<TimeExtensionRequestModel?> requestExtension({
    required int assignmentId,
    required int requestedMinutes,
    required String reason,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final request = await _repository.requestExtension(
        assignmentId: assignmentId,
        requestedMinutes: requestedMinutes,
        reason: reason,
      );

      state = state.copyWith(isLoading: false);

      // Refresh providers
      _ref.invalidate(myExtensionRequestsProvider);
      _ref.invalidate(adminExtensionRequestsProvider);

      return request;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> approveExtension(int extensionId, {String? adminNotes}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.approveExtension(extensionId, adminNotes: adminNotes);
      state = state.copyWith(isLoading: false);

      // Refresh providers
      _ref.invalidate(adminExtensionRequestsProvider);
      _ref.invalidate(pendingExtensionCountProvider);

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> rejectExtension(
      int extensionId, {
      required String adminNotes,
    }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.rejectExtension(extensionId, adminNotes: adminNotes);
      state = state.copyWith(isLoading: false);

      // Refresh providers
      _ref.invalidate(adminExtensionRequestsProvider);
      _ref.invalidate(pendingExtensionCountProvider);

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final timeExtensionActionsProvider =
    StateNotifierProvider<TimeExtensionActionsNotifier, TimeExtensionState>(
        (ref) {
  final repository = ref.watch(timeExtensionRepositoryProvider);
  return TimeExtensionActionsNotifier(repository, ref);
});

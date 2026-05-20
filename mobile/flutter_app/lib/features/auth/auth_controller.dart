import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/storage/auth_session_repository.dart';
import '../../shared/models/auth_models.dart';
import 'auth_repository.dart';

class AuthState {
  const AuthState({
    this.session,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final AuthSession? session;
  final bool isSubmitting;
  final String? errorMessage;

  bool get isAuthenticated => session != null;

  AuthState copyWith({
    AuthSession? session,
    bool clearSession = false,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      session: clearSession ? null : (session ?? this.session),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final session = ref.read(authSessionRepositoryProvider).readSession();
    return AuthState(session: session);
  }

  Future<void> login(LoginPayload payload) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
    );

    try {
      final session = await ref.read(authRepositoryProvider).login(payload);
      await ref.read(authSessionRepositoryProvider).saveSession(session);
      state = state.copyWith(
        session: session,
        isSubmitting: false,
      );
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: describeError(error),
      );
      rethrow;
    }
  }

  Future<void> register(RegisterPayload payload) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
    );

    try {
      final session = await ref.read(authRepositoryProvider).register(payload);
      await ref.read(authSessionRepositoryProvider).saveSession(session);
      state = state.copyWith(
        session: session,
        isSubmitting: false,
      );
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: describeError(error),
      );
      rethrow;
    }
  }

  Future<void> logout() async {
    await ref.read(authSessionRepositoryProvider).clearSession();
    state = state.copyWith(
      clearSession: true,
      clearError: true,
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import '../../features/auth/auth_controller.dart';

final serverCapabilitiesProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
      ref.watch(authControllerProvider.select((s) => s.session?.token));
      final response = await ref
          .watch(apiClientProvider)
          .get<Map<String, dynamic>>('/api/v1/system/status');
      return response.data ?? {};
    });

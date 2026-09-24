import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

final serverCapabilitiesProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final response = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>('/api/v1/system/status');
  return response.data ?? {};
});

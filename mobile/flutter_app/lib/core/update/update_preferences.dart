import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/key_value_store.dart';

final autoUpdateProvider = NotifierProvider<AutoUpdate, bool>(AutoUpdate.new);

class AutoUpdate extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(keyValueStoreProvider).readString('questrace:auto-update') !=
      'false';
  Future<void> setEnabled(bool value) async {
    await ref
        .read(keyValueStoreProvider)
        .writeString('questrace:auto-update', '$value');
    state = value;
  }
}

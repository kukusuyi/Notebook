import 'dart:async';
import 'dart:convert';
import 'package:nsd/nsd.dart';

class LanComputer {
  const LanComputer(this.id, this.name, this.url);
  final String id, name, url;
}

class LanDiscovery {
  Future<List<LanComputer>> scan() async {
    final discovery = await startDiscovery('_questrace._tcp');
    try {
      await Future<void>.delayed(const Duration(seconds: 4));
      final found = <String, LanComputer>{};
      for (final service in discovery.services) {
        final id = utf8.decode(service.txt?['id'] ?? [], allowMalformed: true);
        final host = service.host;
        if (!RegExp(r'^[a-f0-9]{12}$').hasMatch(id) ||
            host == null ||
            service.port == null) {
          continue;
        }
        final url = Uri(
          scheme: 'http',
          host: host.replaceFirst(RegExp(r'\.$'), ''),
          port: service.port!,
        ).toString();
        found[id] = LanComputer(id, service.name ?? host, url);
      }
      return found.values.toList();
    } finally {
      await stopDiscovery(discovery);
    }
  }
}

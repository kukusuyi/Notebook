String resolveRemoteUrl(String rawUrl, String apiBaseUrl) {
  final normalized = rawUrl.trim();
  if (normalized.isEmpty) {
    return normalized;
  }

  final assetUri = Uri.tryParse(normalized);
  final baseUri = Uri.tryParse(apiBaseUrl);
  if (baseUri == null) {
    return normalized;
  }

  if (assetUri == null) {
    return normalized;
  }

  if (!assetUri.hasScheme) {
    return baseUri.resolveUri(assetUri).toString();
  }

  if (assetUri.host == 'localhost' || assetUri.host == '127.0.0.1') {
    final port = assetUri.hasPort
        ? assetUri.port
        : (baseUri.hasPort ? baseUri.port : null);

    return assetUri.replace(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: port,
    ).toString();
  }

  return normalized;
}

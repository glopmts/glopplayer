/// Representa um asset anexado a uma release do GitHub (ex: o .apk).
class GithubAsset {
  final String name;
  final String downloadUrl;
  final int size; // bytes
  final String contentType;

  GithubAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
    required this.contentType,
  });

  factory GithubAsset.fromJson(Map<String, dynamic> json) {
    return GithubAsset(
      name: json['name'] as String? ?? '',
      downloadUrl: json['browser_download_url'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      contentType: json['content_type'] as String? ?? '',
    );
  }

  bool get isApk =>
      name.toLowerCase().endsWith('.apk') ||
      contentType == 'application/vnd.android.package-archive';
}

/// Representa uma release do repositório no GitHub.
class AppRelease {
  final String tagName; // ex: "v1.4.2"
  final String version; // ex: "1.4.2" (sem o "v")
  final String title;
  final String changelog; // corpo/descrição da release (markdown puro)
  final DateTime publishedAt;
  final bool prerelease;
  final List<GithubAsset> assets;
  final String htmlUrl; // link da release no github, usado como fallback

  AppRelease({
    required this.tagName,
    required this.version,
    required this.title,
    required this.changelog,
    required this.publishedAt,
    required this.prerelease,
    required this.assets,
    required this.htmlUrl,
  });

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String? ?? '';
    final assetsJson = (json['assets'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map((a) => GithubAsset.fromJson(a))
        .toList();

    DateTime published;
    try {
      published = DateTime.parse(json['published_at'] as String? ?? '');
    } catch (_) {
      published = DateTime.now();
    }

    return AppRelease(
      tagName: tag,
      version: _stripVPrefix(tag),
      title: json['name'] as String? ?? tag,
      changelog: json['body'] as String? ?? '',
      publishedAt: published,
      prerelease: json['prerelease'] as bool? ?? false,
      assets: assetsJson,
      htmlUrl: json['html_url'] as String? ?? '',
    );
  }

  static String _stripVPrefix(String tag) {
    if (tag.isEmpty) return tag;
    return tag.startsWith(RegExp(r'[vV]')) ? tag.substring(1) : tag;
  }

  /// Primeiro asset .apk encontrado na release, ou null se não houver.
  GithubAsset? get apkAsset {
    for (final asset in assets) {
      if (asset.isApk) return asset;
    }
    return null;
  }
}

/// Compara duas versões no estilo semver (major.minor.patch[.build]).
/// Retorna > 0 se [a] for mais nova que [b], < 0 se mais antiga, 0 se igual.
int compareVersions(String a, String b) {
  final partsA = _versionParts(a);
  final partsB = _versionParts(b);
  final length = partsA.length > partsB.length ? partsA.length : partsB.length;

  for (var i = 0; i < length; i++) {
    final va = i < partsA.length ? partsA[i] : 0;
    final vb = i < partsB.length ? partsB[i] : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}

List<int> _versionParts(String version) {
  // Remove qualquer coisa depois de "-" ou "+" (ex: 1.2.0-beta.1 -> 1.2.0)
  final clean = version.split(RegExp(r'[-+]')).first;
  return clean
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
}

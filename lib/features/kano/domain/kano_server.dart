/// 服务端基址与主备站切换。
///
/// 与鸿蒙 `KanoServer` 同一套口径：
/// - 默认主站 `https://xiaolubao.com`
/// - 主站传输失败或 5xx 时依次切到 `https://kano.kafuno.cn` → `https://kano.fans`
/// - 切换后本次启动内锁定当前可用站，不再来回跳
/// - `/media`、`/assets` 这类相对路径必须补上当前基址
class KanoServer {
  KanoServer._();

  static const defaultBase = 'https://xiaolubao.com';
  static const fallbackBase = 'https://kano.kafuno.cn';
  static const thirdFallbackBase = 'https://kano.fans';
  static const bases = <String>[defaultBase, fallbackBase, thirdFallbackBase];

  static int _fallbackIndex = 0;
  static String? _customBase;

  /// 当前生效的基址（末尾无斜杠）。
  static String get base => _customBase ?? bases[_fallbackIndex];

  /// 是否已经在备用站上（用于界面上给一句提示）。
  static bool get onFallback => _customBase == null && _fallbackIndex > 0;

  /// 用户自定义的实例；空串表示没设过（走主备站）。
  static String get customBase => _customBase ?? '';

  /// 用户自定义实例（设置页可改），传空串恢复默认。
  static void setCustomBase(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      _customBase = null;
      return;
    }
    final normalized = normalize(value);
    _customBase = normalized == defaultBase ? null : normalized;
  }

  /// 当前数据源失败时调用；返回下一备站基址，已是末站或自定义实例则返回 null。
  static String? switchToFallback(String from) {
    if (_customBase != null) return null;
    final idx = bases.indexOf(normalize(from));
    if (idx < 0 || idx + 1 >= bases.length) return null;
    if (_fallbackIndex <= idx) {
      _fallbackIndex = idx + 1;
    }
    return bases[_fallbackIndex];
  }

  static String normalize(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return defaultBase;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static const _knownHosts = <String>[
    'https://xiaolubao.com',
    'http://xiaolubao.com',
    'https://kano.kafuno.cn',
    'http://kano.kafuno.cn',
    'https://kano.fans',
    'http://kano.fans',
  ];

  /// 把服务端给的相对路径补成绝对地址；主备切换后旧快照里的主站地址也会被改写到当前基址。
  static String absolute(String path) {
    if (path.isEmpty) return '';
    for (final host in _knownHosts) {
      if (!path.startsWith(host)) continue;
      final rest = path.substring(host.length);
      if (rest.isNotEmpty && !rest.startsWith('/') && !rest.startsWith('?')) continue;
      return '$base$rest';
    }
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$base${path.startsWith('/') ? '' : '/'}$path';
  }

  /// 从 X 主页地址里抠出小写 handle（`/api/posts?account=` 要这个形态）。
  static String accountOf(String xUrl) {
    final match = RegExp(r'x\.com/([^/?#]+)', caseSensitive: false).firstMatch(xUrl);
    return match == null ? '' : match.group(1)!.toLowerCase();
  }
}

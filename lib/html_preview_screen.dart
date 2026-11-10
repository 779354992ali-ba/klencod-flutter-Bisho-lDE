
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:saf/saf.dart';

class HtmlPreviewScreen extends StatefulWidget {
  final String htmlCode;
  final String? projectUri;

  const HtmlPreviewScreen({
    super.key,
    required this.htmlCode,
    this.projectUri,
  });

  @override
  State<HtmlPreviewScreen> createState() =>
      _HtmlPreviewScreenState();
}

class _HtmlPreviewScreenState extends State<HtmlPreviewScreen> {
  late final WebViewController _controller;

  final Saf _saf = Saf();

  bool _isLoading = true;
  String? _error;

  final Map<String, String> _files = {};

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF101318))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;

            setState(() {
              _isLoading = true;
              _error = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;

            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {
            if (!mounted) return;

            setState(() {
              _isLoading = false;
              _error = error.description;
            });
          },
        ),
      );

    _loadPage();
  }

  String _mimeType(String name) {
    final extension = name.split('.').last.toLowerCase();

    const types = {
      'html': 'text/html',
      'htm': 'text/html',
      'css': 'text/css',
      'js': 'text/javascript',
      'mjs': 'text/javascript',
      'json': 'application/json',
      'svg': 'image/svg+xml',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'ico': 'image/x-icon',
      'woff': 'font/woff',
      'woff2': 'font/woff2',
      'ttf': 'font/ttf',
      'otf': 'font/otf',
      'mp3': 'audio/mpeg',
      'mp4': 'video/mp4',
    };

    return types[extension] ?? 'application/octet-stream';
  }

  Future<void> _readDirectory(
    String directoryUri,
    String prefix,
  ) async {
    final items = await _saf.list(directoryUri);

    for (final item in items) {
      final relativePath = prefix.isEmpty
          ? item.name
          : '$prefix/${item.name}';

      if (item.isDir) {
        await _readDirectory(
          item.uri,
          relativePath,
        );
      } else {
        try {
          final bytes = await _saf.readFileBytes(item.uri);

          final mime = _mimeType(item.name);
          final data = base64Encode(bytes);

          _files[relativePath] = 'data:$mime;base64,$data';
        } catch (_) {
          // تجاهل الملفات التي تعذرت قراءتها.
        }
      }
    }
  }

  String _normalizePath(String path) {
    final parts = <String>[];

    for (final part in path.split('/')) {
      if (part.isEmpty || part == '.') continue;

      if (part == '..') {
        if (parts.isNotEmpty) {
          parts.removeLast();
        }
      } else {
        parts.add(part);
      }
    }

    return parts.join('/');
  }

  String? _resolveFile(
    String path, {
    String baseDirectory = '',
  }) {
    final cleanPath = path.trim();

    if (cleanPath.isEmpty ||
        cleanPath.startsWith('http://') ||
        cleanPath.startsWith('https://') ||
        cleanPath.startsWith('data:') ||
        cleanPath.startsWith('blob:') ||
        cleanPath.startsWith('//') ||
        cleanPath.startsWith('#') ||
        cleanPath.startsWith('mailto:') ||
        cleanPath.startsWith('javascript:')) {
      return null;
    }

    final withoutQuery =
        cleanPath.split('?').first.split('#').first;

    final combined = withoutQuery.startsWith('/')
        ? withoutQuery.substring(1)
        : baseDirectory.isEmpty
            ? withoutQuery
            : '$baseDirectory/$withoutQuery';

    return _files[_normalizePath(combined)];
  }

  String _rewriteCss(
    String css, {
    String baseDirectory = '',
  }) {
    return css.replaceAllMapped(
      RegExp(
        r'''url\(\s*(['"]?)(.*?)\1\s*\)''',
        caseSensitive: false,
      ),
      (match) {
        final path = match.group(2) ?? '';

        final data = _resolveFile(
          path,
          baseDirectory: baseDirectory,
        );

        if (data == null) {
          return match.group(0)!;
        }

        return 'url("$data")';
      },
    );
  }

  String _prepareHtml() {
    var html = widget.htmlCode;

    // معالجة ملفات JavaScript والصور والوسائط و iframe.
    html = html.replaceAllMapped(
      RegExp(
        r'''<(script|img|source|video|audio|iframe)\b[^>]+src\s*=\s*(['"])(.*?)\2[^>]*>''',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final tag = match.group(0)!;
        final path = match.group(3) ?? '';

        final data = _resolveFile(path);

        if (data == null) return tag;

        return tag.replaceFirst(
          RegExp(
            r'''src\s*=\s*(['"])(.*?)\1''',
            caseSensitive: false,
          ),
          'src="$data"',
        );
      },
    );

    // معالجة ملفات CSS الخارجية.
    html = html.replaceAllMapped(
      RegExp(
        r'''<link\b[^>]*href\s*=\s*(['"])(.*?)\1[^>]*>''',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final tag = match.group(0)!;
        final path = match.group(2) ?? '';

        final data = _resolveFile(path);

        if (data == null) return tag;

        return tag.replaceFirst(
          RegExp(
            r'''href\s*=\s*(['"])(.*?)\1''',
            caseSensitive: false,
          ),
          'href="$data"',
        );
      },
    );

    // معالجة CSS الموجود داخل style.
    html = html.replaceAllMapped(
      RegExp(
        r'<style[^>]*>(.*?)</style>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final css = _rewriteCss(
          match.group(1) ?? '',
        );

        return '<style>$css</style>';
      },
    );

    return html;
  }

  Future<void> _loadPage() async {
    try {
      _files.clear();

      if (widget.projectUri != null &&
          widget.projectUri!.isNotEmpty) {
        await _readDirectory(
          widget.projectUri!,
          '',
        );
      }

      if (!mounted) return;

      final html = _prepareHtml();

      await _controller.loadHtmlString(html);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _reloadPage() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    await _loadPage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101318),
      appBar: AppBar(
        backgroundColor: const Color(0xFF191E26),
        foregroundColor: Colors.white,
        title: const Text(
          'معاينة مشروع الويب',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _reloadPage,
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة تحميل المشروع',
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(
            controller: _controller,
          ),

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),

          if (_error != null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF252B35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'تعذر عرض المشروع',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _reloadPage,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
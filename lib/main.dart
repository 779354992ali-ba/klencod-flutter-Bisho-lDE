
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';

import 'package:highlight/languages/dart.dart' as dart_lang;
import 'package:highlight/languages/python.dart' as python_lang;
import 'package:highlight/languages/javascript.dart' as js_lang;
import 'package:highlight/languages/typescript.dart' as ts_lang;
import 'package:highlight/languages/java.dart' as java_lang;
import 'package:highlight/languages/kotlin.dart' as kotlin_lang;
import 'package:highlight/languages/swift.dart' as swift_lang;
import 'package:highlight/languages/c.dart' as c_lang;
import 'package:highlight/languages/cpp.dart' as cpp_lang;
import 'package:highlight/languages/css.dart' as css_lang;
import 'package:highlight/languages/xml.dart' as xml_lang;
import 'package:highlight/languages/json.dart' as json_lang;
import 'package:highlight/languages/sql.dart' as sql_lang;
import 'package:highlight/languages/bash.dart' as bash_lang;
import 'package:highlight/languages/go.dart' as go_lang;
import 'package:highlight/languages/rust.dart' as rust_lang;
import 'package:highlight/languages/php.dart' as php_lang;

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BishoIDE());
}

class BishoIDE extends StatelessWidget {
  const BishoIDE({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bisho IDE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B1020),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
        ),
      ),
      home: const EditorScreen(),
    );
  }
}

class EditorTab {
  final String id;
  final CodeController controller;

  String fileName;
  String language;
  String? filePath;
  bool isSaved;

  EditorTab({
    required this.id,
    required this.controller,
    required this.fileName,
    required this.language,
    this.filePath,
    this.isSaved = true,
  });
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final Map<String, dynamic> languages = {
    'Dart': dart_lang.dart,
    'Python': python_lang.python,
    'JavaScript': js_lang.javascript,
    'TypeScript': ts_lang.typescript,
    'Java': java_lang.java,
    'Kotlin': kotlin_lang.kotlin,
    'Swift': swift_lang.swift,
    'C': c_lang.c,
    'C++': cpp_lang.cpp,
    'CSS': css_lang.css,
    'HTML': xml_lang.xml,
    'XML': xml_lang.xml,
    'JSON': json_lang.json,
    'SQL': sql_lang.sql,
    'Bash': bash_lang.bash,
    'Go': go_lang.go,
    'Rust': rust_lang.rust,
    'PHP': php_lang.php,
  };

  final Map<String, String> extensions = {
    'Dart': 'dart',
    'Python': 'py',
    'JavaScript': 'js',
    'TypeScript': 'ts',
    'Java': 'java',
    'Kotlin': 'kt',
    'Swift': 'swift',
    'C': 'c',
    'C++': 'cpp',
    'CSS': 'css',
    'HTML': 'html',
    'XML': 'xml',
    'JSON': 'json',
    'SQL': 'sql',
    'Bash': 'sh',
    'Go': 'go',
    'Rust': 'rs',
    'PHP': 'php',
  };

  final List<EditorTab> tabs = [];

  int activeIndex = 0;
  int nextTabId = 1;

  String status = 'جاهز';
  String? projectPath;
  String projectName = 'لا يوجد مشروع';

  bool isRestoring = false;
  bool explorerVisible = true;

  EditorTab get activeTab => tabs[activeIndex];

  @override
  void initState() {
    super.initState();
    restoreTabs();
  }

  String createId() {
    return '${DateTime.now().microsecondsSinceEpoch}_${nextTabId++}';
  }

  EditorTab createTab({
    String fileName = 'untitled.dart',
    String language = 'Dart',
    String? code,
    String? filePath,
    bool isSaved = false,
  }) {
    final controller = CodeController(
      text: code ??
          '// Welcome to Bisho IDE\n\nvoid main() {\n  print("Hello World");\n}',
      language: languages[language] ?? languages['Dart'],
    );

    final tab = EditorTab(
      id: createId(),
      controller: controller,
      fileName: fileName,
      language: language,
      filePath: filePath,
      isSaved: isSaved,
    );

    controller.addListener(() {
      if (!mounted || isRestoring) return;

      setState(() {
        tab.isSaved = false;
        status = 'تعديلات جديدة';
      });
    });

    return tab;
  }

  Future<void> restoreTabs() async {
    isRestoring = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTabs = prefs.getString('bisho_tabs');
      final savedIndex = prefs.getInt('bisho_active_index') ?? 0;

      projectPath = prefs.getString('bisho_project_path');
      projectName = prefs.getString('bisho_project_name') ??
          'لا يوجد مشروع';

      if (savedTabs != null) {
        final List<dynamic> data = jsonDecode(savedTabs);

        for (final item in data) {
          final language = item['language'] as String? ?? 'Dart';
          final safeLanguage =
              languages.containsKey(language) ? language : 'Dart';

          tabs.add(
            createTab(
              fileName:
                  item['fileName'] as String? ?? 'untitled.dart',
              language: safeLanguage,
              code: item['code'] as String? ?? '',
              filePath: item['filePath'] as String?,
              isSaved: true,
            ),
          );
        }
      } else {
        final oldCode = prefs.getString('bisho_code');
        final oldName =
            prefs.getString('bisho_filename') ?? 'main.dart';
        final oldLanguage =
            prefs.getString('bisho_language') ?? 'Dart';

        final safeLanguage =
            languages.containsKey(oldLanguage) ? oldLanguage : 'Dart';

        tabs.add(
          createTab(
            fileName: oldName,
            language: safeLanguage,
            code: oldCode,
            isSaved: true,
          ),
        );
      }

      if (tabs.isEmpty) {
        tabs.add(createTab());
      }

      activeIndex = savedIndex.clamp(0, tabs.length - 1).toInt();
    } catch (e) {
      for (final tab in tabs) {
        tab.controller.dispose();
      }
      tabs.clear();
      tabs.add(createTab());
      activeIndex = 0;
    }

    isRestoring = false;

    if (mounted) {
      setState(() {
        status = 'تم استعادة المشروع';
      });
    }
  }

  Future<void> saveAllTabs() async {
    try {
      for (final tab in tabs) {
        if (tab.filePath != null) {
          final file = File(tab.filePath!);
          await file.writeAsString(tab.controller.text);
        }
      }

      final prefs = await SharedPreferences.getInstance();

      final data = tabs.map((tab) {
        return {
          'fileName': tab.fileName,
          'language': tab.language,
          'code': tab.controller.text,
          'filePath': tab.filePath,
        };
      }).toList();

      await prefs.setString('bisho_tabs', jsonEncode(data));
      await prefs.setInt('bisho_active_index', activeIndex);

      await prefs.setString(
        'bisho_code',
        activeTab.controller.text,
      );
      await prefs.setString(
        'bisho_filename',
        activeTab.fileName,
      );
      await prefs.setString(
        'bisho_language',
        activeTab.language,
      );

      if (!mounted) return;

      setState(() {
        for (final tab in tabs) {
          tab.isSaved = true;
        }
        status = 'تم حفظ جميع الملفات';
      });

      showMessage('تم حفظ الملفات');
    } catch (e) {
      showMessage('تعذر حفظ بعض الملفات: $e');
    }
  }

  Future<void> saveTabStateSilently() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final data = tabs.map((tab) {
        return {
          'fileName': tab.fileName,
          'language': tab.language,
          'code': tab.controller.text,
          'filePath': tab.filePath,
        };
      }).toList();

      await prefs.setString('bisho_tabs', jsonEncode(data));
      await prefs.setInt('bisho_active_index', activeIndex);
    } catch (_) {}
  }

  void createNewTab() {
    setState(() {
      tabs.add(createTab());
      activeIndex = tabs.length - 1;
      status = 'تم إنشاء ملف جديد';
    });
  }

  void selectTab(int index) {
    if (index < 0 || index >= tabs.length) return;

    setState(() {
      activeIndex = index;
      status = 'تم فتح ${activeTab.fileName}';
    });
  }

  Future<void> closeTab(int index) async {
    if (index < 0 || index >= tabs.length) return;

    final tab = tabs[index];

    if (!tab.isSaved) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('إغلاق الملف؟'),
          content: Text(
            'الملف ${tab.fileName} يحتوي على تعديلات غير محفوظة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('إغلاق بدون حفظ'),
            ),
          ],
        ),
      );

      if (result != true) return;
    }

    setState(() {
      tab.controller.dispose();
      tabs.removeAt(index);

      if (tabs.isEmpty) {
        tabs.add(createTab());
        activeIndex = 0;
      } else if (activeIndex > index) {
        activeIndex--;
      } else if (activeIndex >= tabs.length) {
        activeIndex = tabs.length - 1;
      }
    });

    await saveTabStateSilently();
  }

  String detectLanguage(String extension) {
    const map = {
      'dart': 'Dart',
      'py': 'Python',
      'js': 'JavaScript',
      'ts': 'TypeScript',
      'java': 'Java',
      'kt': 'Kotlin',
      'swift': 'Swift',
      'c': 'C',
      'h': 'C',
      'cpp': 'C++',
      'cc': 'C++',
      'css': 'CSS',
      'html': 'HTML',
      'htm': 'HTML',
      'xml': 'XML',
      'json': 'JSON',
      'sql': 'SQL',
      'sh': 'Bash',
      'go': 'Go',
      'rs': 'Rust',
      'php': 'PHP',
    };

    return map[extension.toLowerCase()] ?? 'Dart';
  }

  Future<void> openFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final Uint8List? bytes = file.bytes;

      if (bytes == null) {
        showMessage('تعذر قراءة الملف');
        return;
      }

      final language = detectLanguage(file.extension ?? '');
      final content = utf8.decode(bytes, allowMalformed: true);

      setState(() {
        tabs.add(
          createTab(
            fileName: file.name,
            language: language,
            code: content,
            filePath: file.path,
            isSaved: true,
          ),
        );
        activeIndex = tabs.length - 1;
        status = 'تم فتح الملف';
      });

      await saveTabStateSilently();
    } catch (e) {
      showMessage('حدث خطأ أثناء فتح الملف');
    }
  }

  Future<void> openProjectFolder() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'اختر مجلد المشروع',
      );

      if (path == null) return;

      final directory = Directory(path);

      if (!await directory.exists()) {
        showMessage('المجلد غير موجود أو لا يمكن الوصول إليه');
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('bisho_project_path', path);
      await prefs.setString(
        'bisho_project_name',
        directory.uri.pathSegments
            .where((part) => part.isNotEmpty)
            .last,
      );

      if (!mounted) return;

      setState(() {
        projectPath = path;
        projectName = directory.uri.pathSegments
            .where((part) => part.isNotEmpty)
            .last;
        explorerVisible = true;
        status = 'تم فتح المشروع';
      });

      showMessage('تم فتح مجلد المشروع');
    } catch (e) {
      showMessage('تعذر فتح المجلد: $e');
    }
  }

  Future<void> openProjectFile(File file) async {
    try {
      final content = await file.readAsString();
      final name = file.uri.pathSegments.last;
      final language = detectLanguage(
        name.contains('.') ? name.split('.').last : '',
      );

      final existingIndex = tabs.indexWhere(
        (tab) => tab.filePath == file.path,
      );

      if (existingIndex != -1) {
        selectTab(existingIndex);
        return;
      }

      setState(() {
        tabs.add(
          createTab(
            fileName: name,
            language: language,
            code: content,
            filePath: file.path,
            isSaved: true,
          ),
        );

        activeIndex = tabs.length - 1;
        status = 'تم فتح $name';
      });

      await saveTabStateSilently();
    } catch (e) {
      showMessage('تعذر قراءة الملف: $e');
    }
  }

  Future<void> createProjectFile() async {
    if (projectPath == null) {
      showMessage('افتح مجلد مشروع أولاً');
      return;
    }

    final name = await askName('إنشاء ملف جديد', 'مثال: main.dart');

    if (name == null || name.trim().isEmpty) return;

    try {
      final file = File(
        '${projectPath!}${Platform.pathSeparator}${name.trim()}',
      );

      if (await file.exists()) {
        showMessage('هذا الملف موجود بالفعل');
        return;
      }

      await file.create(recursive: true);

      setState(() {
        status = 'تم إنشاء الملف';
      });

      await openProjectFile(file);
      showMessage('تم إنشاء الملف');
    } catch (e) {
      showMessage('تعذر إنشاء الملف: $e');
    }
  }

  Future<void> createProjectFolder() async {
    if (projectPath == null) {
      showMessage('افتح مجلد مشروع أولاً');
      return;
    }

    final name = await askName('إنشاء مجلد جديد', 'اسم المجلد');

    if (name == null || name.trim().isEmpty) return;

    try {
      final directory = Directory(
        '${projectPath!}${Platform.pathSeparator}${name.trim()}',
      );

      await directory.create(recursive: true);

      setState(() {
        status = 'تم إنشاء المجلد';
      });

      showMessage('تم إنشاء المجلد');
    } catch (e) {
      showMessage('تعذر إنشاء المجلد: $e');
    }
  }

  Future<String?> askName(String title, String hint) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              controller.text,
            ),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  Future<void> renameEntity(FileSystemEntity entity) async {
    final oldName = entity.uri.pathSegments.last;

    final name = await askName('إعادة تسمية', oldName);

    if (name == null || name.trim().isEmpty) return;

    try {
      final parent = entity.parent.path;
      final newPath = '$parent${Platform.pathSeparator}${name.trim()}';

      if (entity is File) {
        await entity.rename(newPath);
      } else if (entity is Directory) {
        await entity.rename(newPath);
      }

      for (final tab in tabs) {
        if (tab.filePath == entity.path) {
          tab.filePath = newPath;
          tab.fileName = name.trim();
          tab.isSaved = true;
        }
      }

      setState(() {
        status = 'تم تغيير الاسم';
      });

      await saveTabStateSilently();
      showMessage('تم تغيير الاسم');
    } catch (e) {
      showMessage('تعذرت إعادة التسمية: $e');
    }
  }

  Future<void> deleteEntity(FileSystemEntity entity) async {
    final name = entity.uri.pathSegments.last;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف $name؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await entity.delete(recursive: true);

      tabs.removeWhere((tab) {
        final path = tab.filePath;
        if (path == null) return false;

        final deletedPath = entity.path;
        final belongsToDeleted = path == deletedPath ||
            path.startsWith(
              '$deletedPath${Platform.pathSeparator}',
            );

        if (belongsToDeleted) {
          tab.controller.dispose();
        }

        return belongsToDeleted;
      });

      if (tabs.isEmpty) {
        tabs.add(createTab());
      }

      activeIndex = activeIndex.clamp(0, tabs.length - 1).toInt();

      setState(() {
        status = 'تم حذف العنصر';
      });

      await saveTabStateSilently();
      showMessage('تم الحذف');
    } catch (e) {
      showMessage('تعذر الحذف: $e');
    }
  }

  Future<void> saveCurrentToDisk() async {
    final tab = activeTab;

    if (tab.filePath == null) {
      await exportFile();
      return;
    }

    try {
      await File(tab.filePath!).writeAsString(tab.controller.text);

      setState(() {
        tab.isSaved = true;
        status = 'تم حفظ ${tab.fileName}';
      });

      await saveTabStateSilently();
      showMessage('تم حفظ الملف');
    } catch (e) {
      showMessage('تعذر حفظ الملف: $e');
    }
  }

  Future<void> exportFile() async {
    try {
      final bytes = Uint8List.fromList(
        utf8.encode(activeTab.controller.text),
      );

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'تصدير الملف',
        fileName: activeTab.fileName,
        bytes: bytes,
      );

      if (path != null) {
        setState(() {
          activeTab.isSaved = true;
          status = 'تم التصدير';
        });

        await saveTabStateSilently();
        showMessage('تم تصدير الملف');
      }
    } catch (e) {
      showMessage('تعذر تصدير الملف: $e');
    }
  }

  void changeLanguage(String? language) {
    if (language == null) return;

    setState(() {
      activeTab.language = language;
      activeTab.controller.language = languages[language];

      final parts = activeTab.fileName.split('.');
      final baseName = parts.length > 1
          ? parts.sublist(0, parts.length - 1).join('.')
          : activeTab.fileName;

      activeTab.fileName =
          '$baseName.${extensions[language] ?? 'txt'}';

      activeTab.isSaved = false;
      status = 'تم تغيير اللغة';
    });
  }

  Future<void> searchCode() async {
    final controller = TextEditingController();

    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('البحث في الكود'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'اكتب النص للبحث',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('بحث'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (query == null || query.isEmpty) return;

    final index = activeTab.controller.text.indexOf(query);

    if (index == -1) {
      showMessage('لم يتم العثور على النص');
      return;
    }

    activeTab.controller.selection = TextSelection(
      baseOffset: index,
      extentOffset: index + query.length,
    );

    showMessage('تم العثور على النص');
  }

  Future<void> copyCode() async {
    await Clipboard.setData(
      ClipboardData(text: activeTab.controller.text),
    );
    showMessage('تم نسخ الكود');
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget buildExplorerNode(
    Directory directory,
    int depth,
  ) {
    return FutureBuilder<List<FileSystemEntity>>(
      future: directory.list(followLinks: false).toList(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return const ListTile(
            dense: true,
            title: Text('تعذر قراءة المجلد'),
          );
        }

        final items = snapshot.data ?? [];

        items.sort((a, b) {
          final aDir = a is Directory;
          final bDir = b is Directory;

          if (aDir && !bDir) return -1;
          if (!aDir && bDir) return 1;

          return a.path.toLowerCase().compareTo(
                b.path.toLowerCase(),
              );
        });

        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'المجلد فارغ',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((entity) {
            final name = entity.uri.pathSegments.last;

            if (entity is Directory) {
              return Padding(
                padding: EdgeInsets.only(right: depth * 5.0),
                child: ExpansionTile(
                  key: PageStorageKey(entity.path),
                  dense: true,
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                  ),
                  leading: const Icon(
                    Icons.folder,
                    color: Color(0xFFFBBF24),
                    size: 20,
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      size: 18,
                    ),
                    onSelected: (value) {
                      if (value == 'rename') {
                        renameEntity(entity);
                      }
                      if (value == 'delete') {
                        deleteEntity(entity);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text('إعادة تسمية'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('حذف'),
                      ),
                    ],
                  ),
                  children: [
                    buildExplorerNode(entity, depth + 1),
                  ],
                ),
              );
            }

            if (entity is File) {
              return Padding(
                padding: EdgeInsets.only(right: depth * 5.0),
                child: ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                  ),
                  leading: const Icon(
                    Icons.insert_drive_file,
                    color: Color(0xFF38BDF8),
                    size: 19,
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => openProjectFile(entity),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      size: 18,
                    ),
                    onSelected: (value) {
                      if (value == 'rename') {
                        renameEntity(entity);
                      }
                      if (value == 'delete') {
                        deleteEntity(entity);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text('إعادة تسمية'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('حذف'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return const SizedBox.shrink();
          }).toList(),
        );
      },
    );
  }

  Widget buildExplorer() {
    return Container(
      width: 190,
      color: const Color(0xFF111827),
      child: Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'المستكشف',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: createProjectFile,
                  icon: const Icon(Icons.note_add, size: 19),
                  tooltip: 'ملف جديد',
                ),
                IconButton(
                  onPressed: createProjectFolder,
                  icon: const Icon(Icons.create_new_folder, size: 19),
                  tooltip: 'مجلد جديد',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (projectPath == null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.folder_open,
                        size: 38,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'لم يتم فتح مشروع',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: openProjectFolder,
                        child: const Text('فتح مجلد'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.folder,
                      color: Color(0xFFFBBF24),
                    ),
                    title: Text(
                      projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    trailing: IconButton(
                      onPressed: openProjectFolder,
                      icon: const Icon(Icons.folder_open, size: 18),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: buildExplorerNode(
                        Directory(projectPath!),
                        0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget buildTabBar() {
    return Container(
      height: 46,
      color: const Color(0xFF111827),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final selected = index == activeIndex;

                return InkWell(
                  onTap: () => selectTab(index),
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 100,
                      maxWidth: 180,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF0B1020)
                          : Colors.transparent,
                      border: Border(
                        top: BorderSide(
                          color: selected
                              ? const Color(0xFF38BDF8)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.insert_drive_file,
                          size: 15,
                          color: Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            tab.fileName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        if (!tab.isSaved)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.circle,
                              size: 7,
                              color: Colors.amber,
                            ),
                          ),
                        GestureDetector(
                          onTap: () => closeTab(index),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            onPressed: createNewTab,
            icon: const Icon(
              Icons.add,
              color: Color(0xFF38BDF8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final tab in tabs) {
      tab.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final tab = activeTab;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF151C30),
          title: const Row(
            children: [
              Icon(
                Icons.code,
                color: Color(0xFF38BDF8),
              ),
              SizedBox(width: 8),
              Text(
                'Bisho IDE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () {
                setState(() {
                  explorerVisible = !explorerVisible;
                });
              },
              icon: const Icon(Icons.folder_open),
              tooltip: 'المستكشف',
            ),
            IconButton(
              onPressed: saveCurrentToDisk,
              icon: const Icon(Icons.save),
              tooltip: 'حفظ الملف',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'new') createNewTab();
                if (value == 'open') openFile();
                if (value == 'folder') openProjectFolder();
                if (value == 'export') exportFile();
                if (value == 'search') searchCode();
                if (value == 'copy') copyCode();
                if (value == 'saveall') saveAllTabs();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'new',
                  child: Text('ملف جديد'),
                ),
                PopupMenuItem(
                  value: 'open',
                  child: Text('فتح ملف'),
                ),
                PopupMenuItem(
                  value: 'folder',
                  child: Text('فتح مجلد مشروع'),
                ),
                PopupMenuItem(
                  value: 'export',
                  child: Text('تصدير الملف'),
                ),
                PopupMenuItem(
                  value: 'search',
                  child: Text('بحث'),
                ),
                PopupMenuItem(
                  value: 'copy',
                  child: Text('نسخ الكود'),
                ),
                PopupMenuItem(
                  value: 'saveall',
                  child: Text('حفظ جميع الملفات'),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            buildTabBar(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              color: const Color(0xFF111827),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tab.fileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  DropdownButton<String>(
                    value: tab.language,
                    dropdownColor: const Color(0xFF1E293B),
                    underline: const SizedBox(),
                    items: languages.keys.map((language) {
                      return DropdownMenuItem<String>(
                        value: language,
                        child: Text(language),
                      );
                    }).toList(),
                    onChanged: changeLanguage,
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  toolButton(Icons.add, 'جديد', createNewTab),
                  toolButton(Icons.folder_open, 'فتح', openFile),
                  toolButton(Icons.folder, 'مشروع', openProjectFolder),
                  toolButton(Icons.save, 'حفظ', saveCurrentToDisk),
                  toolButton(Icons.download, 'تصدير', exportFile),
                  toolButton(Icons.search, 'بحث', searchCode),
                  toolButton(Icons.copy, 'نسخ', copyCode),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  if (explorerVisible) buildExplorer(),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF080D19),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF26334D),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CodeTheme(
                        data: CodeThemeData(
                          styles: monokaiSublimeTheme,
                        ),
                        child: CodeField(
                          key: ValueKey(tab.id),
                          controller: tab.controller,
                          expands: true,
                          wrap: false,
                          padding: const EdgeInsets.all(12),
                          textStyle: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                          gutterStyle: const GutterStyle(
                            showLineNumbers: true,
                            showErrors: true,
                            showFoldingHandles: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              color: const Color(0xFF151C30),
              child: Row(
                children: [
                  const Icon(
                    Icons.circle,
                    color: Colors.green,
                    size: 9,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  Text(
                    tab.language,
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    tab.isSaved ? 'محفوظ' : 'غير محفوظ',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget toolButton(
    IconData icon,
    String label,
    VoidCallback action,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: const Color(0xFF38BDF8),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

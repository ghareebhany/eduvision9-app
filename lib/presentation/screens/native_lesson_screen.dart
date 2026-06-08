// ----------------------------------------------------------------------------
//  NativeLessonScreen — مشغل فيديو مستقل
//
//  الفكرة: بدلاً من youtube_player_iframe الذي يُنتج origin=null ويسبب
//  خطأ YouTube 150/152، نستخدم WebView يُحمّل endpoint مخصص من الـ API:
//
//    GET /wp-json/app/v1/lesson-view/{lessonId}?token={jwt}
//
//  هذا الـ endpoint (video_player.php) يُرجع HTML كاملة:
//    • Plyr.js + YouTube IFrame بـ origin=home_url() الصحيح
//    • youtube-nocookie.com + referrerpolicy صحيح
//    • يتواصل مع Flutter عبر AppChannel.postMessage()
//
//  الفرق عن webview_lesson_screen القديم:
//    • يُحمّل PLAYER فقط (HTML نظيفة) وليس صفحة الموقع الكاملة
//    • يستقبل أحداث: ready / play / pause / ended / time:{n}
//    • يُشغّل تسجيل الإكمال + التنقل بين الدروس من Flutter
//    • أزرار تحكم إضافية (السابق/التالي/قائمة الدروس) من Flutter
// ----------------------------------------------------------------------------

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/secure_storage.dart';
import '../../core/widgets/secure_screen.dart';
import '../../domain/entities/lesson.dart';
import '../providers/di_providers.dart';
import '../screens/video_progress_service.dart';

// ----------------------------------------------------------------------------
class NativeLessonScreen extends ConsumerStatefulWidget {
  final Lesson lesson;
  final int courseId;
  final List<Lesson> allLessons;

  const NativeLessonScreen({
    super.key,
    required this.lesson,
    required this.courseId,
    required this.allLessons,
  });

  @override
  ConsumerState<NativeLessonScreen> createState() => _NativeLessonScreenState();
}

class _NativeLessonScreenState extends ConsumerState<NativeLessonScreen> {
  late Lesson _current;
  bool _completionFired = false;
  bool _isFullscreen    = false;

  @override
  void initState() {
    super.initState();
    _current = widget.lesson;
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _switchLesson(Lesson lesson) {
    if (lesson.id == _current.id) return;
    setState(() {
      _current = lesson;
      _completionFired = false;
    });
  }

  Future<void> _handleCompletion() async {
    if (_completionFired) return;
    _completionFired = true;

    await ref
        .read(markLessonCompleteUseCaseProvider)
        .call(_current.id, widget.courseId);
    await VideoProgressService.instance.clearPosition(_current.id);

    if (!mounted) return;
    await _moveToNextLesson();
  }

  Future<void> _moveToNextLesson() async {
    final idx = widget.allLessons.indexWhere((l) => l.id == _current.id);
    final next = (idx >= 0 && idx + 1 < widget.allLessons.length)
        ? widget.allLessons[idx + 1]
        : null;

    if (next != null) {
      _switchLesson(next);
    } else {
      await ref.read(markCourseCompleteUseCaseProvider).call(widget.courseId);
      if (mounted) _showCourseComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lessons = widget.allLessons;
    final idx     = lessons.indexWhere((l) => l.id == _current.id);
    final hasPrev = idx > 0;
    final hasNext = idx >= 0 && idx + 1 < lessons.length;

    // Fullscreen: WebView يملأ الشاشة كاملاً — بدون AppBar أو NavBar
    if (_isFullscreen) {
      return SecureScreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _PlayerArea(
            key: ValueKey(_current.id),
            lesson: _current,
            isFullscreen: true,
            onCompleted: _handleCompletion,
            onFullscreenChanged: (v) => setState(() => _isFullscreen = v),
          ),
        ),
      );
    }

    // Portrait: التخطيط الاعتيادي
    return SecureScreen(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            _buildAppBar(),

            // -- منطقة المشغل ---------------------------------------------
            _PlayerArea(
              key: ValueKey(_current.id),
              lesson: _current,
              isFullscreen: false,
              onCompleted: _handleCompletion,
              onFullscreenChanged: (v) => setState(() => _isFullscreen = v),
            ),

            // -- محتوى نصي (إن وجد وليس فيديو) ---------------------------
            if (!_current.hasVideo && _current.content.isNotEmpty)
              Expanded(
                child: Container(
                  color: const Color(0xFF111111),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _current.content,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.7,
                        fontFamily: 'Cairo',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ),
              )
            else
              const Expanded(child: SizedBox()),

            _buildNavBar(lessons, idx, hasPrev, hasNext),
          ],
        ),
      ),
    );
  }

  // -- App Bar ----------------------------------------------------------------
  Widget _buildAppBar() {
    return Container(
      color: AppPalette.mocha,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: Text(
                _current.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.list_rounded, color: Colors.white),
              onPressed: _showLessonsList,
            ),
          ],
        ),
      ),
    );
  }

  // -- شريط التنقل بين الدروس ------------------------------------------------
  Widget _buildNavBar(
      List<Lesson> lessons, int idx, bool hasPrev, bool hasNext) {
    return Container(
      color: AppPalette.mocha,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 4,
        top: 4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: hasPrev ? () => _switchLesson(lessons[idx - 1]) : null,
            icon: Icon(Icons.skip_previous_rounded,
                color: hasPrev ? AppPalette.coral : Colors.grey),
            label: Text('السابق',
                style: TextStyle(
                    color: hasPrev ? AppPalette.coral : Colors.grey)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppPalette.plum.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${idx + 1} / ${lessons.length}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          TextButton.icon(
            onPressed: hasNext ? () => _switchLesson(lessons[idx + 1]) : null,
            label: Text('التالي',
                style: TextStyle(
                    color: hasNext ? AppPalette.coral : Colors.grey)),
            icon: Icon(Icons.skip_next_rounded,
                color: hasNext ? AppPalette.coral : Colors.grey),
          ),
        ],
      ),
    );
  }

  // -- قائمة الدروس ----------------------------------------------------------
  void _showCourseComplete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppPalette.mocha,
        title: const Text('تهانينا 🎉',
            style: TextStyle(color: Colors.white)),
        content: const Text('أنهيت جميع دروس الكورس بنجاح',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('رجوع',
                style: TextStyle(color: AppPalette.coral)),
          ),
        ],
      ),
    );
  }

  void _showLessonsList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a1a),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => ListView.builder(
        itemCount: widget.allLessons.length,
        itemBuilder: (_, i) {
          final l = widget.allLessons[i];
          final isCurrent = l.id == _current.id;
          return ListTile(
            leading: Icon(
              l.isQuiz
                  ? Icons.quiz_rounded
                  : l.hasVideo
                      ? Icons.play_circle_outline_rounded
                      : Icons.article_rounded,
              color: isCurrent ? AppPalette.coral : Colors.white54,
              size: 20,
            ),
            title: Text(
              l.title,
              style: TextStyle(
                color: isCurrent ? AppPalette.coral : Colors.white,
                fontWeight:
                    isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
              textDirection: TextDirection.rtl,
            ),
            subtitle: l.videoDuration.isNotEmpty
                ? Text(l.videoDuration,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12))
                : null,
            trailing: l.isCompleted
                ? const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 18)
                : null,
            onTap: () {
              Navigator.pop(context);
              _switchLesson(l);
            },
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------------------------------
//  _PlayerArea
//  يستخدم WebView لتحميل HTML endpoint الخاص بالإضافة
//  هذا يضمن أن YouTube يرى origin صحيح (home_url الموقع)
//  وتعمل نفس آلية Plyr الموجودة في الموقع بالضبط
// ----------------------------------------------------------------------------
class _PlayerArea extends StatefulWidget {
  final Lesson lesson;
  final VoidCallback onCompleted;
  final ValueChanged<bool> onFullscreenChanged;
  final bool isFullscreen;

  const _PlayerArea({
    super.key,
    required this.lesson,
    required this.onCompleted,
    required this.onFullscreenChanged,
    required this.isFullscreen,
  });

  @override
  State<_PlayerArea> createState() => _PlayerAreaState();
}

class _PlayerAreaState extends State<_PlayerArea> {
  WebViewController? _ctrl;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    // -- جلب الـ JWT token --------------------------------------------------
    final token = await SecureStorageService.instance.getToken() ?? '';

    if (!mounted) return;

    // -- تحديد الـ URL ------------------------------------------------------
    // lesson-view endpoint يُرجع HTML Plyr player مع origin صحيح
    // YouTube يقبله لأن origin = home_url() الموقع وليس "null"
    final url = '${ApiConstants.lessonViewUrl(widget.lesson.id)}'
        '${token.isNotEmpty ? "?token=${Uri.encodeComponent(token)}" : ""}';

    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)

      // -- استقبال أحداث Plyr من HTML ------------------------------------
      // video_player.php يُرسل: ready / play / pause / ended / time:{n} / no_video
      ..addJavaScriptChannel(
        'AppChannel',
        onMessageReceived: (msg) => _onPlayerEvent(msg.message),
      )
      // اسم بديل للتوافق (بعض الأجهزة)
      ..addJavaScriptChannel(
        'VideoEvents',
        onMessageReceived: (msg) => _onPlayerEvent(msg.message),
      )

      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() { _loading = true; _error = null; });
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (e) {
          if (mounted) {
            setState(() {
              _loading = false;
              _error = 'تعذّر تحميل المشغّل (${e.errorCode})';
            });
          }
        },
      ))

      ..loadRequest(Uri.parse(url));

    // -- إعدادات خاصة بـ Android -------------------------------------------
    if (ctrl.platform is AndroidWebViewController) {
      final android = ctrl.platform as AndroidWebViewController;
      await android.setMediaPlaybackRequiresUserGesture(false);
    }

    if (mounted) setState(() => _ctrl = ctrl);
  }

  // -- معالجة أحداث Plyr -----------------------------------------------------
  void _onPlayerEvent(String event) {
    if (!mounted) return;

    switch (event) {
      case 'ready':
        break;

      case 'no_video':
        break;

      case 'play':
        break;

      case 'pause':
        break;

      case 'ended':
        widget.onCompleted();
        break;

      // -- Fullscreen: _PlayerArea يُبلّغ الـ parent فقط ------------------
      // الـ parent (_NativeLessonScreenState) هو المصدر الوحيد للحالة
      case 'fullscreen:enter':
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        widget.onFullscreenChanged(true);   // ← parent يُعيد build
        break;

      case 'fullscreen:exit':
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        widget.onFullscreenChanged(false);  // ← parent يُعيد build
        break;

      default:
        if (event.startsWith('time:')) {
          final secs = int.tryParse(event.substring(5));
          if (secs != null) {
            VideoProgressService.instance.savePosition(
                widget.lesson.id, secs);
          }
        }
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFullscreen) {
      // SizedBox.expand: لا حسابات — يملأ المساحة المتاحة فعلاً
      // آمن عبر كل الأجهزة بما فيها Samsung و Xiaomi notch screens
      return SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
        children: [
          // -- WebView المشغّل ----------------------------------------------
          if (_ctrl != null)
            Positioned.fill(child: WebViewWidget(controller: _ctrl!)),

          // -- مؤشر التحميل ------------------------------------------------
          if (_loading)
            Container(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppPalette.coral),
                ),
              ),
            ),

          // -- رسالة خطأ ---------------------------------------------------
          if (_error != null && !_loading)
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 40),
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _ctrl = null;
                          _error = null;
                        });
                        _initWebView();
                      },
                      child: Text('إعادة المحاولة',
                          style:
                              TextStyle(color: AppPalette.coral)),
                    ),
                  ],
                ),
              ),
            ),

        ],
      ),
    ); // SizedBox.expand fullscreen
    }

    // Portrait: نسبة 16:9 ثابتة
    final w = MediaQuery.of(context).size.width;
    return SizedBox(
      width:  w,
      height: w * 9 / 16,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_ctrl != null)
            Positioned.fill(child: WebViewWidget(controller: _ctrl!)),
          if (_loading)
            const ColoredBox(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFe52027), strokeWidth: 2.5),
              ),
            ),
        ],
      ),
    );
  }

}

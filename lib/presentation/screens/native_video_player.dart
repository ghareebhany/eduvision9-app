import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../domain/entities/lesson.dart';
import '../providers/di_providers.dart';
import 'video_progress_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// الشاشة الرئيسية: تقرر نوع المشغّل وتبني قائمة الدروس
// ══════════════════════════════════════════════════════════════════════════════

class NativeVideoPlayerScreen extends ConsumerStatefulWidget {
  final Lesson lesson;
  final int courseId;
  final List<Lesson> allLessons;

  const NativeVideoPlayerScreen({
    super.key,
    required this.lesson,
    required this.courseId,
    required this.allLessons,
  });

  @override
  ConsumerState<NativeVideoPlayerScreen> createState() =>
      _NativeVideoPlayerScreenState();
}

class _NativeVideoPlayerScreenState
    extends ConsumerState<NativeVideoPlayerScreen> {
  late Lesson _current;
  bool _completionFired = false;

  // key لإعادة بناء المشغّل عند تغيير الدرس
  Key _playerKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _current = widget.lesson;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _switchLesson(Lesson lesson) {
    setState(() {
      _current          = lesson;
      _completionFired  = false;
      _playerKey        = UniqueKey(); // يُجبر Flutter على بناء مشغّل جديد
    });
  }

  Future<void> _handleEnded() async {
    if (_completionFired) return;
    _completionFired = true;

    await ref
        .read(markLessonCompleteUseCaseProvider)
        .call(_current.id, widget.courseId);
    await VideoProgressService.instance.clearPosition(_current.id);
    if (!mounted) return;

    final idx  = widget.allLessons.indexWhere((l) => l.id == _current.id);
    final next = (idx >= 0 && idx + 1 < widget.allLessons.length)
        ? widget.allLessons[idx + 1]
        : null;

    if (next != null && next.hasVideo) {
      _switchLesson(next);
    } else if (next != null) {
      _switchLesson(next);
    } else {
      await ref.read(markCourseCompleteUseCaseProvider).call(widget.courseId);
      if (mounted) _showCourseComplete();
    }
  }

  void _handleTimeUpdate(int sec) {
    VideoProgressService.instance.savePosition(_current.id, sec);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a1a),
        foregroundColor: Colors.white,
        title: Text(
          _current.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                '${widget.allLessons.indexWhere((l) => l.id == _current.id) + 1}'
                '/${widget.allLessons.length}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── منطقة المشغّل ─────────────────────────────────────────────────
          _buildPlayer(),

          // ── قائمة الدروس ──────────────────────────────────────────────────
          Expanded(
            child: Container(
              color: theme.scaffoldBackgroundColor,
              child: _LessonsList(
                lessons:    widget.allLessons,
                currentId:  _current.id,
                onTap:      _switchLesson,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    // يوتيوب
    if (_current.isYoutube) {
      final ytId = _extractYoutubeId(_current.videoUrl);
      if (ytId.isNotEmpty) {
        return _YoutubeNativePlayer(
          key:          _playerKey,
          videoId:      ytId,
          onEnded:      _handleEnded,
          onTimeUpdate: _handleTimeUpdate,
        );
      }
    }

    // HTML5 / External URL
    if (_current.videoUrl.isNotEmpty &&
        (_current.videoSource == 'html5' ||
         _current.videoSource == 'external_url' ||
         _current.videoUrl.endsWith('.mp4') ||
         _current.videoUrl.endsWith('.m3u8'))) {
      return _Html5NativePlayer(
        key:          _playerKey,
        videoUrl:     _current.videoUrl,
        posterUrl:    '', // يمكن إضافة poster لاحقاً من lesson_model
        onEnded:      _handleEnded,
        onTimeUpdate: _handleTimeUpdate,
      );
    }

    // لا يوجد فيديو مدعوم
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 40),
            const SizedBox(height: 10),
            Text(
              'نوع الفيديو غير مدعوم (${_current.videoSource})',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ]),
        ),
      ),
    );
  }

  void _showCourseComplete() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.emoji_events_rounded, size: 56, color: Colors.amber),
        title: const Text('🎉 أتممت الدورة!', textAlign: TextAlign.center),
        content: const Text(
          'لقد أكملت جميع دروس هذه الدورة بنجاح',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('العودة للدورة'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// مشغّل يوتيوب الأصلي — youtube_player_iframe
// نفس الآلية التي يستخدمها Plyr: controls=0 + overlay مخصّص
// ══════════════════════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════════════════════
// مشغّل يوتيوب — WebViewController + HTML يبني نفس iframe Plyr بالضبط
// السر: origin + widget_referrer = eduvision3.com تماماً كما يفعل Plyr
// ══════════════════════════════════════════════════════════════════════════════

class _YoutubeNativePlayer extends StatefulWidget {
  final String videoId;
  final VoidCallback onEnded;
  final Function(int) onTimeUpdate;

  const _YoutubeNativePlayer({
    super.key,
    required this.videoId,
    required this.onEnded,
    required this.onTimeUpdate,
  });

  @override
  State<_YoutubeNativePlayer> createState() => _YoutubeNativePlayerState();
}

class _YoutubeNativePlayerState extends State<_YoutubeNativePlayer> {
  late final WebViewController _wvc;
  Timer? _hideTimer;
  Timer? _syncTimer;
  bool   _showControls = true;
  bool   _playerReady  = false;
  bool   _isPlaying    = false;
  bool   _hasEnded     = false;
  int    _currentSec   = 0;
  int    _totalSec     = 0;

  // domain الموقع — نفس ما يُرسله Plyr كـ origin و widget_referrer
  static const _siteOrigin = 'https://eduvision3.com';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() async {
    _wvc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _startSyncTimer(),
      ))
      ..addJavaScriptChannel(
        'PlayerBridge',
        onMessageReceived: (msg) => _onBridgeMessage(msg.message),
      );

    // ✅ تمكين autoplay بدون user gesture على Android
    final platform = _wvc.platform;
    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(false);
    }

    // ✅ baseUrl = eduvision3.com يُعطي الصفحة origin حقيقي
    // YouTube IFrame API تتحقق من origin وتسمح بالتشغيل
    await _wvc.loadHtmlString(
      _buildPlayerHtml(widget.videoId),
      baseUrl: _siteOrigin,
    );
  }

  // ── يبني HTML بنفس iframe params التي يستخدمها Plyr ──
  // ✅ youtube-nocookie.com = لا قيود تضمين، لا تحقق من origin
  // هذا بالضبط ما يفعله Plyr عند noCookie:true
  // ✅ الطريقة الصحيحة لـ YouTube IFrame API:
  //    div فارغ → API تبني الـ iframe بنفسها → لا تعارض
  //    baseUrl في loadHtmlString يُعطي origin حقيقي
  String _buildPlayerHtml(String videoId) {
    return '''<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<style>
* { margin:0; padding:0; box-sizing:border-box; }
html, body { width:100%; height:100%; background:#000; overflow:hidden; }
#player { width:100%; height:100%; }
</style>
</head>
<body>
<div id="player"></div>
<script>
var tag = document.createElement('script');
tag.src = 'https://www.youtube.com/iframe_api';
document.head.appendChild(tag);

var player;
function onYouTubeIframeAPIReady() {
  player = new YT.Player('player', {
    videoId: '$videoId',
    playerVars: {
      autoplay:       1,
      controls:       0,
      disablekb:      1,
      playsinline:    1,
      rel:            0,
      showinfo:       0,
      iv_load_policy: 3,
      modestbranding: 1,
      origin:         '$_siteOrigin'
    },
    events: {
      onReady:       onPlayerReady,
      onStateChange: onPlayerStateChange,
      onError:       onPlayerError,
    }
  });
}

function onPlayerReady(e) {
  PlayerBridge.postMessage(JSON.stringify({
    type:'ready', duration: player.getDuration()
  }));
}

function onPlayerStateChange(e) {
  if      (e.data === 0) PlayerBridge.postMessage(JSON.stringify({type:'ended'}));
  else if (e.data === 1) PlayerBridge.postMessage(JSON.stringify({type:'playing'}));
  else if (e.data === 2) PlayerBridge.postMessage(JSON.stringify({type:'paused'}));
}

function onPlayerError(e) {
  PlayerBridge.postMessage(JSON.stringify({type:'error', code:e.data}));
}

function playVideo()      { if(player) player.playVideo(); }
function pauseVideo()     { if(player) player.pauseVideo(); }
function seekTo(sec)      { if(player) player.seekTo(sec, true); }
function getCurrentTime() { return player ? player.getCurrentTime() : 0; }
function getDuration()    { return player ? player.getDuration() : 0; }
</script>
</body>
</html>''';
  }

  void _onBridgeMessage(String msg) {
    if (!mounted) return;
    try {
      final data = _parseJson(msg);
      final type = data['type'] as String? ?? '';
      switch (type) {
        case 'ready':
          final dur = (data['duration'] as num?)?.toInt() ?? 0;
          setState(() {
            _playerReady = true;
            if (dur > 0) _totalSec = dur;
          });
          _scheduleHide();
        case 'playing':
          setState(() => _isPlaying = true);
        case 'paused':
          setState(() => _isPlaying = false);
        case 'ended':
          if (!_hasEnded) {
            _hasEnded = true;
            widget.onEnded();
          }
        case 'error':
          final code = (data['code'] as num?)?.toInt() ?? -1;
          debugPrint('❌ YouTube player error code: $code');
          // أظهر المشغّل على أي حال حتى لا تبقى شاشة التحميل
          if (!_playerReady && mounted) setState(() => _playerReady = true);
        case 'time':
          final sec = (data['current'] as num?)?.toInt() ?? 0;
          final dur = (data['duration'] as num?)?.toInt() ?? 0;
          if (sec != _currentSec || (_totalSec == 0 && dur > 0)) {
            setState(() {
              _currentSec = sec;
              if (dur > 0) _totalSec = dur;
            });
            widget.onTimeUpdate(sec);
          }
      }
    } catch (_) {}
  }

  Map<String, dynamic> _parseJson(String s) {
    // استخراج بسيط بدون dart:convert (تجنب import إضافي)
    final result = <String, dynamic>{};
    final typeMatch = RegExp(r'"type"\s*:\s*"([^"]+)"').firstMatch(s);
    if (typeMatch != null) result['type'] = typeMatch.group(1);
    final numMatches = RegExp(r'"(\w+)"\s*:\s*([\d.]+)').allMatches(s);
    for (final m in numMatches) {
      result[m.group(1)!] = double.tryParse(m.group(2)!) ?? 0;
    }
    return result;
  }

  // مزامنة الوقت كل ثانية عبر JS
  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_playerReady) return;
      _wvc.runJavaScript('''
        (function() {
          var cur = getCurrentTime();
          var dur = getDuration();
          PlayerBridge.postMessage(JSON.stringify({
            type: "time", current: Math.floor(cur), duration: Math.floor(dur)
          }));
        })();
      ''');
    });
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  void _seek(int delta) {
    final target = (_currentSec + delta).clamp(0, _totalSec);
    _wvc.runJavaScript('seekTo($target);');
    setState(() { _currentSec = target; _showControls = true; });
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalSec > 0
        ? (_currentSec / _totalSec).clamp(0.0, 1.0)
        : 0.0;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [

            // ── WebView يحمل HTML مع YouTube iframe ──────────────────────
            WebViewWidget(controller: _wvc),

            // ── شاشة التحميل حتى يُرسل JS حدث ready ─────────────────────
            if (!_playerReady)
              const ColoredBox(
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFe52027), strokeWidth: 2.5,
                  ),
                ),
              ),

            // ── overlay التحكم المخصّص ────────────────────────────────────
            if (_playerReady)
              AnimatedOpacity(
                opacity:  _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: _VideoOverlay(
                  isPlaying:  _isPlaying,
                  currentSec: _currentSec,
                  totalSec:   _totalSec,
                  progress:   progress,
                  onPlayPause: () {
                    if (_isPlaying) {
                      _wvc.runJavaScript('pauseVideo();');
                    } else {
                      _wvc.runJavaScript('playVideo();');
                    }
                    setState(() => _showControls = true);
                    _scheduleHide();
                  },
                  onSeekBack:    () => _seek(-10),
                  onSeekForward: () => _seek(10),
                  onSliderChange: (v) {
                    final t = (v * _totalSec).toInt();
                    _wvc.runJavaScript('seekTo($t);');
                    setState(() => _currentSec = t);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// مشغّل HTML5 الأصلي — video_player + chewie overlay مخصّص
// ══════════════════════════════════════════════════════════════════════════════

class _Html5NativePlayer extends StatefulWidget {
  final String videoUrl;
  final String posterUrl;
  final VoidCallback onEnded;
  final Function(int) onTimeUpdate;

  const _Html5NativePlayer({
    super.key,
    required this.videoUrl,
    required this.posterUrl,
    required this.onEnded,
    required this.onTimeUpdate,
  });

  @override
  State<_Html5NativePlayer> createState() => _Html5NativePlayerState();
}

class _Html5NativePlayerState extends State<_Html5NativePlayer> {
  VideoPlayerController? _vpc;
  bool    _initialized  = false;
  bool    _hasError     = false;
  bool    _hasEnded     = false;
  bool    _showControls = true;
  Timer?  _hideTimer;
  Timer?  _progressTimer;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await ctrl.initialize();
      if (!mounted) { ctrl.dispose(); return; }

      ctrl.addListener(_onPlayerUpdate);
      await ctrl.play();

      setState(() {
        _vpc         = ctrl;
        _initialized = true;
      });

      _scheduleHide();
      _startProgressTimer();
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onPlayerUpdate() {
    if (_vpc == null || !mounted) return;
    final pos = _vpc!.value.position;
    final dur = _vpc!.value.duration;
    if (dur.inSeconds > 0 &&
        pos.inSeconds >= dur.inSeconds - 1 &&
        !_hasEnded) {
      _hasEnded = true;
      widget.onEnded();
    }
  }

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_vpc == null || !mounted) return;
      final sec = _vpc!.value.position.inSeconds;
      widget.onTimeUpdate(sec);
    });
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  void _seek(int deltaSec) {
    if (_vpc == null) return;
    final cur    = _vpc!.value.position.inSeconds;
    final dur    = _vpc!.value.duration.inSeconds;
    final target = (cur + deltaSec).clamp(0, dur);
    _vpc!.seekTo(Duration(seconds: target));
    setState(() => _showControls = true);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _vpc?.removeListener(_onPlayerUpdate);
    _vpc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 36),
              const SizedBox(height: 8),
              const Text('تعذّر تحميل الفيديو',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  setState(() { _hasError = false; _initialized = false; });
                  _initPlayer();
                },
                icon: const Icon(Icons.refresh, color: Color(0xFFe52027)),
                label: const Text('إعادة المحاولة',
                    style: TextStyle(color: Color(0xFFe52027))),
              ),
            ]),
          ),
        ),
      );
    }

    if (!_initialized || _vpc == null) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(
              color: Color(0xFFe52027), strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _vpc!,
        builder: (_, value, __) {
          final isPlaying  = value.isPlaying;
          final currentSec = value.position.inSeconds;
          final totalSec   = value.duration.inSeconds;
          final progress   = totalSec > 0
              ? (currentSec / totalSec).clamp(0.0, 1.0)
              : 0.0;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── الفيديو ────────────────────────────────────────────────
                VideoPlayer(_vpc!),

                // ── الـ overlay المخصّص ────────────────────────────────────
                AnimatedOpacity(
                  opacity:  _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: _VideoOverlay(
                    isPlaying:    isPlaying,
                    currentSec:   currentSec,
                    totalSec:     totalSec,
                    progress:     progress,
                    onPlayPause: () {
                      isPlaying ? _vpc!.pause() : _vpc!.play();
                      setState(() => _showControls = true);
                      _scheduleHide();
                    },
                    onSeekBack:    () => _seek(-10),
                    onSeekForward: () => _seek(10),
                    onSliderChange: (v) {
                      final t = (v * totalSec).toInt();
                      _vpc!.seekTo(Duration(seconds: t));
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// الـ Overlay المشترك — نفس تصميم Plyr
// يُستخدم من كلا المشغّلَين (YouTube و HTML5)
// ══════════════════════════════════════════════════════════════════════════════

class _VideoOverlay extends StatelessWidget {
  final bool isPlaying;
  final int  currentSec;
  final int  totalSec;
  final double progress;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final ValueChanged<double> onSliderChange;

  const _VideoOverlay({
    required this.isPlaying,
    required this.currentSec,
    required this.totalSec,
    required this.progress,
    required this.onPlayPause,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onSliderChange,
  });

  String _fmt(int s) {
    final h   = s ~/ 3600;
    final m   = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2,'0')}:'
             '${m.toString().padLeft(2,'0')}:'
             '${sec.toString().padLeft(2,'0')}';
    }
    return '${m.toString().padLeft(2,'0')}:'
           '${sec.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [
            Color(0xBB000000),
            Color(0x00000000),
            Color(0x00000000),
            Color(0xCC000000),
          ],
          stops: [0.0, 0.25, 0.72, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          const SizedBox(height: 4),

          // ── أزرار التحكم الوسطى ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CtrlBtn(Icons.replay_10_rounded, onTap: onSeekBack),
              const SizedBox(width: 28),
              _CtrlBtn(
                isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                size: 62,
                onTap: onPlayPause,
              ),
              const SizedBox(width: 28),
              _CtrlBtn(Icons.forward_10_rounded, onTap: onSeekForward),
            ],
          ),

          // ── شريط التقدم + الوقت ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor:   const Color(0xFFe52027),
                    inactiveTrackColor: Colors.white30,
                    thumbColor:         const Color(0xFFe52027),
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6),
                    trackHeight:  3,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value:     progress.clamp(0.0, 1.0),
                    onChanged: onSliderChange,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(currentSec),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                      Text(_fmt(totalSec),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData     icon;
  final double       size;
  final VoidCallback onTap;

  const _CtrlBtn(this.icon, {required this.onTap, this.size = 38});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Icon(icon, color: Colors.white, size: size,
        shadows: const [Shadow(color: Colors.black54, blurRadius: 8)]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// قائمة الدروس المضمّنة في الأسفل
// ══════════════════════════════════════════════════════════════════════════════

class _LessonsList extends StatelessWidget {
  final List<Lesson>     lessons;
  final int              currentId;
  final ValueChanged<Lesson> onTap;

  const _LessonsList({
    required this.lessons,
    required this.currentId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      itemCount: lessons.length,
      itemBuilder: (_, i) {
        final l         = lessons[i];
        final isCurrent = l.id == currentId;
        return ListTile(
          dense: true,
          tileColor: isCurrent
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
          leading: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrent
                  ? theme.colorScheme.primary
                  : l.isCompleted
                      ? Colors.green.withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerHighest,
            ),
            child: Icon(
              isCurrent
                  ? Icons.play_arrow_rounded
                  : l.isCompleted
                      ? Icons.check_rounded
                      : Icons.play_arrow_rounded,
              color: isCurrent
                  ? Colors.white
                  : l.isCompleted
                      ? Colors.green
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              size: 16,
            ),
          ),
          title: Text(
            l.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize:   13,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color:      isCurrent ? theme.colorScheme.primary : null,
            ),
          ),
          subtitle: l.videoDuration.isNotEmpty
              ? Text(l.videoDuration,
                  style: const TextStyle(fontSize: 11))
              : null,
          onTap: (!isCurrent) ? () => onTap(l) : null,
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// مساعد: استخراج YouTube ID من الـ URL
// ══════════════════════════════════════════════════════════════════════════════

String _extractYoutubeId(String url) {
  if (url.isEmpty) return '';
  // ID مباشر (11 حرف بدون https)
  if (!url.contains('/') && !url.contains('.') && url.length == 11) return url;
  // youtu.be/ID
  final short = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})').firstMatch(url);
  if (short != null) {
    final result = short.group(1)!;
    debugPrint('🔍 extractYoutubeId input: $url → output: $result');
    return result;
  }
  // youtube.com/watch?v=ID أو /embed/ID أو /shorts/ID
  final long  = RegExp(r'(?:v=|embed/|shorts/)([a-zA-Z0-9_-]{11})')
      .firstMatch(url);
  if (long  != null) {
    final result = long.group(1)!;
    debugPrint('🔍 extractYoutubeId input: $url → output: $result');
    return result;
  }
  debugPrint('🔍 extractYoutubeId input: $url → output: (empty)');
  return '';
}

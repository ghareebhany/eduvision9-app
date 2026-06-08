import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_widget.dart';
import '../providers/dashboard_provider.dart';

// ── Shadow helper ─────────────────────────────────────────────────────────────
BoxShadow _shadow(double blur,
        {Color base = Colors.black, double opacity = 0.08}) =>
    BoxShadow(
        color: base.withValues(alpha: opacity),
        blurRadius: blur,
        offset: Offset(0, blur * 0.4));

// ══════════════════════════════════════════════════════════════════════════════
//  My Courses Screen
// ══════════════════════════════════════════════════════════════════════════════
class MyCoursesScreen extends ConsumerStatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  ConsumerState<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends ConsumerState<MyCoursesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  static const _tabs = [
    (label: 'الكل', status: 'all'),
    (label: 'قيد التعلم', status: 'active'),
    (label: 'المكتملة', status: 'completed'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sage100,
      body: Column(children: [
        _MyCoursesHeader(tabCtrl: _tabCtrl, tabs: _tabs),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children:
                _tabs.map((t) => _CoursesList(status: t.status)).toList(),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Header — gradient فاخر مع TabBar
// ══════════════════════════════════════════════════════════════════════════════
class _MyCoursesHeader extends StatelessWidget {
  final TabController tabCtrl;
  final List<({String label, String status})> tabs;
  const _MyCoursesHeader({required this.tabCtrl, required this.tabs});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.mocha900, AppTheme.mocha800, AppTheme.mocha500],
            stops: [0.0, 0.55, 1.0],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Stack(children: [
          // ── Deco elements ────────────────────────────────────────────
          Positioned(
              top: -30, right: -20,
              child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppPalette.coral.withValues(alpha: 0.07)))),
          Positioned(
              top: 30, right: 70,
              child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppPalette.peach.withValues(alpha: 0.10)))),
          Positioned(
              bottom: -10, left: -15,
              child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppPalette.plum.withValues(alpha: 0.20)))),

          SafeArea(
            bottom: false,
            child: Column(children: [
              // ── Title row ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppTheme.buttonGradient,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        _shadow(12,
                            base: AppPalette.coral, opacity: 0.4),
                      ],
                    ),
                    child: const Icon(Icons.menu_book_rounded,
                        color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('دوراتي',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3)),
                      SizedBox(height: 1),
                      Text('تابع مسيرتك التعليمية',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12)),
                    ],
                  ),
                ]),
              ),

              // ── TabBar ─────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: TabBar(
                  controller: tabCtrl,
                  tabs: tabs.map((t) => Tab(
                    child: Text(t.label,
                        style: const TextStyle(fontSize: 13)),
                  )).toList(),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.45),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                  unselectedLabelStyle:
                      const TextStyle(fontWeight: FontWeight.w500),
                  indicator: BoxDecoration(
                    gradient: AppTheme.buttonGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      _shadow(8,
                          base: AppPalette.coral, opacity: 0.35),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                ),
              ),
              const SizedBox(height: 10),
            ]),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  Courses List
// ══════════════════════════════════════════════════════════════════════════════
class _CoursesList extends ConsumerStatefulWidget {
  final String status;
  const _CoursesList({required this.status});

  @override
  ConsumerState<_CoursesList> createState() => _CoursesListState();
}

class _CoursesListState extends ConsumerState<_CoursesList> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final filter = MyCoursesFilter(status: widget.status, page: _page);
    final async  = ref.watch(myCourseItemsProvider(filter));

    return async.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppPalette.coral)),
      error: (e, _) => AppErrorWidget(
        message: e.toString().replaceAll('Exception: ', ''),
        onRetry: () => ref.invalidate(myCourseItemsProvider(filter)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return _EmptyState(status: widget.status);
        }

        return RefreshIndicator(
          color: AppPalette.coral,
          onRefresh: () async =>
              ref.invalidate(myCourseItemsProvider(filter)),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (_, i) => _MyCourseCard(item: items[i]),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Empty State
// ══════════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final String status;
  const _EmptyState({required this.status});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppPalette.plum.withValues(alpha: 0.10),
                AppPalette.coral.withValues(alpha: 0.07),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            status == 'completed'
                ? Icons.verified_rounded
                : Icons.menu_book_outlined,
            size: 48,
            color: AppPalette.plum.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          status == 'completed'
              ? 'لم تكمل أي دورة بعد'
              : status == 'active'
                  ? 'لا توجد دورات قيد التعلم'
                  : 'لم تسجّل في أي دورة بعد',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppPalette.mocha.withValues(alpha: 0.6)),
          textAlign: TextAlign.center,
        ),
        if (status == 'all') ...[
          const SizedBox(height: 8),
          Text('ابدأ رحلتك التعليمية واكتشف أفضل الدورات',
              style: TextStyle(
                  fontSize: 13,
                  color: AppPalette.mocha.withValues(alpha: 0.4)),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.go('/courses'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppPalette.btnGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  _shadow(14,
                      base: AppPalette.coral, opacity: 0.30)
                ],
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.explore_rounded,
                    color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('تصفح الدورات',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ]),
            ),
          ),
        ],
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  Course Card — horizontal layout فاخر
// ══════════════════════════════════════════════════════════════════════════════
class _MyCourseCard extends StatefulWidget {
  final MyCourseItem item;
  const _MyCourseCard({required this.item});

  @override
  State<_MyCourseCard> createState() => _MyCourseCardState();
}

class _MyCourseCardState extends State<_MyCourseCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final course      = widget.item.course;
    final isCompleted = widget.item.isCourseCompleted;
    final pct         = widget.item.completedPercent;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        context.push(isCompleted
            ? '/course/${course.id}'
            : '/lessons/${course.id}');
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isCompleted
                  ? AppPalette.successGreen.withValues(alpha: 0.35)
                  : AppPalette.sage.withValues(alpha: 0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isCompleted
                        ? AppPalette.successGreen
                        : AppPalette.mocha)
                    .withValues(alpha: 0.09),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Thumbnail ────────────────────────────────────────────
              Stack(children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(21)),
                  child: course.thumbnail.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: course.thumbnail,
                          height: 155,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _ThumbFallback(isCompleted: isCompleted))
                      : _ThumbFallback(isCompleted: isCompleted),
                ),

                // Vignette
                Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                        height: 70,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                              Colors.transparent,
                              AppPalette.mocha.withValues(alpha: 0.6),
                            ])))),

                // Completed badge
                if (isCompleted)
                  Positioned(
                      top: 11, left: 11,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: AppPalette.successGreen,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: AppPalette.successGreen
                                      .withValues(alpha: 0.45),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3))
                            ]),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_rounded,
                                  color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text('مكتملة',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold)),
                            ]),
                      )),

                // Lesson count
                Positioned(
                    bottom: 9, right: 11,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_circle_outline_rounded,
                                size: 11, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('${course.totalLessons} درس',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold)),
                          ]),
                    )),

                // Progress indicator strip على الصورة مباشرة
                if (!isCompleted)
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppPalette.coral),
                    ),
                  ),
              ]),

              // ── Info ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: AppPalette.mocha,
                          height: 1.35)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.person_outline,
                        size: 13,
                        color: AppPalette.plum.withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(course.instructorName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: AppPalette.mocha.withValues(alpha: 0.5))),
                    ),
                  ]),

                  const SizedBox(height: 13),

                  // ── Progress details ─────────────────────────────────
                  if (!isCompleted) ...[
                    Row(children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            minHeight: 7,
                            backgroundColor:
                                AppPalette.sage.withValues(alpha: 0.4),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              pct >= 70
                                  ? AppPalette.successGreen
                                  : AppPalette.coral,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('$pct%',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: pct >= 70
                                  ? AppPalette.successGreen
                                  : AppPalette.coral,
                              fontSize: 13)),
                    ]),
                    const SizedBox(height: 5),
                    Row(children: [
                      Icon(Icons.check_circle_outline,
                          size: 12,
                          color: AppPalette.mocha.withValues(alpha: 0.4)),
                      const SizedBox(width: 4),
                      Text(
                          '${widget.item.completedLessons} / ${course.totalLessons} درس مكتمل',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppPalette.mocha.withValues(alpha: 0.45))),
                    ]),
                    const SizedBox(height: 13),
                  ],

                  // ── Action button ────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: isCompleted
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: AppPalette.plum.withValues(alpha: 0.35),
                                  width: 1.5),
                              borderRadius: BorderRadius.circular(14),
                              color: AppPalette.mocha.withValues(alpha: 0.03),
                            ),
                            child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.replay_rounded,
                                      size: 16, color: AppPalette.plum),
                                  SizedBox(width: 7),
                                  Text('مراجعة الدورة',
                                      style: TextStyle(
                                          color: AppPalette.plum,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13)),
                                ]),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              gradient: AppPalette.btnGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                _shadow(10,
                                    base: AppPalette.coral, opacity: 0.30)
                              ],
                            ),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.play_arrow_rounded,
                                      size: 18, color: Colors.white),
                                  const SizedBox(width: 7),
                                  Text(
                                    pct == 0
                                        ? 'ابدأ الدورة'
                                        : 'استكمل التعلم',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                ]),
                          ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Thumb Fallback ────────────────────────────────────────────────────────────
class _ThumbFallback extends StatelessWidget {
  final bool isCompleted;
  const _ThumbFallback({required this.isCompleted});

  @override
  Widget build(BuildContext context) => Container(
        height: 155,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isCompleted
                  ? [AppPalette.successGreen, const Color(0xFF2D6347)]
                  : [AppPalette.plum, AppPalette.mocha]),
        ),
        child: Icon(
            isCompleted
                ? Icons.verified_rounded
                : Icons.play_circle_fill_rounded,
            size: 52,
            color: Colors.white.withValues(alpha: 0.25)),
      );
}

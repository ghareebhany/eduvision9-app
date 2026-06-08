import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/bundle.dart';
import '../providers/auth_provider.dart';
import '../providers/bundles_provider.dart';

// ── Palette shortcuts ─────────────────────────────────────────────────────────
const _bg     = AppTheme.mocha700;
const _plum   = AppTheme.mocha500;
const _mocha  = AppTheme.mocha700;
const _coral  = AppTheme.coral500;
const _peach  = AppTheme.peach500;
const _sage   = AppTheme.sage500;
const _white  = Colors.white;

BoxShadow _sh(double b, {Color c = Colors.black, double o = 0.12}) =>
    BoxShadow(color: c.withValues(alpha: o), blurRadius: b, offset: Offset(0, b * 0.4));

// ── Sort state ────────────────────────────────────────────────────────────────
class _Sort {
  static const newest   = 'newest';
  static const enrolled = 'enrolled';
  static String label(String s) => switch (s) {
    enrolled => 'المسجّل أولاً',
    _        => 'الافتراضي',
  };
}

// ══════════════════════════════════════════════════════════════════════════════
//  Courses Screen
// ══════════════════════════════════════════════════════════════════════════════
class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});
  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  final _searchCtrl = TextEditingController();
  String _q      = '';
  String _sort   = _Sort.newest;
  bool   _onlyEnrolled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchWhenReady());
  }

  Future<void> _fetchWhenReady() async {
    for (var i = 0; i < 50; i++) {
      if (ref.read(authProvider) is! AuthInitial) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;
    ref.read(bundlesProvider.notifier).fetch();
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<Bundle> _apply(List<Bundle> all) {
    var r = all;
    if (_q.isNotEmpty) {
      final q = _q.toLowerCase();
      r = r.where((b) => b.title.toLowerCase().contains(q)).toList();
    }
    if (_onlyEnrolled) r = r.where((b) => b.isEnrolled).toList();
    if (_sort == _Sort.enrolled) {
      r = [...r]..sort((a, b) => (b.isEnrolled ? 1 : 0) - (a.isEnrolled ? 1 : 0));
    }
    return r;
  }

  bool get _hasFilter => _q.isNotEmpty || _onlyEnrolled || _sort != _Sort.newest;

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(bundlesProvider);
    final all      = state.bundles;
    final filtered = _apply(all);
    final enrolledCount = all.where((b) => b.isEnrolled).length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.mocha900,
        body: RefreshIndicator(
          color: _coral,
          backgroundColor: _white,
          onRefresh: () => ref.read(bundlesProvider.notifier).fetch(refresh: true),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [

              // ── Hero header ──────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                floating: true,
                snap: true,
                backgroundColor: Colors.transparent,
                systemOverlayStyle: SystemUiOverlayStyle.light,
                expandedHeight: 140,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: _HeroHeader(count: all.length),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.mocha900.withValues(alpha: 0.0),
                          AppTheme.mocha900,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(children: [
                      // Search field
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: _white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _white.withValues(alpha: 0.15)),
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(color: _white, fontSize: 13),
                            onChanged: (v) => setState(() => _q = v),
                            decoration: InputDecoration(
                              hintText: 'ابحث عن حزمة...',
                              hintStyle: TextStyle(
                                  color: _white.withValues(alpha: 0.4), fontSize: 13),
                              prefixIcon: Icon(Icons.search_rounded,
                                  color: _white.withValues(alpha: 0.5), size: 20),
                              suffixIcon: _q.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.close_rounded,
                                          color: _white.withValues(alpha: 0.5), size: 18),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _q = '');
                                      })
                                  : null,
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Filter button
                      Stack(children: [
                        GestureDetector(
                          onTap: () => _showFilterSheet(context, all, enrolledCount),
                          child: Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              gradient: _hasFilter
                                  ? LinearGradient(colors: [_coral, _plum])
                                  : null,
                              color: _hasFilter ? null : _white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _hasFilter
                                    ? Colors.transparent
                                    : _white.withValues(alpha: 0.15),
                              ),
                              boxShadow: _hasFilter
                                  ? [_sh(12, c: _coral, o: 0.4)]
                                  : null,
                            ),
                            child: Icon(Icons.tune_rounded,
                                color: _white, size: 20),
                          ),
                        ),
                        if (_hasFilter)
                          Positioned(
                            top: 8, right: 8,
                            child: Container(
                              width: 7, height: 7,
                              decoration: const BoxDecoration(
                                  color: _peach, shape: BoxShape.circle),
                            ),
                          ),
                      ]),
                    ]),
                  ),
                ),
              ),

              // ── Sort bar ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  color: AppTheme.mocha900,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(children: [
                    for (final s in [
                      (_Sort.newest,   'الافتراضي',     Icons.grid_view_rounded),
                      (_Sort.enrolled, 'المسجّل أولاً', Icons.check_circle_outline_rounded),
                    ]) ...[
                      GestureDetector(
                        onTap: () => setState(() => _sort = s.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: _sort == s.$1
                                ? AppTheme.buttonGradient
                                : null,
                            color: _sort == s.$1
                                ? null
                                : _white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _sort == s.$1
                                  ? Colors.transparent
                                  : _white.withValues(alpha: 0.15),
                            ),
                            boxShadow: _sort == s.$1
                                ? [_sh(10, c: _coral, o: 0.35)]
                                : null,
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(s.$3,
                                size: 13,
                                color: _sort == s.$1
                                    ? _white
                                    : _white.withValues(alpha: 0.5)),
                            const SizedBox(width: 5),
                            Text(s.$2,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _sort == s.$1
                                        ? _white
                                        : _white.withValues(alpha: 0.5))),
                          ]),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (filtered.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${filtered.length} حزمة',
                            style: TextStyle(
                                fontSize: 11,
                                color: _white.withValues(alpha: 0.5))),
                      ),
                  ]),
                ),
              ),

              // ── Active filter chips ─────────────────────────────────────
              if (_hasFilter)
                SliverToBoxAdapter(
                  child: Container(
                    color: AppTheme.mocha900,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Wrap(spacing: 8, runSpacing: 6, children: [
                      if (_q.isNotEmpty)
                        _FilterPill(
                          label: 'بحث: $_q',
                          onDelete: () {
                            _searchCtrl.clear();
                            setState(() => _q = '');
                          },
                        ),
                      if (_onlyEnrolled)
                        _FilterPill(
                          label: 'المسجّلة فقط',
                          icon: Icons.check_circle_outline_rounded,
                          onDelete: () => setState(() => _onlyEnrolled = false),
                        ),
                      if (_sort != _Sort.newest)
                        _FilterPill(
                          label: _Sort.label(_sort),
                          icon: Icons.sort_rounded,
                          onDelete: () => setState(() => _sort = _Sort.newest),
                        ),
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() {
                            _q = ''; _sort = _Sort.newest; _onlyEnrolled = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('مسح الكل',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: _white.withValues(alpha: 0.5))),
                        ),
                      ),
                    ]),
                  ),
                ),

              // ── Content area (rounded top) ──────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.sage100,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: const SizedBox(height: 20),
                ),
              ),

              // ── Loading ─────────────────────────────────────────────────
              if (state.isLoading)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.70,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => const _CardShimmer(),
                      childCount: 6,
                    ),
                  ),
                )

              // ── Error ────────────────────────────────────────────────────
              else if (state.error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(
                    color: AppTheme.sage100,
                    child: _ErrorView(
                      message: state.error!,
                      onRetry: () => ref.read(bundlesProvider.notifier).fetch(),
                    ),
                  ),
                )

              // ── Empty ────────────────────────────────────────────────────
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(
                    color: AppTheme.sage100,
                    child: _EmptyView(hasQuery: _q.isNotEmpty, query: _q),
                  ),
                )

              // ── Grid ─────────────────────────────────────────────────────
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.66,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _BundleCard(bundle: filtered[i]),
                      childCount: filtered.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                child: ColoredBox(
                  color: AppTheme.sage100,
                  child: SizedBox(height: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filter bottom sheet ───────────────────────────────────────────────────
  void _showFilterSheet(
      BuildContext context, List<Bundle> all, int enrolledCount) {
    var tempSort         = _sort;
    var tempOnlyEnrolled = _onlyEnrolled;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.75,
          minChildSize: 0.35,
          expand: false,
          builder: (_, ctrl) => Container(
            decoration: const BoxDecoration(
              color: AppTheme.sage100,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    color: AppTheme.sage500, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  const Text('فلترة الحزم',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _mocha)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setModal(() {
                      tempSort = _Sort.newest;
                      tempOnlyEnrolled = false;
                    }),
                    child: const Text('إعادة ضبط',
                        style: TextStyle(color: _coral)),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text('ترتيب حسب',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _mocha)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final s in [
                        (_Sort.newest,   'الافتراضي',     Icons.grid_view_rounded),
                        (_Sort.enrolled, 'المسجّل أولاً', Icons.check_circle_outline_rounded),
                      ])
                        GestureDetector(
                          onTap: () => setModal(() => tempSort = s.$1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              gradient: tempSort == s.$1
                                  ? AppTheme.buttonGradient
                                  : null,
                              color: tempSort == s.$1
                                  ? null
                                  : AppTheme.sage200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(s.$3,
                                  size: 14,
                                  color: tempSort == s.$1
                                      ? _white
                                      : AppTheme.textMuted),
                              const SizedBox(width: 6),
                              Text(s.$2,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: tempSort == s.$1
                                          ? _white
                                          : AppTheme.textMuted)),
                            ]),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 22),
                    if (enrolledCount > 0) ...[
                      const Text('تصفية',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _mocha)),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () =>
                            setModal(() => tempOnlyEnrolled = !tempOnlyEnrolled),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: tempOnlyEnrolled
                                ? AppTheme.success.withValues(alpha: 0.1)
                                : AppTheme.sage200,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: tempOnlyEnrolled
                                  ? AppTheme.success.withValues(alpha: 0.4)
                                  : AppTheme.sage500.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(children: [
                            Icon(
                              tempOnlyEnrolled
                                  ? Icons.check_circle_rounded
                                  : Icons.check_circle_outline_rounded,
                              color: tempOnlyEnrolled
                                  ? AppTheme.success
                                  : AppTheme.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text('المسجّلة فقط ($enrolledCount حزمة)',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: tempOnlyEnrolled
                                        ? AppTheme.success
                                        : _mocha)),
                          ]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppTheme.buttonGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [_sh(12, c: _coral, o: 0.35)],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _sort = tempSort;
                            _onlyEnrolled = tempOnlyEnrolled;
                          });
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('تطبيق',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _white)),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Hero Header
// ══════════════════════════════════════════════════════════════════════════════
class _HeroHeader extends StatelessWidget {
  final int count;
  const _HeroHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.mocha900, AppTheme.mocha800, AppTheme.mocha700],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(children: [
        // Deco — دائرة كبيرة علوية
        Positioned(
          top: -40, right: -30,
          child: Container(
            width: 160, height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _coral.withValues(alpha: 0.06),
            ),
          ),
        ),
        // Deco — دائرة صغيرة
        Positioned(
          top: 20, right: 100,
          child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _peach.withValues(alpha: 0.08),
            ),
          ),
        ),
        // Deco — خط مائل
        Positioned(
          bottom: 30, left: -20,
          child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _plum.withValues(alpha: 0.25),
            ),
          ),
        ),
        // Content
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: AppTheme.buttonGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [_sh(10, c: _coral, o: 0.4)],
                    ),
                    child: const Icon(Icons.collections_bookmark_rounded,
                        color: _white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('الحزم التعليمية',
                        style: TextStyle(
                            color: _white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            letterSpacing: -0.3)),
                  ),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: _coral.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _coral.withValues(alpha: 0.35)),
                      ),
                      child: Text('$count حزمة',
                          style: TextStyle(
                              color: _white.withValues(alpha: 0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                ]),
                const SizedBox(height: 6),
                Text('اكتشف أفضل المسارات التعليمية',
                    style: TextStyle(
                        color: _white.withValues(alpha: 0.45),
                        fontSize: 12.5)),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Bundle Card
// ══════════════════════════════════════════════════════════════════════════════
class _BundleCard extends StatefulWidget {
  final Bundle bundle;
  const _BundleCard({required this.bundle});

  @override
  State<_BundleCard> createState() => _BundleCardState();
}

class _BundleCardState extends State<_BundleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.bundle;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        context.push('/bundle/${b.id}');
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: b.isEnrolled
                  ? AppTheme.success.withValues(alpha: 0.35)
                  : AppTheme.sage400.withValues(alpha: 0.6),
              width: b.isEnrolled ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (b.isEnrolled ? AppTheme.success : AppTheme.mocha700)
                    .withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: (b.isEnrolled ? AppTheme.success : _coral)
                    .withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Thumbnail ───────────────────────────────────────────
              Expanded(
                flex: 5,
                child: Stack(fit: StackFit.expand, children: [
                  b.thumbnail.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: b.thumbnail,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _GradBg(index: b.id))
                      : _GradBg(index: b.id),

                  // Gradient scrim داكن
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                          ],
                          stops: const [0.35, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Status badge
                  if (b.isEnrolled)
                    Positioned(
                      top: 9, left: 9,
                      child: _StatusBadge(
                          label: 'مسجّل',
                          color: AppTheme.success,
                          icon: Icons.check_rounded),
                    ),

                  // Course count badge
                  Positioned(
                    bottom: 8, right: 9,
                    child: _CountBadge(count: b.courseCount),
                  ),
                ]),
              ),

              // ── Info ────────────────────────────────────────────────
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 8, 11, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.mocha700,
                              height: 1.3)),

                      const Spacer(),

                      if (b.isEnrolled) ...[
                        _MiniProgress(courses: b.courses),
                        const SizedBox(height: 7),
                      ],

                      // CTA
                      b.isEnrolled
                          ? _CtaButton(
                              label: 'ابدأ التعلم',
                              icon: Icons.play_arrow_rounded,
                              gradient: null,
                              solidColor: AppTheme.successLight,
                              textColor: AppTheme.success)
                          : _CtaButton(
                              label: 'أدخل كود',
                              icon: Icons.vpn_key_rounded,
                              gradient: AppTheme.buttonGradient,
                              solidColor: null,
                              textColor: _white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusBadge({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: _white),
      const SizedBox(width: 3),
      Text(label,
          style: const TextStyle(
              color: _white, fontSize: 9.5, fontWeight: FontWeight.bold)),
    ]),
  );
}

// ── Count Badge ───────────────────────────────────────────────────────────────
class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      color: Colors.black.withValues(alpha: 0.5),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.library_books_rounded, size: 9, color: _white),
        const SizedBox(width: 3),
        Text('$count',
            style: const TextStyle(
                color: _white, fontSize: 9.5, fontWeight: FontWeight.bold)),
      ]),
    ),
  );
}

// ── Mini Progress ─────────────────────────────────────────────────────────────
class _MiniProgress extends StatelessWidget {
  final List<BundleCourse> courses;
  const _MiniProgress({required this.courses});

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) return const SizedBox.shrink();
    final cnt = courses.where((c) => c.isEnrolled).length;
    final pct = cnt / courses.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct, minHeight: 4,
              backgroundColor: AppTheme.success.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(AppTheme.success)),
          ),
        ),
        const SizedBox(width: 5),
        Text('${(pct * 100).round()}%',
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppTheme.success)),
      ]),
    ]);
  }
}

// ── CTA Button ────────────────────────────────────────────────────────────────
class _CtaButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient? gradient;
  final Color? solidColor;
  final Color textColor;
  const _CtaButton({
    required this.label, required this.icon,
    required this.gradient, required this.solidColor, required this.textColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 7),
    decoration: BoxDecoration(
      gradient: gradient,
      color: solidColor,
      borderRadius: BorderRadius.circular(10),
      boxShadow: gradient != null
          ? [_sh(10, c: _coral, o: 0.28)] : null,
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 13, color: textColor),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
    ]),
  );
}

// ── Filter Pill ───────────────────────────────────────────────────────────────
class _FilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onDelete;
  const _FilterPill({required this.label, this.icon, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
    decoration: BoxDecoration(
      color: _coral.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _coral.withValues(alpha: 0.35)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        Icon(icon, size: 12, color: _coral),
        const SizedBox(width: 4),
      ],
      Text(label,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: _coral)),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: onDelete,
        child: const Icon(Icons.close_rounded, size: 13, color: _coral),
      ),
    ]),
  );
}

// ── Gradient Background ───────────────────────────────────────────────────────
class _GradBg extends StatelessWidget {
  final int index;
  const _GradBg({required this.index});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.categoryGradients[index % AppTheme.categoryGradients.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: c, begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: const Center(
        child: Icon(Icons.collections_bookmark_rounded,
            size: 32, color: Colors.white24)),
    );
  }
}

// ── Shimmer Card ──────────────────────────────────────────────────────────────
class _CardShimmer extends StatelessWidget {
  const _CardShimmer();

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: AppTheme.sage300,
    highlightColor: AppTheme.sage100,
    child: Container(
      decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(22)),
    ),
  );
}

// ── Error View ────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: _coral.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.wifi_off_rounded, size: 40, color: _coral)),
        const SizedBox(height: 14),
        Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: _mocha.withValues(alpha: 0.6))),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
                gradient: AppTheme.buttonGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [_sh(10, c: _coral, o: 0.3)]),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.refresh_rounded, color: _white, size: 16),
              SizedBox(width: 8),
              Text('إعادة المحاولة',
                  style: TextStyle(color: _white, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ]),
    ),
  );
}

// ── Empty View ────────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final bool hasQuery;
  final String query;
  const _EmptyView({required this.hasQuery, required this.query});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_plum.withValues(alpha: 0.12), _coral.withValues(alpha: 0.08)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.folder_off_outlined, size: 40, color: _plum)),
      const SizedBox(height: 12),
      Text(hasQuery ? 'لا نتائج لـ "$query"' : 'لا توجد حزم متاحة',
          style: TextStyle(
              color: _mocha.withValues(alpha: 0.55), fontSize: 14)),
    ]),
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';
import 'package:alumni_system/features/forum/models/forum_filters.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/forum/presentation/forum_composer_page.dart';
import 'package:alumni_system/features/forum/presentation/forum_topic_page.dart';
import 'package:alumni_system/features/forum/widgets/forum_ui.dart';
import 'package:alumni_system/shared/widgets/user/portal_filters.dart';
import 'package:alumni_system/shared/widgets/user/portal_floating.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key, this.embeddedInHub = false});

  /// When true, omit the top AppBar (parent Community hub provides chrome).
  final bool embeddedInHub;

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final _forumService = ForumService();
  final _searchController = TextEditingController();

  List<ForumTopic> _topics = [];
  int _totalCount = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;
  int _page = 0;

  String _search = '';
  ForumSort _sort = ForumSort.latestActivity;
  final Set<ForumListFilter> _filters = {ForumListFilter.all};

  Timer? _debounce;
  StreamSubscription<void>? _refreshSub;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _refreshSub = ForumService.topicsChangedStream.listen((_) {
      if (mounted) _load(reset: true, silent: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _refreshSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false, bool silent = false}) async {
    if (reset) {
      _page = 0;
      if (!silent) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final page = await _forumService.fetchTopics(
        ForumTopicQuery(
          search: _search,
          filters: Set.of(_filters),
          sort: _sort,
          page: _page,
          pageSize: 20,
        ),
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _topics = page.topics;
        } else {
          _topics = [..._topics, ...page.topics];
        }
        _totalCount = page.totalCount;
        _hasMore = page.hasMore;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = '$e';
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      setState(() => _search = value.trim());
      _load(reset: true);
    });
  }

  void _toggleFilter(ForumListFilter filter) {
    setState(() {
      if (filter == ForumListFilter.all) {
        _filters
          ..clear()
          ..add(ForumListFilter.all);
      } else {
        _filters.remove(ForumListFilter.all);
        if (_filters.contains(filter)) {
          _filters.remove(filter);
        } else {
          _filters.add(filter);
        }
        if (_filters.isEmpty) _filters.add(ForumListFilter.all);
      }
    });
    _load(reset: true);
  }

  Future<void> _openComposer() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ForumComposerPage()),
    );
    if (!mounted) return;
    await _load(reset: true);
    if (id != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ForumTopicScreen(topicId: id)),
      );
      if (mounted) await _load(reset: true, silent: true);
    }
  }

  Future<void> _openTopic(ForumTopic topic) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ForumTopicScreen(topicId: topic.id)),
    );
    if (mounted) await _load(reset: true, silent: true);
  }

  Widget _buildSortChip() {
    return PortalDropdownChip<ForumSort>(
      value: _sort,
      items: [for (final s in ForumSort.values) (s, s.label)],
      icon: Icons.swap_vert_rounded,
      selected: _sort != ForumSort.latestActivity,
      onChanged: (v) {
        setState(() => _sort = v);
        _load(reset: true);
      },
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: PortalFilterChip.height,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildSortChip(),
            ),
            for (final f in ForumListFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PortalFilterChip(
                  label: f.label,
                  selected: _filters.contains(f),
                  onTap: () => _toggleFilter(f),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(bool wide) {
    if (!wide) return const SizedBox.shrink();
    return SizedBox(
      width: 220,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ForumTheme.radius2xl),
          border: Border.all(color: ForumTheme.border.withValues(alpha: 0.75)),
          boxShadow: ForumTheme.softShadow,
        ),
        child: ListView(
          padding: const EdgeInsets.all(PortalTheme.space3),
          children: [
            Text(
              'Filters',
              style: PortalTheme.sectionTitle.copyWith(fontSize: 16),
            ),
            const SizedBox(height: PortalTheme.space2),
            ...ForumListFilter.values.map((f) {
              final selected = _filters.contains(f);
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  f.label,
                  style: PortalTheme.body.copyWith(fontSize: 13),
                ),
                value: selected,
                activeColor: ForumTheme.navy,
                onChanged: (_) => _toggleFilter(f),
                controlAffinity: ListTileControlAffinity.leading,
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;

    return Scaffold(
      backgroundColor: ForumTheme.pageBg,
      appBar: widget.embeddedInHub
          ? null
          : PortalAppBar(
              title: 'Forum',
              subtitle: 'Alumni discussions',
              actions: [
                PortalHeaderAction(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh',
                  onPressed: () => _load(reset: true),
                ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        // Clear the floating pill bottom nav when embedded in Community hub.
        // Tablet / web use a side rail instead, so no offset there.
        padding: EdgeInsets.only(
          bottom:
              widget.embeddedInHub &&
                  !PortalBreakpoints.useNavigationRail(
                    PortalBreakpoints.widthOf(context),
                  )
              ? PortalFloating.bottomClearance(context) - 16
              : 0,
        ),
        child: FloatingActionButton.extended(
          onPressed: _openComposer,
          backgroundColor: ForumTheme.navy,
          foregroundColor: Colors.white,
          elevation: 2,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New topic'),
        ),
      ),
      body: RefreshIndicator(
        color: ForumTheme.navy,
        onRefresh: () => _load(reset: true),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      left: PortalTheme.space3,
                      top: PortalTheme.space3,
                      bottom: PortalTheme.space3,
                    ),
                    child: _buildSidebar(true),
                  ),
                  const SizedBox(width: PortalTheme.space3),
                ],
                Expanded(
                  child: PortalContentFrame(
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        PortalFloatingFilterHeader(
                          child: _buildFilterCardContent(wide),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                          sliver: SliverToBoxAdapter(child: _buildListBody()),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: wide
                                ? PortalTheme.space5
                                : PortalFloating.bottomClearance(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterCardContent(bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PortalSearchField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          hintText: 'Search title, content, author, program, tags…',
        ),
        const SizedBox(height: PortalTheme.space2),
        if (!wide) _buildFilterChips(),
        if (!wide) const SizedBox(height: PortalTheme.space2),
        Row(
          children: [
            Text(
              _totalCount == 1 ? '1 discussion' : '$_totalCount discussions',
              style: PortalTheme.meta,
            ),
            if (wide) ...[const Spacer(), _buildSortChip()],
          ],
        ),
      ],
    );
  }

  Widget _buildListBody() {
    if (_loading) {
      return const SizedBox(
        height: 320,
        child: PortalCardListSkeleton(threeLine: true),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 280,
        child: ForumErrorState(
          message: _error!,
          onRetry: () => _load(reset: true),
        ),
      );
    }
    if (_topics.isEmpty) {
      final searching = _search.isNotEmpty;
      final bookmarkedOnly =
          _filters.contains(ForumListFilter.bookmarked) &&
          !_filters.contains(ForumListFilter.all);
      return SizedBox(
        height: 320,
        child: ForumEmptyState(
          icon: searching
              ? Icons.search_off
              : bookmarkedOnly
              ? Icons.bookmark_border
              : Icons.forum_outlined,
          title: searching
              ? 'No search results'
              : bookmarkedOnly
              ? 'No bookmarked topics'
              : 'No discussions yet',
          subtitle: searching
              ? 'Try a different keyword or clear filters.'
              : bookmarkedOnly
              ? 'Save discussions you want to revisit later.'
              : 'Start the first topic and invite alumni to reply.',
          actionLabel: searching || bookmarkedOnly ? null : 'Start discussion',
          onAction: searching || bookmarkedOnly ? null : _openComposer,
        ),
      );
    }

    final pinned = _topics
        .where((t) => t.isPinned && !t.isAnnouncement)
        .toList();
    final regular = _topics
        .where((t) => !t.isPinned || t.isAnnouncement)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pinned.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: PortalTheme.space2),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: ForumTheme.pinnedBg,
                    borderRadius: BorderRadius.circular(PortalTheme.radiusSm),
                  ),
                  child: const Icon(
                    Icons.push_pin_rounded,
                    size: 14,
                    color: ForumTheme.pinned,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Pinned',
                  style: PortalTheme.sectionTitle.copyWith(
                    fontSize: 14,
                    color: ForumTheme.pinned,
                  ),
                ),
              ],
            ),
          ),
          for (final topic in pinned)
            ForumTopicCard(topic: topic, onTap: () => _openTopic(topic)),
        ],
        if (regular.isNotEmpty && pinned.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              top: PortalTheme.space1,
              bottom: PortalTheme.space2,
            ),
            child: Text(
              'All discussions',
              style: PortalTheme.sectionTitle.copyWith(fontSize: 14),
            ),
          ),
        for (final topic in regular)
          ForumTopicCard(topic: topic, onTap: () => _openTopic(topic)),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: PortalTheme.space3),
            child: TextButton(
              onPressed: _loadingMore
                  ? null
                  : () {
                      setState(() => _page += 1);
                      _load();
                    },
              style: PortalTheme.ghostButton(),
              child: Text(_loadingMore ? 'Loading…' : 'Load more'),
            ),
          ),
      ],
    );
  }
}

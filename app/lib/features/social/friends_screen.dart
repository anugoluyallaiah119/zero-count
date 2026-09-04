import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/zc_cosmetics.dart';
import '../../ui/zc_theme.dart';
import '../auth/avatar_catalog.dart';
import 'friend_repository.dart';

/// Social hub: Friends · Requests · Search.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(friendListsProvider);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF09031E), Color(0xFF140733)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(),
              const SizedBox(height: 4),
              _TabBar(controller: _tabs,
                  badge: listsAsync.valueOrNull?.incoming.length ?? 0),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _FriendsTab(listsAsync: listsAsync),
                    _RequestsTab(listsAsync: listsAsync),
                    const _SearchTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// HEADER
// =============================================================================

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0x22FFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0x33FFFFFF), width: 1.1),
                ),
                child: const Icon(Icons.chevron_left_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FRIENDS',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8)),
                Text('Invite · Challenge · Play',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Icon(Icons.people_rounded, color: ZcColors.gold, size: 26),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB BAR
// =============================================================================

class _TabBar extends StatelessWidget {
  const _TabBar({required this.controller, required this.badge});
  final TabController controller;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF5A1FA8), Color(0xFF3A1280)]),
          borderRadius: BorderRadius.circular(11),
          boxShadow: const [
            BoxShadow(
                color: Color(0x55A855F7), blurRadius: 8, spreadRadius: 1)
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12.5,
            fontWeight: FontWeight.w900),
        unselectedLabelStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12,
            fontWeight: FontWeight.w700),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        tabs: [
          const Tab(text: '👥 Friends'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔔 Requests'),
                if (badge > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$badge',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                  ),
                ],
              ],
            ),
          ),
          const Tab(text: '🔍 Search'),
        ],
      ),
    );
  }
}

// =============================================================================
// FRIENDS TAB
// =============================================================================

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab({required this.listsAsync});
  final AsyncValue<FriendLists> listsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return listsAsync.when(
      loading: () => const _Loader(),
      error: (e, _) => _ErrView(message: e.toString()),
      data: (lists) {
        if (lists.friends.isEmpty) {
          return _EmptyState(
            icon: '👥',
            message:
                'No friends yet.\nSearch for players and send a request!',
          );
        }
        return RefreshIndicator(
          color: ZcColors.gold,
          backgroundColor: const Color(0xFF1A0B3D),
          onRefresh: () async => ref.invalidate(friendListsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
            itemCount: lists.friends.length,
            itemBuilder: (context, i) => _FriendRow(
              entry: lists.friends[i],
              trailing: _InviteChip(userId: lists.friends[i].userId,
                  name: lists.friends[i].name),
              onRemove: () async {
                await ref
                    .read(friendRepositoryProvider)
                    .remove(lists.friends[i].userId);
                ref.invalidate(friendListsProvider);
              },
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// REQUESTS TAB
// =============================================================================

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab({required this.listsAsync});
  final AsyncValue<FriendLists> listsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return listsAsync.when(
      loading: () => const _Loader(),
      error: (e, _) => _ErrView(message: e.toString()),
      data: (lists) {
        if (lists.incoming.isEmpty && lists.outgoing.isEmpty) {
          return _EmptyState(
            icon: '🔔',
            message: 'No pending requests.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
          children: [
            if (lists.incoming.isNotEmpty) ...[
              _sectionLabel('INCOMING'),
              ...lists.incoming.map((e) => _FriendRow(
                    entry: e,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SmallBtn(
                          label: 'Accept',
                          color: const Color(0xFF22C55E),
                          onTap: () async {
                            await ref
                                .read(friendRepositoryProvider)
                                .accept(e.userId);
                            ref.invalidate(friendListsProvider);
                          },
                        ),
                        const SizedBox(width: 6),
                        _SmallBtn(
                          label: 'Decline',
                          color: const Color(0xFFEF4444),
                          onTap: () async {
                            await ref
                                .read(friendRepositoryProvider)
                                .remove(e.userId);
                            ref.invalidate(friendListsProvider);
                          },
                        ),
                      ],
                    ),
                  )),
            ],
            if (lists.outgoing.isNotEmpty) ...[
              _sectionLabel('SENT'),
              ...lists.outgoing.map((e) => _FriendRow(
                    entry: e,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x22FFFFFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Pending',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  )),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2)),
      );
}

// =============================================================================
// SEARCH TAB
// =============================================================================

class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab();

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  final _ctrl = TextEditingController();
  List<FriendEntry>? _results;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final r = await ref.read(friendRepositoryProvider).search(q);
      if (mounted) setState(() => _results = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  onSubmitted: (_) => _search(),
                  style: const TextStyle(color: Colors.white),
                  cursorColor: ZcColors.neonPurple,
                  decoration: InputDecoration(
                    hintText: 'Search by name…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0x22FFFFFF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide:
                          const BorderSide(color: Color(0x33FFFFFF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide:
                          const BorderSide(color: Color(0x33FFFFFF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(
                          color: ZcColors.neonPurple, width: 1.4),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Colors.white38, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _loading ? null : _search,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZcColors.neonPurple,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Go',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        Expanded(
          child: _results == null
              ? const _EmptyState(
                  icon: '🔍',
                  message: 'Search for players by their display name.',
                )
              : _results!.isEmpty
                  ? const _EmptyState(
                      icon: '🤷',
                      message: 'No players found.',
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(14, 0, 14, 20),
                      itemCount: _results!.length,
                      itemBuilder: (context, i) => _FriendRow(
                        entry: _results![i],
                        trailing: _AddFriendBtn(
                            userId: _results![i].userId),
                      ),
                    ),
        ),
      ],
    );
  }
}

// =============================================================================
// SHARED WIDGETS
// =============================================================================

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.entry,
    required this.trailing,
    this.onRemove,
  });
  final FriendEntry entry;
  final Widget trailing;
  final VoidCallback? onRemove;

  Widget _avatar(String id) {
    if (id.startsWith('av_')) return ZcAvatars.forId(id, 40);
    final opt = kAvatars.firstWhere((a) => a.id == id,
        orElse: () => kAvatars.first);
    return Image.asset(opt.asset,
        width: 40, height: 40, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(child: _avatar(entry.avatar)),
              if (entry.online)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF09031E), width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name.isEmpty ? 'Player' : entry.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.online) ...[
                      const SizedBox(width: 6),
                      const Text('● Online',
                          style: TextStyle(
                              color: Color(0xFF22C55E),
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          trailing,
          if (onRemove != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.person_remove_rounded,
                  color: Colors.white24, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddFriendBtn extends ConsumerStatefulWidget {
  const _AddFriendBtn({required this.userId});
  final String userId;

  @override
  ConsumerState<_AddFriendBtn> createState() => _AddFriendBtnState();
}

class _AddFriendBtnState extends ConsumerState<_AddFriendBtn> {
  String? _state; // null, 'loading', 'sent', 'friends', 'error'

  @override
  Widget build(BuildContext context) {
    if (_state == 'friends' || _state == 'sent') {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          _state == 'friends' ? '✓ Friends' : '✓ Sent',
          style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w800),
        ),
      );
    }
    return ElevatedButton(
      onPressed: _state == 'loading'
          ? null
          : () async {
              setState(() => _state = 'loading');
              try {
                final result = await ref
                    .read(friendRepositoryProvider)
                    .request(widget.userId);
                if (mounted) {
                  setState(() => _state = result == 'accepted'
                      ? 'friends'
                      : 'sent');
                  ref.invalidate(friendListsProvider);
                }
              } catch (e) {
                if (mounted) setState(() => _state = null);
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: ZcColors.neonPurple,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      ),
      child: _state == 'loading'
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Text('Add',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900)),
    );
  }
}

/// Chip on friends list — invite to a room with the share sheet.
class _InviteChip extends StatelessWidget {
  const _InviteChip({required this.userId, required this.name});
  final String userId;
  final String name;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => context.push('/invite'),
      style: OutlinedButton.styleFrom(
        foregroundColor: ZcColors.gold,
        side: const BorderSide(color: Color(0x44FDE047)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('Invite',
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w900)),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  const _SmallBtn(
      {required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9)),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w900)),
    );
  }
}

class _Loader extends StatelessWidget {
  const _Loader();
  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: ZcColors.neonPurple),
      );
}

class _ErrView extends StatelessWidget {
  const _ErrView({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 13)),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final String icon;
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}

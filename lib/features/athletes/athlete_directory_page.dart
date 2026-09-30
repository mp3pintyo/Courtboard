import 'package:flutter/material.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/shared/images.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';
import 'package:courtboard/data/api_sports.dart';
import 'package:courtboard/domain/athlete.dart';

class AthleteDirectoryPage extends StatefulWidget {
  const AthleteDirectoryPage({
    super.key,
    required this.athletes,
    required this.sort,
    required this.onOpen,
    required this.onAdd,
    required this.onReorder,
  });
  final List<Athlete> athletes;
  final String sort;
  final ValueChanged<Athlete> onOpen;
  final VoidCallback onAdd;

  /// A „Saját sorrend” módosítása: régi és (a kivétel után már igazított)
  /// új index a teljes listában.
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  State<AthleteDirectoryPage> createState() => _AthleteDirectoryState();
}

class _AthleteDirectoryState extends State<AthleteDirectoryPage> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'directory-search');

  /// A sportág-szűrő; `null`: „Mind”.
  Sport? _sport;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _focusSearch() {
    _searchFocus.requestFocus();
    _search.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _search.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = normalizeAthleteName(_search.text.trim());
    final athletes = sortAthletes(
      widget.athletes
          .where(
            (athlete) =>
                (_sport == null || athlete.sport == _sport) &&
                (query.isEmpty ||
                    normalizeAthleteName(athlete.name).contains(query)),
          )
          .toList(),
      widget.sort,
    );
    final customOrder = widget.sort == 'custom';
    // Húzással csak a teljes, szűretlen listát lehet átrendezni, különben az
    // indexek nem a tényleges sorrendre vonatkoznának.
    final reorderable = customOrder && query.isEmpty && _sport == null;
    final cb = context.cb;
    final padding = MediaQuery.sizeOf(context).width < 800 ? 20.0 : 34.0;
    return CommandListener(
      onFocusSearch: _focusSearch,
      child: Container(
        color: cb.canvas,
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Sportolók',
              subtitle: 'Névfeloldás, képkeresés és saját követési lista.',
              actions: [
                Tooltip(
                  message: 'Új sportoló (Ctrl+N)',
                  child: FilledButton.icon(
                    onPressed: widget.onAdd,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Sportoló hozzáadása'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('athlete-directory-search'),
                    controller: _search,
                    focusNode: _searchFocus,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Keresés név alapján… (Ctrl+F)',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Keresés törlése',
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${athletes.length} sportoló',
                  style: context.text.titleSmall?.copyWith(color: cb.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Sport?>[null, ...Sport.values]
                    .map(
                      (sport) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: ValueKey(
                            'athlete-sport-'
                            '${sport?.shortLabel ?? Sport.allLabel}',
                          ),
                          label: Text(sport?.shortLabel ?? Sport.allLabel),
                          selected: _sport == sport,
                          onSelected: (_) => setState(() => _sport = sport),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (customOrder) ...[
              const SizedBox(height: 10),
              Text(
                reorderable
                    ? 'Saját sorrend: a fogantyúval húzva átrendezheted a listát.'
                    : 'Az átrendezéshez töröld a keresést, és válaszd a „Mind” szűrőt.',
                style: context.text.bodySmall,
              ),
            ],
            const SizedBox(height: 18),
            Expanded(
              child: athletes.isEmpty
                  ? const Center(
                      child: EmptyState(
                        icon: Icons.person_search_outlined,
                        message: 'Nincs a keresésnek megfelelő sportoló.',
                      ),
                    )
                  : reorderable
                  ? ReorderableListView.builder(
                      key: const Key('athlete-directory-reorderable'),
                      buildDefaultDragHandles: false,
                      itemCount: athletes.length,
                      onReorderItem: widget.onReorder,
                      itemBuilder: (context, index) => Padding(
                        key: ValueKey('reorder-${athletes[index].name}'),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DirectoryTile(
                          athlete: athletes[index],
                          onOpen: widget.onOpen,
                          trailing: ReorderableDragStartListener(
                            index: index,
                            child: Tooltip(
                              message: 'Húzd az átrendezéshez',
                              child: Icon(
                                Icons.drag_handle,
                                color: cb.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: athletes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _DirectoryTile(
                        athlete: athletes[index],
                        onOpen: widget.onOpen,
                        trailing: Icon(
                          Icons.arrow_forward,
                          color: cb.textMuted,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectoryTile extends StatelessWidget {
  const _DirectoryTile({
    required this.athlete,
    required this.onOpen,
    required this.trailing,
  });
  final Athlete athlete;
  final ValueChanged<Athlete> onOpen;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => FocusRing(
    borderRadius: BorderRadius.circular(16),
    child: Material(
      color: context.cb.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.cb.border),
      ),
      child: ListTile(
        key: ValueKey('directory-athlete-${athlete.name}'),
        onTap: () => onOpen(athlete),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: SizedBox.square(
          dimension: 42,
          child: ClipOval(
            child: CourtboardImage(
              url: athlete.photoUrl,
              alignment: const Alignment(0, -0.5),
              semanticLabel: '${athlete.name} fotója',
              placeholder: InitialsPlaceholder(
                name: athlete.name,
                color: athlete.accent,
              ),
            ),
          ),
        ),
        title: Text(
          athlete.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.titleMedium,
        ),
        subtitle: Text(
          athlete.sportAndTeam,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: trailing,
      ),
    ),
  );
}

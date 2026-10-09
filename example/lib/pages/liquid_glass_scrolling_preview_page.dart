import 'package:flutter/material.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

import '../widgets/theme_mode_action_button.dart';

/// Native Liquid Glass widgets inside Flutter's scroll views. The native
/// views should move, size and clip exactly like the Flutter content around
/// them.
class LiquidGlassScrollingPreviewPage extends StatelessWidget {
  final ValueChanged<bool> onThemeChanged;

  const LiquidGlassScrollingPreviewPage({
    super.key,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scrolling preview'),
          actions: [ThemeModeActionButton(onThemeChanged: onThemeChanged)],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'ListView'),
              Tab(text: 'CustomScrollView'),
              Tab(text: 'GridView'),
              Tab(text: 'Horizontal'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ListViewDemo(),
            _CustomScrollViewDemo(),
            _GridViewDemo(),
            _HorizontalDemo(),
          ],
        ),
      ),
    );
  }
}

void _pressed(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Pressed $what'),
        duration: const Duration(milliseconds: 800),
      ),
    );
}

class _ListViewDemo extends StatelessWidget {
  const _ListViewDemo();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 40,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        // Mix the native widget types so each scrolls next to Flutter text.
        final Widget trailing = switch (i % 4) {
          0 => LiquidGlassButton(
            label: 'Open $i',
            onPressed: () => _pressed(context, 'Open $i'),
          ),
          1 => LiquidGlassButton.icon(
            icon: const NativeLiquidGlassIcon.sfSymbol('heart'),
            onPressed: () => _pressed(context, 'heart $i'),
          ),
          2 => LiquidGlassButtonGroup(
            spacing: 0,
            buttons: [
              LiquidGlassButtonData(
                icon: const NativeLiquidGlassIcon.sfSymbol('hand.thumbsup'),
                onPressed: () => _pressed(context, 'like $i'),
              ),
              LiquidGlassButtonData(
                icon: const NativeLiquidGlassIcon.sfSymbol('hand.thumbsdown'),
                onPressed: () => _pressed(context, 'dislike $i'),
              ),
            ],
          ),
          _ => LiquidGlassButton(
            label: 'Share',
            icon: const NativeLiquidGlassIcon.sfSymbol('square.and.arrow.up'),
            imagePlacement: LiquidGlassImagePlacement.trailing,
            onPressed: () => _pressed(context, 'share $i'),
          ),
        };
        return ListTile(
          title: Text('Row $i'),
          subtitle: Text(switch (i % 4) {
            0 => 'Text button',
            1 => 'Icon button',
            2 => 'Button group',
            _ => 'Text button with icon',
          }),
          trailing: trailing,
        );
      },
    );
  }
}

class _CustomScrollViewDemo extends StatelessWidget {
  const _CustomScrollViewDemo();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 140,
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text('Pinned header'),
            background: ColoredBox(color: colorScheme.primaryContainer),
          ),
          actions: [
            LiquidGlassButton.icon(
              icon: const NativeLiquidGlassIcon.sfSymbol('magnifyingglass'),
              onPressed: () => _pressed(context, 'search'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: LiquidGlassButtonGroup(
                buttons: [
                  for (final symbol in ['bold', 'italic', 'underline'])
                    LiquidGlassButtonData(
                      icon: NativeLiquidGlassIcon.sfSymbol(symbol),
                      onPressed: () => _pressed(context, symbol),
                    ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              for (var i = 0; i < 6; i++)
                LiquidGlassContainer(
                  config: const LiquidGlassConfig(
                    shape: LiquidGlassEffectShape.rect,
                    cornerRadius: 20,
                    interactive: true,
                  ),
                  onTap: () => _pressed(context, 'card $i'),
                  child: Center(child: Text('Glass card $i')),
                ),
            ],
          ),
        ),
        SliverList.builder(
          itemCount: 25,
          itemBuilder: (context, i) => ListTile(
            title: Text('Sliver row $i'),
            trailing: LiquidGlassButton(
              label: 'Go',
              icon: const NativeLiquidGlassIcon.sfSymbol('chevron.right'),
              imagePlacement: LiquidGlassImagePlacement.trailing,
              onPressed: () => _pressed(context, 'go $i'),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridViewDemo extends StatelessWidget {
  const _GridViewDemo();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: 30,
      itemBuilder: (context, i) => LiquidGlassContainer(
        config: const LiquidGlassConfig(
          shape: LiquidGlassEffectShape.rect,
          cornerRadius: 24,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Item $i', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            LiquidGlassButton(
              label: 'Add',
              icon: const NativeLiquidGlassIcon.sfSymbol('plus'),
              onPressed: () => _pressed(context, 'add $i'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HorizontalDemo extends StatelessWidget {
  const _HorizontalDemo();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        for (var section = 0; section < 6; section++) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Section $section',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 12,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => Center(
                child: i.isEven
                    ? LiquidGlassButton(
                        label: 'Chip $section.$i',
                        onPressed: () => _pressed(context, 'chip $section.$i'),
                      )
                    : LiquidGlassButton.icon(
                        icon: const NativeLiquidGlassIcon.sfSymbol('star'),
                        onPressed: () => _pressed(context, 'star $section.$i'),
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

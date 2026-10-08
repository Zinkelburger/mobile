import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/l10n/l10n.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/analysis/common_analysis_prefs.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/styles/lichess_icons.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/screen.dart';
import 'package:lichess_mobile/src/view/engine/engine_gauge.dart';
import 'package:lichess_mobile/src/widgets/pockets.dart';
import 'package:material_ui/material_ui.dart';

/// The height of the board header or footer in the analysis layout.
const kAnalysisBoardHeaderOrFooterHeight = 26.0;

typedef BoardBuilder = Widget Function(
  BuildContext context,
  double boardSize,
  BorderRadius? boardRadius,
);

typedef EngineGaugeBuilder = Widget Function(BuildContext context);

enum AnalysisTab(final IconData icon) {
  pgn(Icons.sell_outlined),
  explorer(Icons.explore),
  moves(LichessIcons.flow_cascade),
  summary(Icons.area_chart),
  moveTimes(Icons.punch_clock),
  conditionalPremoves(Icons.save);

  String l10n(AppLocalizations l10n) {
    switch (this) {
      case AnalysisTab.pgn:
        return l10n.studyPgnTags;
      case AnalysisTab.explorer:
        return l10n.openingExplorerAndTablebase;
      case AnalysisTab.moves:
        return l10n.movesPlayed;
      case AnalysisTab.summary:
        return l10n.computerAnalysis;
      case AnalysisTab.moveTimes:
        return l10n.moveTimes;
      case AnalysisTab.conditionalPremoves:
        return l10n.conditionalPremoves;
    }
  }
}

/// Layout for the analysis and similar screens (study, broadcast, etc.).
///
/// The layout is responsive and adapts to the screen size and orientation.
///
/// It includes a [TabBarView] with the [children] widgets. If a [TabController]
/// is not provided, then there must be a [DefaultTabController] ancestor.
///
/// The length of the [children] list must match the [tabController]'s
/// [TabController.length] and the length of the [AppBarAnalysisTabIndicator.tabs]
class const AnalysisLayout({
  /// The tab controller for the tab view.
  final TabController? tabController,

  /// If non-null, a tab indicator bar will be shown above the tab view.
  final List<AnalysisTab>? tabs,

  /// The builder for the board widget.
  required final BoardBuilder boardBuilder,

  /// The children of the tab view.
  ///
  /// The length of this list must match the [tabController]'s [TabController.length]
  /// and the length of the [tabs] list.
  required final List<Widget> children,

  /// The side the board is displayed from.
  required final Side pov,

  /// The side to move. In crazyhouse, this enables the [PocketsMenu] of this side.
  required final Side? sideToMove,

  /// A widget to show above the board.
  ///
  /// The widget will included in a parent container with a height of
  /// [kAnalysisBoardHeaderOrFooterHeight].
  final Widget? boardHeader,

  /// A widget to show below the board.
  ///
  /// The widget will included in a parent container with a height of
  /// [kAnalysisBoardHeaderOrFooterHeight].
  final Widget? boardFooter,

  /// A builder for the engine gauge widget.
  final EngineGaugeBuilder? engineGaugeBuilder,

  /// A widget to show below the engine gauge, typically the engine lines.
  final Widget? engineLines,

  /// A widget to show at the bottom of the screen.
  final Widget? bottomBar,

  /// The size of the board in portrait orientation, as a fraction of its full size.
  final double boardScale = 1.0,

  /// Called with the new [boardScale] when the user resizes the board with the handle at the top
  /// of the tab view.
  ///
  /// If null, the board cannot be resized.
  final ValueChanged<double>? onBoardScaleChanged,

  /// Current state of the pockets, in variants like crazyhouse.
  ///
  /// If not null, will render a [PocketsMenu] for each player.
  final Pockets? pockets,
  super.key,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final orientation = constraints.maxWidth > constraints.maxHeight
                    ? Orientation.landscape
                    : Orientation.portrait;
                final isTablet = isTabletOrLarger(context);
                const tabletBoardRadius = Styles.boardBorderRadius;

                final playerSide = switch (sideToMove) {
                  Side.white => PlayerSide.white,
                  Side.black => PlayerSide.black,
                  null => PlayerSide.none,
                };

                if (orientation == Orientation.landscape) {
                  final headerAndFooterHeight =
                      (boardHeader != null ? kAnalysisBoardHeaderOrFooterHeight : 0.0) +
                      (boardFooter != null ? kAnalysisBoardHeaderOrFooterHeight : 0.0);
                  final sideWidth =
                      constraints.biggest.longestSide - constraints.biggest.shortestSide;
                  final defaultBoardSize =
                      constraints.biggest.shortestSide - (kTabletBoardTableSidePadding * 2);
                  final boardSize =
                      (sideWidth >= 250
                          ? defaultBoardSize
                          : constraints.biggest.longestSide / kGoldenRatio -
                                (kTabletBoardTableSidePadding * 2)) -
                      headerAndFooterHeight;

                  final boardPrefs = ref.watch(boardPreferencesProvider);

                  return Padding(
                    padding: const EdgeInsets.all(kTabletBoardTableSidePadding),
                    child: Row(
                      textDirection: switch (boardPrefs.landscapeBoardPosition) {
                        .left => TextDirection.ltr,
                        .right => TextDirection.rtl,
                      },
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Column(
                          children: [
                            if (boardHeader != null)
                              Container(
                                // This key is used to preserve the state of the board header when the pov changes
                                key: ValueKey(pov.opposite),
                                decoration: BoxDecoration(
                                  borderRadius: isTablet
                                      ? tabletBoardRadius.copyWith(
                                          bottomLeft: Radius.zero,
                                          bottomRight: Radius.zero,
                                        )
                                      : null,
                                ),
                                clipBehavior: isTablet ? Clip.hardEdge : Clip.none,
                                child: SizedBox(
                                  height: kAnalysisBoardHeaderOrFooterHeight,
                                  width: boardSize,
                                  child: boardHeader,
                                ),
                              ),
                            boardBuilder(
                              context,
                              boardSize,
                              isTablet && boardHeader == null && boardFooter != null
                                  ? tabletBoardRadius
                                  : null,
                            ),
                            if (boardFooter != null)
                              Container(
                                // This key is used to preserve the state of the board footer when the pov changes
                                key: ValueKey(pov),
                                decoration: BoxDecoration(
                                  borderRadius: isTablet
                                      ? tabletBoardRadius.copyWith(
                                          topLeft: Radius.zero,
                                          topRight: Radius.zero,
                                        )
                                      : null,
                                ),
                                clipBehavior: isTablet ? Clip.hardEdge : Clip.none,
                                height: kAnalysisBoardHeaderOrFooterHeight,
                                width: boardSize,
                                child: boardFooter,
                              ),
                          ],
                        ),
                        if (engineGaugeBuilder != null) ...[
                          const SizedBox(width: 4.0),
                          Container(
                            clipBehavior: Clip.hardEdge,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(4.0)),
                            child: engineGaugeBuilder!(context),
                          ),
                        ],
                        const SizedBox(width: 16.0),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ?engineLines,
                              if (pockets != null)
                                Align(
                                  alignment: Alignment.center,
                                  child: PocketsMenu(
                                    side: pov.opposite,
                                    sideToMove: sideToMove,
                                    playerSide: playerSide,
                                    pockets: pockets!,
                                    squareSize: pocketSquareSize(
                                      boardSize: boardSize,
                                      isTablet: isTablet,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Card(
                                  clipBehavior: Clip.hardEdge,
                                  semanticContainer: false,
                                  child: _AnalysisTabView(
                                    tabs: tabs,
                                    controller: tabController,
                                    children: children,
                                  ),
                                ),
                              ),
                              if (pockets != null)
                                Align(
                                  alignment: Alignment.center,
                                  child: PocketsMenu(
                                    side: pov,
                                    sideToMove: sideToMove,
                                    playerSide: playerSide,
                                    pockets: pockets!,
                                    squareSize: pocketSquareSize(
                                      boardSize: boardSize,
                                      isTablet: isTablet,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  final evalGaugeSize = engineGaugeBuilder != null
                      ? getEvalGaugeWidth(context)
                      : 0.0;
                  final fullBoardSize = constraints.biggest.shortestSide - evalGaugeSize;

                  return _BoardResizer(
                    boardScale: boardScale,
                    onBoardScaleChanged: onBoardScaleChanged,
                    fullBoardSize: fullBoardSize,
                    builder: (context, scale, headerBuilder) {
                      final defaultBoardSize = scale * fullBoardSize;

                      // Measured with the full size board, so that the pockets padding does not
                      // jump while the board is being resized.
                      final remainingHeight = constraints.maxHeight - fullBoardSize;
                      final isSmallScreen = remainingHeight < kSmallHeightMinusBoard;
                      final additionalBoardSidePaddingForPockets = isSmallScreen ? 70.0 : 16.0;

                      final boardSize =
                          defaultBoardSize -
                          (isTablet ? kTabletBoardTableSidePadding * 2 : 0) -
                          (pockets != null ? additionalBoardSidePaddingForPockets : 0.0);

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ?engineLines,
                          Padding(
                            padding: isTablet
                                ? const EdgeInsets.all(kTabletBoardTableSidePadding)
                                : EdgeInsets.zero,
                            child: Column(
                              children: [
                                if (pockets != null)
                                  PocketsMenu(
                                    side: pov.opposite,
                                    sideToMove: sideToMove,
                                    playerSide: playerSide,
                                    pockets: pockets!,
                                    squareSize: pocketSquareSize(
                                      boardSize: boardSize,
                                      isTablet: isTablet,
                                    ),
                                  ),
                                if (boardHeader != null)
                                  // This key is used to preserve the state of the board header when the pov changes
                                  Container(
                                    key: ValueKey(pov.opposite),
                                    decoration: BoxDecoration(
                                      borderRadius: isTablet
                                          ? tabletBoardRadius.copyWith(
                                              bottomLeft: Radius.zero,
                                              bottomRight: Radius.zero,
                                            )
                                          : null,
                                    ),
                                    clipBehavior: isTablet ? Clip.hardEdge : Clip.none,
                                    height: kAnalysisBoardHeaderOrFooterHeight,
                                    child: boardHeader,
                                  ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    boardBuilder(
                                      context,
                                      boardSize,
                                      isTablet && boardHeader == null && boardFooter != null
                                          ? tabletBoardRadius
                                          : null,
                                    ),
                                    if (engineGaugeBuilder != null)
                                      SizedBox(
                                        height: boardSize,
                                        child: engineGaugeBuilder!(context),
                                      ),
                                  ],
                                ),
                                if (boardFooter != null)
                                  Container(
                                    // This key is used to preserve the state of the board footer when the pov changes
                                    key: ValueKey(pov),
                                    decoration: BoxDecoration(
                                      borderRadius: isTablet
                                          ? tabletBoardRadius.copyWith(
                                              topLeft: Radius.zero,
                                              topRight: Radius.zero,
                                            )
                                          : null,
                                    ),
                                    clipBehavior: isTablet ? Clip.hardEdge : Clip.none,
                                    height: kAnalysisBoardHeaderOrFooterHeight,
                                    child: boardFooter,
                                  ),
                                if (pockets != null)
                                  PocketsMenu(
                                    side: pov,
                                    sideToMove: sideToMove,
                                    playerSide: playerSide,
                                    pockets: pockets!,
                                    squareSize: pocketSquareSize(
                                      boardSize: boardSize,
                                      isTablet: isTablet,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: isTablet
                                  ? const EdgeInsets.symmetric(
                                      horizontal: kTabletBoardTableSidePadding,
                                    )
                                  : EdgeInsets.zero,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: ColorScheme.of(context).surfaceContainerLowest,
                                ),
                                child: _AnalysisTabView(
                                  tabs: tabs,
                                  controller: tabController,
                                  headerBuilder: headerBuilder,
                                  children: children,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }
              },
            ),
          ),
        ),
        ?bottomBar,
      ],
    );
  }
}

/// How much the board scale changes with the accessibility increase and decrease actions.
const _kBoardScaleStep = 0.1;

double _stepBoardScale(double scale, double delta) => (scale + delta).clamp(kMinBoardScale, 1.0);

String _percent(double scale) => '${(scale * 100).round()}%';

/// Builds the header of the tab view around the [tabBar], if any.
typedef _TabViewHeaderBuilder = Widget Function(Widget? tabBar);

/// Holds the board scale while the user drags the resize handle, and reports it once the drag ends
/// so that preferences are not written on every frame.
class const _BoardResizer({
  required final double boardScale,
  required final ValueChanged<double>? onBoardScaleChanged,
  required final double fullBoardSize,
  required final Widget Function(
    BuildContext context,
    double boardScale,
    _TabViewHeaderBuilder? headerBuilder,
  )
  builder,
}) extends StatefulWidget {
  @override
  State<_BoardResizer> createState() => _BoardResizerState();
}

class _BoardResizerState() extends State<_BoardResizer> {
  /// The scale being dragged to, or null when no drag is in progress.
  double? _dragScale;

  double get _scale => _dragScale ?? widget.boardScale;

  void _onDragUpdate(DragUpdateDetails details) {
    final scale = _stepBoardScale(_scale, details.primaryDelta! / widget.fullBoardSize);
    if (scale == _scale) return;
    if (scale == kMinBoardScale || scale == 1.0) HapticFeedback.selectionClick();
    setState(() => _dragScale = scale);
  }

  void _onDragEnd(DragEndDetails _) {
    final scale = _dragScale;
    if (scale == null) return;
    widget.onBoardScaleChanged!(scale);
    setState(() => _dragScale = null);
  }

  void _step(double delta) {
    widget.onBoardScaleChanged!(_stepBoardScale(_scale, delta));
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _scale,
      widget.onBoardScaleChanged == null
          ? null
          : (tabBar) => _BoardResizeHandle(
              boardScale: _scale,
              isDragging: _dragScale != null,
              onDragUpdate: _onDragUpdate,
              onDragEnd: _onDragEnd,
              onIncrease: () => _step(_kBoardScaleStep),
              onDecrease: () => _step(-_kBoardScaleStep),
              tabBar: tabBar,
            ),
    );
  }
}

/// A grab handle on top of the tab view: dragging it up shrinks the board and makes room for the
/// tabs, like pulling up a bottom sheet.
///
/// The whole header, tab bar included, reacts to vertical drags so the touch target stays large
/// while the visible handle stays slim.
class const _BoardResizeHandle({
  required final double boardScale,
  required final bool isDragging,
  required final GestureDragUpdateCallback onDragUpdate,
  required final GestureDragEndCallback onDragEnd,
  required final VoidCallback onIncrease,
  required final VoidCallback onDecrease,
  required final Widget? tabBar,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        child: ColoredBox(
          color: colorScheme.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                slider: true,
                label: 'Board size',
                value: _percent(boardScale),
                increasedValue: _percent(_stepBoardScale(boardScale, _kBoardScaleStep)),
                decreasedValue: _percent(_stepBoardScale(boardScale, -_kBoardScaleStep)),
                onIncrease: boardScale < 1.0 ? onIncrease : null,
                onDecrease: boardScale > kMinBoardScale ? onDecrease : null,
                child: SizedBox(
                  height: 14.0,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      width: isDragging ? 40.0 : 32.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: isDragging ? 0.8 : 0.4,
                        ),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),
                ),
              ),
              ?tabBar,
            ],
          ),
        ),
      ),
    );
  }
}

class const _AnalysisTabView({
  required final List<AnalysisTab>? tabs,
  required final TabController? controller,
  final _TabViewHeaderBuilder? headerBuilder,
  required final List<Widget> children,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const iconSize = 18.0;

    final tabBar = tabs != null && tabs!.length > 1
        ? Container(
            decoration: BoxDecoration(color: ColorScheme.of(context).surface),
            child: TabBar(
              controller: controller,
              tabs: tabs!
                  .map(
                    (tab) => Tooltip(
                      message: tab.l10n(context.l10n),
                      child: Tab(
                        height: iconSize + 8.0,
                        icon: Icon(tab.icon, size: iconSize, semanticLabel: tab.l10n(context.l10n)),
                      ),
                    ),
                  )
                  .toList(),
            ),
          )
        : null;

    return Column(
      children: [
        if (headerBuilder != null) headerBuilder!(tabBar) else ?tabBar,
        Expanded(
          child: TabBarView(controller: controller, children: children),
        ),
      ],
    );
  }
}

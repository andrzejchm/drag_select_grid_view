// Copyright (c) 2019 Simon Lightfoot
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart' hide SelectionChangedCallback;

import '../auto_scroll/auto_scroller_mixin.dart';
import '../drag_select_grid_view/selectable.dart';
import 'drag_select_grid_view_controller.dart';
import 'selection.dart';

/// Function signature for creating widgets based on the index and whether
/// it is selected or not.
typedef SelectableWidgetBuilder = Widget Function(
    BuildContext context, int index, bool selected);

/// Gesture that starts drag selection.
enum DragSelectionTrigger {
  /// Starts drag selection after a long press.
  longPress,

  /// Starts drag selection when horizontal movement wins the gesture arena.
  ///
  /// Vertical-first movement remains available to the grid's scroll view.
  ///
  /// Requires [DragSelectGridView.scrollDirection] to be [Axis.vertical];
  /// see [DragSelectGridView.dragSelectionTrigger] for what happens
  /// otherwise.
  horizontalDrag,
}

/// Grid that supports both dragging and tapping to select its items.
///
/// By default, a long-press enables selection. The user may select/unselect any
/// item by tapping on it. Dragging allows cascade select/unselect. The flag
/// [triggerSelectionOnTap] allows selection to be enabled by tapping.
///
/// Through auto-scroll, this widget adds the ability to select items that go
/// beyond screen bounds without having to stop the drag. To do so, this widget
/// creates two imaginary zones that, if reached by the pointer while dragging,
/// triggers the auto-scroll.
///
/// For vertical scrolling, the first zone is at the top, and triggers backward
/// auto-scrolling. The second is at the bottom, and triggers forward
/// auto-scrolling.
///
/// For horizontal scrolling, the first zone is at the left, and triggers
/// backward auto-scrolling. The second is at the right, and triggers forward
/// auto-scrolling.
class DragSelectGridView extends StatefulWidget {
  /// Default height of the hotspot that enables auto-scroll.
  static const defaultAutoScrollHotspotHeight = 64.0;

  /// Creates a grid that supports both dragging and tapping to select its
  /// items.
  ///
  /// It is possible to customize the height of the hotspot that enables
  /// auto-scroll by specifying [autoScrollHotspotHeight].
  ///
  /// The [gridController] provides information that can be used to update the
  /// UI to indicate whether there are selected items and how many are selected,
  /// besides allowing to directly update the selected items.
  ///
  /// By leaving [unselectOnWillPop] false, the items won't get unselected when
  /// the user tries to pop the route.
  ///
  /// The [itemBuilder] must be used to create widgets based on the index and
  /// whether they are selected or not.
  ///
  /// For information about the clause of the other parameters, refer to
  /// [GridView.builder].
  DragSelectGridView({
    super.key,
    double? autoScrollHotspotHeight,
    ScrollController? scrollController,
    this.gridController,
    this.triggerSelectionOnTap = false,
    this.dragSelectionTrigger = DragSelectionTrigger.longPress,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    required this.gridDelegate,
    required this.itemBuilder,
    this.itemCount,
    this.findChildIndexCallback,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.cacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.hitTestBehavior = HitTestBehavior.opaque,
    this.impliesAppBarDismissal = true,
  })  : assert(
          dragSelectionTrigger != DragSelectionTrigger.horizontalDrag ||
              scrollDirection != Axis.horizontal,
          'DragSelectionTrigger.horizontalDrag cannot be used with '
          'scrollDirection: Axis.horizontal, because both interpret '
          'horizontal pointer movement. Either use '
          'DragSelectionTrigger.longPress, or keep scrollDirection at '
          'Axis.vertical.',
        ),
        autoScrollHotspotHeight =
            autoScrollHotspotHeight ?? defaultAutoScrollHotspotHeight,
        scrollController = scrollController ?? ScrollController(),
        _ownsScrollController = scrollController == null;

  /// The extent of the hotspot that enables auto-scroll, measured along the
  /// scroll axis.
  ///
  /// For vertical scrolling, this is the height of the top and bottom hotspots.
  /// For horizontal scrolling, this is the width of the left and right hotspots.
  ///
  /// Defaults to [defaultAutoScrollHotspotHeight].
  final double autoScrollHotspotHeight;

  /// {@macro flutter.widgets.scroll_view.controller}
  ///
  /// Refer to [ScrollView.controller].
  final ScrollController scrollController;

  /// Whether the [scrollController] was created internally and should be
  /// disposed when the widget is removed from the tree.
  final bool _ownsScrollController;

  /// Controller of the grid.
  ///
  /// Provides information that can be used to update the UI to indicate whether
  /// there are selected items and how many are selected.
  ///
  /// Also allows to directly update the selected items.
  ///
  /// This controller may not be used after [DragSelectGridViewState] disposes,
  /// since [DragSelectGridViewController.dispose] will get called and the
  /// listeners are going to be cleaned up.
  final DragSelectGridViewController? gridController;

  /// Whether should start selection by tapping instead of long-pressing.
  ///
  /// Defaults to false.
  final bool triggerSelectionOnTap;

  /// Gesture that starts drag selection.
  ///
  /// [DragSelectionTrigger.longPress] preserves the default long-press
  /// behavior. [DragSelectionTrigger.horizontalDrag] lets horizontal-first
  /// movement claim drag selection while vertical-first movement remains
  /// available for scrolling.
  ///
  /// [DragSelectionTrigger.horizontalDrag] requires [scrollDirection] to be
  /// [Axis.vertical], since both would otherwise compete for horizontal
  /// pointer movement. This asserts in debug builds. In release builds,
  /// where asserts are stripped, the combination safely falls back to
  /// [DragSelectionTrigger.longPress] instead of wiring up two recognizers
  /// that would fight over the same gesture.
  ///
  /// Defaults to [DragSelectionTrigger.longPress].
  final DragSelectionTrigger dragSelectionTrigger;

  /// {@macro flutter.widgets.scroll_view.scrollDirection}
  ///
  /// Refer to [ScrollView.scrollDirection].
  final Axis scrollDirection;

  /// {@macro flutter.widgets.scroll_view.reverse}
  ///
  /// Refer to [ScrollView.reverse].
  final bool reverse;

  /// {@macro flutter.widgets.scroll_view.primary}
  ///
  /// Refer to [ScrollView.primary].
  final bool? primary;

  /// {@macro flutter.widgets.scroll_view.physics}
  ///
  /// Refer to [ScrollView.physics].
  final ScrollPhysics? physics;

  /// {@macro flutter.widgets.scroll_view.shrinkWrap}
  ///
  /// Refer to [ScrollView.shrinkWrap].
  final bool shrinkWrap;

  /// Refer to [BoxScrollView.padding].
  final EdgeInsetsGeometry? padding;

  /// Refer to [GridView.gridDelegate].
  final SliverGridDelegate gridDelegate;

  /// Called whenever a child needs to be built.
  ///
  /// The client should use this to build the children dynamically, based on
  /// the index and whether it is selected or not.
  ///
  /// Also refer to [SliverChildBuilderDelegate.builder].
  final SelectableWidgetBuilder itemBuilder;

  /// Refer to [SliverChildBuilderDelegate.childCount].
  final int? itemCount;

  /// {@macro flutter.widgets.SliverChildBuilderDelegate.findChildIndexCallback}
  ///
  /// Refer to [SliverChildBuilderDelegate.findChildIndexCallback].
  final ChildIndexGetter? findChildIndexCallback;

  /// {@macro flutter.widgets.SliverChildBuilderDelegate.addAutomaticKeepAlives}
  ///
  /// Refer to [SliverChildBuilderDelegate.addAutomaticKeepAlives].
  final bool addAutomaticKeepAlives;

  /// {@macro flutter.widgets.SliverChildBuilderDelegate.addRepaintBoundaries}
  ///
  /// Refer to [SliverChildBuilderDelegate.addRepaintBoundaries].
  final bool addRepaintBoundaries;

  /// {@macro flutter.widgets.SliverChildBuilderDelegate.addSemanticIndexes}
  ///
  /// Refer to [SliverChildBuilderDelegate.addSemanticIndexes].
  final bool addSemanticIndexes;

  /// {@macro flutter.rendering.RenderViewportBase.cacheExtent}
  ///
  /// Refer to [ScrollView.cacheExtent].
  final double? cacheExtent;

  /// Refer to [ScrollView.semanticChildCount].
  final int? semanticChildCount;

  /// {@macro flutter.widgets.scrollable.dragStartBehavior}
  ///
  /// Refer to [ScrollView.dragStartBehavior].
  final DragStartBehavior dragStartBehavior;

  /// {@macro flutter.widgets.scroll_view.keyboardDismissBehavior}
  ///
  /// Refer to [ScrollView.keyboardDismissBehavior].
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// {@macro flutter.widgets.scrollable.restorationId}
  ///
  /// Refer to [ScrollView.restorationId].
  final String? restorationId;

  /// {@macro flutter.material.Material.clipBehavior}
  ///
  /// Refer to [ScrollView.clipBehavior].
  final Clip clipBehavior;

  /// {@macro flutter.widgets.scrollable.hitTestBehavior}
  ///
  /// Refer to [ScrollView.hitTestBehavior].
  final HitTestBehavior hitTestBehavior;

  /// Refer to [LocalHistoryEntry.impliesAppBarDismissal].
  final bool impliesAppBarDismissal;

  @override
  DragSelectGridViewState createState() => DragSelectGridViewState();
}

/// The state for a grid that supports both dragging and tapping to select its
/// items.
@visibleForTesting
class DragSelectGridViewState extends State<DragSelectGridView>
    with AutoScrollerMixin<DragSelectGridView> {
  final _elements = <SelectableElement>{};
  final _selectionManager = SelectionManager();

  /// Pointers currently down, tracked from raw [PointerDownEvent]s so that
  /// [_activeDragSelectionTrigger] can be frozen for the whole pointer
  /// sequence, even before a recognizer accepts the gesture.
  final _activePointerIds = <int>{};

  Offset? _lastDragPosition;

  /// Down position of every pointer currently active, keyed by pointer id.
  ///
  /// Tracked per pointer - rather than only for the current candidate - so
  /// that if the candidate pointer lifts before starting a drag, the next
  /// remaining pointer can be promoted using its own down position, instead
  /// of falling back to a post-slop position or inheriting the previous
  /// candidate's.
  final _pointerDownPositions = <int, Offset>{};

  /// Id of the pointer that is the current candidate to start a drag
  /// selection.
  ///
  /// Set on pointer-down and consumed once a drag-selection gesture starts,
  /// so a later finger touching down can't overwrite it.
  int? _pointerDownPointerId;

  /// [widget.dragSelectionTrigger] frozen for the duration of the current
  /// pointer sequence, so switching it mid-gesture (e.g. via a rebuild)
  /// doesn't change which recognizers are wired up and tear down a
  /// recognizer that's still tracking the pointer.
  DragSelectionTrigger? _activeDragSelectionTrigger;

  /// Whether more than one pointer was down at the same time before a
  /// horizontal-drag selection started for the current pointer sequence.
  ///
  /// Flutter's `HorizontalDragGestureRecognizer` may end up tracking a
  /// different pointer than the one this sequence anchored to once a second
  /// pointer joins, so rather than guessing which pointer "won", no range
  /// selection is started at all for that sequence. Reset once the whole
  /// pointer sequence fully ends.
  bool _hasMultiplePointersDown = false;

  LocalHistoryEntry? _historyEntry;

  DragSelectGridViewController? get _gridController => widget.gridController;

  /// The [widget.dragSelectionTrigger] that should actually be wired up.
  ///
  /// The constructor already asserts that [DragSelectionTrigger.horizontalDrag]
  /// isn't combined with a horizontal [DragSelectGridView.scrollDirection] in
  /// debug builds; this is the release-mode (asserts stripped) safety net for
  /// that same combination, so a horizontally scrolling grid never wires up a
  /// horizontal-drag selection recognizer that would fight the grid's own
  /// horizontal scrolling.
  DragSelectionTrigger get _configuredDragSelectionTrigger =>
      resolveDragSelectionTrigger(
        trigger: widget.dragSelectionTrigger,
        scrollDirection: widget.scrollDirection,
      );

  /// Resolves the [DragSelectionTrigger] that should actually be wired up
  /// for a given [trigger] and [scrollDirection].
  ///
  /// Falls back to [DragSelectionTrigger.longPress] when [trigger] is
  /// [DragSelectionTrigger.horizontalDrag] combined with a horizontal
  /// [scrollDirection], since both would otherwise compete for the same
  /// horizontal pointer movement. Pure and side-effect-free, so it's testable
  /// on its own without constructing a widget (which asserts against this
  /// same combination in debug builds).
  @visibleForTesting
  static DragSelectionTrigger resolveDragSelectionTrigger({
    required DragSelectionTrigger trigger,
    required Axis scrollDirection,
  }) {
    final isInvalidHorizontalCombination =
        trigger == DragSelectionTrigger.horizontalDrag &&
            scrollDirection == Axis.horizontal;
    return isInvalidHorizontalCombination
        ? DragSelectionTrigger.longPress
        : trigger;
  }

  /// Indexes selected by dragging or tapping.
  Set<int> get selectedIndexes => _selectionManager.selectedIndexes;

  /// Whether any item got selected.
  bool get isSelecting => selectedIndexes.isNotEmpty;

  /// Whether drag gesture is being performed.
  bool get isDragging =>
      (_selectionManager.dragStartIndex != -1) &&
      (_selectionManager.dragEndIndex != -1);

  @override
  double get autoScrollHotspotHeight => widget.autoScrollHotspotHeight;

  @override
  Axis get scrollDirection => widget.scrollDirection;

  @override
  ScrollController get scrollController => widget.scrollController;

  @override
  void handleScroll() {
    final position = _lastDragPosition;
    if (position != null) _updateDragSelection(position);
  }

  @override
  void initState() {
    super.initState();
    _gridController?.addListener(_onSelectionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _onSelectionChanged();
  }

  @override
  void dispose() {
    _gridController?.removeListener(_onSelectionChanged);
    if (widget._ownsScrollController) {
      scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      triggerAutoScrollIfNeeded();
    });

    final dragSelectionTrigger =
        _activeDragSelectionTrigger ?? _configuredDragSelectionTrigger;
    final callbacks = _dragSelectionCallbacksFor(dragSelectionTrigger);

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: GestureDetector(
        onTapUp: _handleTapUp,
        onLongPressStart: callbacks.onLongPressStart,
        onLongPressMoveUpdate: callbacks.onLongPressMoveUpdate,
        onLongPressEnd: callbacks.onLongPressEnd,
        onHorizontalDragStart: callbacks.onHorizontalDragStart,
        onHorizontalDragUpdate: callbacks.onHorizontalDragUpdate,
        onHorizontalDragEnd: callbacks.onHorizontalDragEnd,
        behavior: HitTestBehavior.translucent,
        child: IgnorePointer(
          ignoring: isDragging,
          child: GridView.builder(
            controller: widget.scrollController,
            scrollDirection: widget.scrollDirection,
            reverse: widget.reverse,
            primary: widget.primary,
            physics: widget.physics,
            shrinkWrap: widget.shrinkWrap,
            padding: widget.padding,
            gridDelegate: widget.gridDelegate,
            itemCount: widget.itemCount,
            findChildIndexCallback: widget.findChildIndexCallback,
            addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
            addRepaintBoundaries: widget.addRepaintBoundaries,
            addSemanticIndexes: widget.addSemanticIndexes,
            cacheExtent: widget.cacheExtent,
            semanticChildCount: widget.semanticChildCount,
            dragStartBehavior: widget.dragStartBehavior,
            keyboardDismissBehavior: widget.keyboardDismissBehavior,
            restorationId: widget.restorationId,
            clipBehavior: widget.clipBehavior,
            hitTestBehavior: widget.hitTestBehavior,
            itemBuilder: (context, index) {
              return IgnorePointer(
                ignoring: isSelecting || widget.triggerSelectionOnTap,
                child: Selectable(
                  index: index,
                  onMountElement: _elements.add,
                  onUnmountElement: _elements.remove,
                  child: widget.itemBuilder(
                    context,
                    index,
                    selectedIndexes.contains(index),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Gesture-recognizer callbacks that implement [trigger], with the other
  /// trigger's callbacks left `null` so its recognizer never claims the
  /// gesture arena.
  ({
    GestureLongPressStartCallback? onLongPressStart,
    GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate,
    GestureLongPressEndCallback? onLongPressEnd,
    GestureDragStartCallback? onHorizontalDragStart,
    GestureDragUpdateCallback? onHorizontalDragUpdate,
    GestureDragEndCallback? onHorizontalDragEnd,
  }) _dragSelectionCallbacksFor(DragSelectionTrigger trigger) =>
      switch (trigger) {
        DragSelectionTrigger.longPress => (
            onLongPressStart: _handleLongPressStart,
            onLongPressMoveUpdate: _handleLongPressMoveUpdate,
            onLongPressEnd: _handleLongPressEnd,
            onHorizontalDragStart: null,
            onHorizontalDragUpdate: null,
            onHorizontalDragEnd: null,
          ),
        DragSelectionTrigger.horizontalDrag => (
            onLongPressStart: null,
            onLongPressMoveUpdate: null,
            onLongPressEnd: null,
            onHorizontalDragStart: _handleHorizontalDragStart,
            onHorizontalDragUpdate: _handleHorizontalDragUpdate,
            onHorizontalDragEnd: _handleHorizontalDragEnd,
          ),
      };

  void _onSelectionChanged() {
    final controller = _gridController;
    if (controller != null) {
      final controllerSelectedIndexes = controller.value.selectedIndexes;
      if (!setEquals(controllerSelectedIndexes, selectedIndexes)) {
        setState(
          () => _selectionManager.selectedIndexes = controllerSelectedIndexes,
        );
        _updateLocalHistory();
      }
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (isSelecting || widget.triggerSelectionOnTap) {
      final tapIndex = _findIndexOfSelectable(details.localPosition);

      if (tapIndex != -1) {
        setState(() => _selectionManager.tap(tapIndex));
        _notifySelectionChange();
        _updateLocalHistory();
      }
    }
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    _startDragSelection(details.localPosition);
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    _updateDragSelection(details.localPosition);
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    _endDragSelection();
  }

  void _handlePointerDown(PointerDownEvent event) {
    final isFirstActivePointer = _activePointerIds.isEmpty;
    _activePointerIds.add(event.pointer);

    // Freeze the trigger for the whole pointer sequence so a mid-gesture
    // rebuild (e.g. `setState` elsewhere) can't swap which recognizer is
    // wired up and tear down one that's still tracking the pointer.
    if (isFirstActivePointer) {
      _activeDragSelectionTrigger = _configuredDragSelectionTrigger;
    } else if (!isDragging) {
      // A second (or further) pointer joined before any selection started;
      // see `_hasMultiplePointersDown`.
      _hasMultiplePointersDown = true;
    }

    // Every pointer's own down position is kept, so a later pointer that
    // gets promoted to candidate (see `_handlePointerSequenceEnd`) anchors
    // to where it actually went down.
    _pointerDownPositions[event.pointer] = event.localPosition;

    // Only the first pointer down is a candidate for starting a drag
    // selection; a second finger touching down must not overwrite it.
    _pointerDownPointerId ??= event.pointer;
  }

  void _handlePointerUp(PointerUpEvent event) =>
      _handlePointerSequenceEnd(event.pointer);

  void _handlePointerCancel(PointerCancelEvent event) =>
      _handlePointerSequenceEnd(event.pointer);

  void _handlePointerSequenceEnd(int pointerId) {
    _activePointerIds.remove(pointerId);
    _pointerDownPositions.remove(pointerId);

    if (_pointerDownPointerId == pointerId) {
      // Promote the next remaining pointer (if any) as the new candidate,
      // using its own down position rather than the one that just lifted.
      _pointerDownPointerId =
          _activePointerIds.isEmpty ? null : _activePointerIds.first;
    }

    if (_activePointerIds.isEmpty) {
      _activeDragSelectionTrigger = null;
      _hasMultiplePointersDown = false;
    }
  }

  void _handleHorizontalDragStart(DragStartDetails details) {
    final pointerId = _pointerDownPointerId;
    final startPosition =
        (pointerId == null ? null : _pointerDownPositions[pointerId]) ??
            details.localPosition;
    if (pointerId != null) _pointerDownPositions.remove(pointerId);
    _pointerDownPointerId = null;

    // Flutter's `HorizontalDragGestureRecognizer` may end up tracking a
    // different pointer than the one this sequence anchored to when more
    // than one pointer was down before the drag started, so don't guess -
    // just don't start a range selection for this pointer sequence.
    if (_hasMultiplePointersDown) return;

    _startDragSelection(startPosition);
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    _updateDragSelection(details.localPosition);
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    _endDragSelection();
  }

  void _startDragSelection(Offset position) {
    final pressIndex = _findIndexOfSelectable(position);

    if (pressIndex != -1) {
      setState(() => _selectionManager.startDrag(pressIndex));
      _notifySelectionChange();
      _updateLocalHistory();
    }
  }

  void _updateDragSelection(Offset position) {
    if (!isDragging) return;

    _lastDragPosition = position;
    var dragIndex = _findIndexOfSelectable(position);

    if (dragIndex == -1) {
      dragIndex = _findIndexOfSelectableInEmptySpace(position);
    }

    if ((dragIndex != -1) && (dragIndex != _selectionManager.dragEndIndex)) {
      setState(() => _selectionManager.updateDrag(dragIndex));
      _notifySelectionChange();
    }

    if (isInsideStartAutoScrollHotspot(position)) {
      if (widget.reverse) {
        startAutoScrollingForward();
      } else {
        startAutoScrollingBackward();
      }
    } else if (isInsideEndAutoScrollHotspot(position)) {
      if (widget.reverse) {
        startAutoScrollingBackward();
      } else {
        startAutoScrollingForward();
      }
    } else {
      stopScrolling();
    }
  }

  void _endDragSelection() {
    setState(() {
      _selectionManager.endDrag();
      _activeDragSelectionTrigger = null;
    });
    _lastDragPosition = null;
    stopScrolling();
  }

  void _updateLocalHistory() {
    final route = ModalRoute.of(context);
    if (route == null) return;

    if (isSelecting) {
      if (_historyEntry == null) {
        final entry = LocalHistoryEntry(
          impliesAppBarDismissal: widget.impliesAppBarDismissal,
          onRemove: () {
            setState(_selectionManager.clear);
            _notifySelectionChange();
            _historyEntry = null;
          },
        );
        route.addLocalHistoryEntry(entry);
        _historyEntry = entry;
      }
    } else {
      final entry = _historyEntry;
      if (entry != null) {
        route.removeLocalHistoryEntry(entry);
        _historyEntry = null;
      }
    }
  }

  int _findIndexOfSelectable(Offset offset) {
    final ancestor = context.findRenderObject();
    if (ancestor == null) return -1;

    var elementFinder = _elements.firstWhereOrNull;

    // Conceptually, `Set.singleWhere()` is the safer option, however we're
    // avoiding to iterate over the whole `Set` to improve the performance.
    assert(() {
      elementFinder = _elements.singleWhereOrNull;
      return true;
    }());

    final element = elementFinder(
      (element) => element.containsOffset(ancestor, offset),
    );

    return (element == null) ? -1 : element.widget.index;
  }

  /// Finds the nearest item index when the drag position is outside all items.
  ///
  /// Returns -1 if the offset is not in any empty space around the items.
  int _findIndexOfSelectableInEmptySpace(Offset offset) {
    final ancestor = context.findRenderObject();
    if (ancestor == null || _elements.isEmpty) return -1;

    return _findLastIndexPastItems(ancestor, offset) ??
        _findFirstIndexBeforeItems(ancestor, offset) ??
        -1;
  }

  /// Returns the last item's index if [offset] is past or beside it,
  /// or `null` otherwise.
  ///
  /// Handles trailing empty space in a partial last row and offsets
  /// that are entirely past all items.
  int? _findLastIndexPastItems(RenderObject ancestor, Offset offset) {
    final lastElement = _elements.reduce(
      (a, b) => a.widget.index > b.widget.index ? a : b,
    );

    final lastRect = _elementRect(lastElement, ancestor);

    final isOnSameRow =
        offset.dy >= lastRect.top && offset.dy < lastRect.bottom;
    final isPastLastItemHorizontally = offset.dx >= lastRect.right;

    final isPastAllItems = widget.reverse
        ? offset.dy < lastRect.top
        : offset.dy >= lastRect.bottom;

    if ((isOnSameRow && isPastLastItemHorizontally) || isPastAllItems) {
      return lastElement.widget.index;
    }

    return null;
  }

  /// Returns the first item's index if [offset] is before all items,
  /// or `null` otherwise.
  int? _findFirstIndexBeforeItems(RenderObject ancestor, Offset offset) {
    final firstElement = _elements.reduce(
      (a, b) => a.widget.index < b.widget.index ? a : b,
    );

    final firstRect = _elementRect(firstElement, ancestor);

    final isBeforeAllItems = widget.reverse
        ? offset.dy >= firstRect.bottom
        : offset.dy < firstRect.top;

    return isBeforeAllItems ? firstElement.widget.index : null;
  }

  Rect _elementRect(SelectableElement element, RenderObject ancestor) {
    final box = element.renderObject as RenderBox;
    return box.localToGlobal(Offset.zero, ancestor: ancestor) & box.size;
  }

  void _notifySelectionChange() {
    _gridController?.value = Selection(_selectionManager.selectedIndexes);
  }
}

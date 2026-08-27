import 'package:drag_select_grid_view/drag_select_grid_view.dart';
import 'package:drag_select_grid_view/src/auto_scroll/auto_scroll.dart';
import 'package:drag_select_grid_view/src/drag_select_grid_view/drag_select_grid_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide SelectionChangedCallback;
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';

void main() {
  final gridFinder = find.byType(DragSelectGridView);
  final emptySpaceFinder = find.byKey(const ValueKey('empty-space'));

  final firstItemFinder = find.byKey(const ValueKey('grid-item-0'));
  final lastItemFinder = find.byKey(const ValueKey('grid-item-11'));

  late DragSelectGridViewState dragSelectState;

  late Offset mainAxisItemsDistance;
  late Offset crossAxisItemsDistance;

  /// Creates a [DragSelectGridView] with 4 columns and 3 lines, based on
  /// [screenHeight] and [screenWidth].
  Widget createWidget({
    DragSelectGridViewController? gridController,
    Axis? scrollDirection,
    bool? reverse,
    bool? triggerSelectionOnTap,
    DragSelectionTrigger? dragSelectionTrigger,
  }) {
    return MaterialApp(
      home: Row(
        children: [
          const SizedBox(
            key: ValueKey('empty-space'),
            height: double.infinity,
            width: 10,
          ),
          Expanded(
            child: DragSelectGridView(
              gridController: gridController,
              scrollDirection: scrollDirection ?? Axis.vertical,
              reverse: reverse ?? false,
              itemCount: 12,
              itemBuilder: (_, index, __) => Container(
                key: ValueKey('grid-item-$index'),
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
              ),
              triggerSelectionOnTap: triggerSelectionOnTap ?? false,
              dragSelectionTrigger:
                  dragSelectionTrigger ?? DragSelectionTrigger.longPress,
            ),
          )
        ],
      ),
    );
  }

  /// Notice that this is not a call to the the native [setUp] function.
  /// I could not use it because I need [WidgetTester] as a parameter to avoid
  /// creating the widget at every single [testWidgets].
  /// I get access to [WidgetTester], but in counterpart I have to call [setUp]
  /// manually at the initialization of every [testWidgets].
  Future<void> setUp(
    WidgetTester tester, {
    DragSelectGridViewController? gridController,
    Axis? scrollDirection,
    bool? reverse,
    bool? triggerSelectionOnTap,
    DragSelectionTrigger? dragSelectionTrigger,
  }) async {
    final widget = createWidget(
      gridController: gridController,
      scrollDirection: scrollDirection,
      reverse: reverse,
      triggerSelectionOnTap: triggerSelectionOnTap,
      dragSelectionTrigger: dragSelectionTrigger,
    );

    await tester.pumpWidget(widget);
    dragSelectState = tester.state(gridFinder);

    final secondItemFinder = find.byKey(const ValueKey('grid-item-1'));
    mainAxisItemsDistance =
        tester.getCenter(secondItemFinder) - tester.getCenter(firstItemFinder);

    final fifthItemFinder = find.byKey(const ValueKey('grid-item-4'));
    crossAxisItemsDistance =
        tester.getCenter(fifthItemFinder) - tester.getCenter(firstItemFinder);
  }

  testWidgets(
    "When DragSelectGridView is created with zero items, "
    "then it renders without errors.",
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DragSelectGridView(
            itemCount: 0,
            itemBuilder: (_, index, __) => Container(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
            ),
          ),
        ),
      );

      expect(find.byType(DragSelectGridView), findsOneWidget);
    },
  );

  testWidgets(
    "When DragSelectGridView is created with a single item, "
    "then tapping it selects it.",
    (tester) async {
      final controller = DragSelectGridViewController();

      await tester.pumpWidget(
        MaterialApp(
          home: DragSelectGridView(
            gridController: controller,
            triggerSelectionOnTap: true,
            itemCount: 1,
            itemBuilder: (_, index, __) => Container(
              key: ValueKey('item-$index'),
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
            ),
          ),
        ),
      );

      final state = tester.state(find.byType(DragSelectGridView))
          as DragSelectGridViewState;

      expect(state.isSelecting, isFalse);

      await tester.tap(
        find.byKey(const ValueKey('item-0')),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(state.isSelecting, isTrue);
      expect(state.selectedIndexes, {0});
    },
  );

  testWidgets(
    "When DragSelectGridView is initiated, "
    "then it starts listening to the controller.",
    (tester) async {
      final controller = DragSelectGridViewController();

      // Initially, the controller is not listened to.
      // ignore: invalid_use_of_protected_member
      expect(controller.hasListeners, isFalse);

      // When DragSelectGridView is initiated,
      await setUp(tester, gridController: controller);

      // then it starts listening to the controller.
      // ignore: invalid_use_of_protected_member
      expect(controller.hasListeners, isTrue);
    },
    skip: false,
  );

  testWidgets(
    "When DragSelectGridView is created without a ScrollController, "
    "then the internally created ScrollController is disposed "
    "when the widget is removed from the tree.",
    (tester) async {
      await setUp(tester);

      // Grab the internally created ScrollController.
      final internalScrollController = dragSelectState.scrollController;

      // Initially, the controller has clients (is attached).
      expect(internalScrollController.hasClients, isTrue);

      // When DragSelectGridView is removed from the tree,
      await tester.pumpWidget(Container());

      // then the internally created ScrollController should be disposed.
      // Adding a listener on a disposed ChangeNotifier throws.
      expect(
        () => internalScrollController.addListener(() {}),
        throwsFlutterError,
      );
    },
  );

  testWidgets(
    "When DragSelectGridView is created with an external ScrollController, "
    "then the external ScrollController is NOT disposed "
    "when the widget is removed from the tree.",
    (tester) async {
      final externalController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: DragSelectGridView(
            scrollController: externalController,
            itemCount: 12,
            itemBuilder: (_, index, __) => Container(
              key: ValueKey('grid-item-$index'),
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
            ),
          ),
        ),
      );

      // When DragSelectGridView is removed from the tree,
      await tester.pumpWidget(Container());

      // then the external ScrollController should NOT be disposed.
      // We can still safely access it without throwing.
      expect(() => externalController.hasClients, returnsNormally);

      // Clean up.
      externalController.dispose();
    },
  );

  testWidgets(
    "When DragSelectGridView is disposed, "
    "then it stops listening to the controller.",
    (tester) async {
      final controller = DragSelectGridViewController();
      await setUp(tester, gridController: controller);

      // Initially, the controller is listened to.
      // ignore: invalid_use_of_protected_member
      expect(controller.hasListeners, isTrue);

      // When DragSelectGridView is disposed,
      await tester.pumpWidget(Container());

      // then it stops listening to the controller.
      // ignore: invalid_use_of_protected_member
      expect(controller.hasListeners, isFalse);
    },
    skip: false,
  );

  group("Drag-select-grid-view integration tests.", () {
    group("Select by pressing.", () {
      testWidgets(
        "Given that `triggerSelectionOnTap` is false, "
        "when an item of DragSelectGridView is long-pressed down, "
        "then `isSelecting` and `isDragging` become true.",
        (tester) async {
          await setUp(tester);

          // Initially, `isSelecting` and `isDragging` are false.
          expect(dragSelectState.isSelecting, isFalse);
          expect(dragSelectState.isDragging, isFalse);

          // Given that `triggerSelectionOnTap` is false,
          expect(dragSelectState.widget.triggerSelectionOnTap, isFalse);

          // When an item of DragSelectGridView is long-pressed down,
          await longPressDown(tester: tester, finder: gridFinder);
          await tester.pump();

          // then `isSelecting` and `isDragging` become true.
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.isDragging, isTrue);
        },
        skip: false,
      );

      testWidgets(
        "Given that `triggerSelectionOnTap` is true, "
        "when an item of DragSelectGridView is tapped, "
        "then `isSelecting` becomes true "
        "and `isDragging` continues false.",
        (tester) async {
          await setUp(tester, triggerSelectionOnTap: true);

          // Initially, `isSelecting` and `isDragging` are false.
          expect(dragSelectState.isSelecting, isFalse);
          expect(dragSelectState.isDragging, isFalse);

          // Given that `triggerSelectionOnTap` is true,
          expect(dragSelectState.widget.triggerSelectionOnTap, isTrue);

          // When an item of DragSelectGridView is tapped,
          await tester.tap(gridFinder);
          await tester.pump();

          // then `isSelecting` becomes true
          expect(dragSelectState.isSelecting, isTrue);

          // and `isDragging` continues false.
          expect(dragSelectState.isDragging, isFalse);
        },
        skip: false,
      );

      testWidgets(
        "Given that an item of DragSelectGridView was long-pressed down, "
        "when the item is long-pressed up, "
        "then `isDragging` becomes false.",
        (tester) async {
          await setUp(tester);

          // Given that an item of DragSelectGridView was long-pressed down,
          final gesture =
              await longPressDown(tester: tester, finder: gridFinder);
          await tester.pump();

          // when the item is long-pressed up,
          await gesture.up();
          await tester.pump();

          // then `isDragging` becomes false.
          expect(dragSelectState.isDragging, isFalse);
        },
        skip: false,
      );

      testWidgets(
        "When an empty space of DragSelectGridView is long-pressed, "
        "then `isDragging` doesn't change.",
        (tester) async {
          await setUp(tester);

          // Initially, `isDragging` is false.
          expect(dragSelectState.isDragging, isFalse);

          // When an empty space of DragSelectGridView is long-pressed.
          await tester.longPress(emptySpaceFinder, warnIfMissed: false);
          await tester.pump();

          // then `isDragging` doesn't change.
          expect(dragSelectState.isDragging, isFalse);
        },
        skip: false,
      );

      testWidgets(
        "Given that the grid has 4 columns and 3 lines, "
        "and that the first item of the grid is UNSELECTED, "
        ""
        "when the first item of the grid is long-pressed, "
        ""
        "then the item gets selected, "
        "and we get notified about selection change.",
        (tester) async {
          var selectionChangeCount = 0;

          final gridController = DragSelectGridViewController()
            ..addListener(() => selectionChangeCount++);

          // Given that the grid has 4 columns and 3 lines,
          await setUp(tester, gridController: gridController);

          // and that the first item of the grid is UNSELECTED,
          expect(dragSelectState.selectedIndexes, <int>{});

          // when the first item of the grid is long-pressed,
          await tester.longPress(firstItemFinder, warnIfMissed: false);
          await tester.pump();

          // then the item gets selected.
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.selectedIndexes, {0});

          // and we get notified about selection change.
          expect(selectionChangeCount, 1);
        },
        skip: false,
      );

      testWidgets(
        "Given that the grid has 4 columns and 3 lines, "
        "and that the first item of the grid is UNSELECTED, "
        ""
        "when the first item of the grid is tapped, "
        ""
        "then the item stills UNSELECTED.",
        (tester) async {
          // Given that the grid has 4 columns and 3 lines,
          await setUp(tester);

          // and that the first item of the grid is UNSELECTED,
          expect(dragSelectState.selectedIndexes, <int>{});

          // when the first item of the grid is tapped,
          await tester.tap(firstItemFinder, warnIfMissed: false);
          await tester.pump();

          // then the item stills UNSELECTED.
          expect(dragSelectState.isSelecting, isFalse);
          expect(dragSelectState.selectedIndexes, <int>{});
        },
        skip: false,
      );

      testWidgets(
        "Given that the grid has 4 columns and 3 lines, "
        "and that the first item of the grid is selected, "
        ""
        "when the first item is long-pressed, "
        ""
        "then the item stills selected.",
        (tester) async {
          // Given that the grid has 4 columns and 3 lines,
          await setUp(tester);

          // and that the first item of the grid is selected,
          await tester.longPress(firstItemFinder, warnIfMissed: false);
          await tester.pump();

          // when the first item is long-pressed,
          await tester.longPress(firstItemFinder, warnIfMissed: false);
          await tester.pump();

          // then the item stills selected.
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.selectedIndexes, {0});
        },
        skip: false,
      );

      testWidgets(
        "Given that the grid has 4 columns and 3 lines, "
        "and that the first item of the grid is selected, "
        ""
        "when the item is tapped, "
        ""
        "then the item gets UNSELECTED.",
        (tester) async {
          // Given that the grid has 4 columns and 3 lines,
          await setUp(tester);

          // and that the first item of the grid is selected,
          await tester.longPress(firstItemFinder, warnIfMissed: false);
          await tester.pump();

          // when the item is tapped,
          await tester.tap(firstItemFinder, warnIfMissed: false);
          await tester.pump();

          // then the item stills selected.
          expect(dragSelectState.isSelecting, isFalse);
          expect(dragSelectState.selectedIndexes, <int>{});
        },
        skip: false,
      );
    });

    group("Select by dragging forward.", () {
      testWidgets(
        "Given that the grid has 4 columns and 3 lines, "
        "and that the first item was long-pressed and selected, "
        ""
        "when dragging to the second item (at the right), "
        ""
        "then the second item gets selected, "
        "and the first item stills selected, "
        "and we get notified about selection changes.",
        (tester) async {
          var selectionChangeCount = 0;

          final gridController = DragSelectGridViewController()
            ..addListener(() => selectionChangeCount++);

          // Given that the grid has 4 columns and 3 lines,
          await setUp(tester, gridController: gridController);

          // and that the first item was long-pressed and selected,
          var gesture = await longPressDown(
            tester: tester,
            finder: firstItemFinder,
          );
          await tester.pump();

          // when dragging to the second item (at the right),
          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: mainAxisItemsDistance,
          );
          await gesture.up();
          await tester.pump();

          // then the second item gets selected,
          // and the first item stills selected.
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.selectedIndexes, {0, 1});

          // and we get notified about selection changes.
          expect(selectionChangeCount, 2);
        },
        skip: false,
      );

      testWidgets(
        "Given that the grid has 4 columns and 3 lines, "
        "and that the first item was long-pressed and selected, "
        "and that the second item was selected by dragging, "
        ""
        "when dragging back to the first item, "
        ""
        "then the second item gets UNSELECTED, "
        "and the first item stills selected.",
        (tester) async {
          // Given that the grid has 4 columns and 3 lines,
          await setUp(tester);

          // and that the first item was long-pressed and selected,
          var gesture = await longPressDown(
            tester: tester,
            finder: firstItemFinder,
          );
          await tester.pump();

          // and that the second item was selected by dragging,
          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: mainAxisItemsDistance,
          );
          await tester.pump();

          // when dragging back to the first item,
          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: -mainAxisItemsDistance,
          );
          await gesture.up();
          await tester.pump();

          // then the second item gets UNSELECTED,
          // and the first item stills selected.
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.selectedIndexes, {0});
        },
        skip: false,
      );

      testWidgets(
        "Given that the grid has 4 columns and 3 lines, "
        "and that the first item was long-pressed and selected, "
        ""
        "when dragging to the third item, passing through the second item, "
        ""
        "then the second and the third item get selected, "
        "and the first item stills selected.",
        (tester) async {
          // Given that the grid has 4 columns and 3 lines,
          await setUp(tester);

          // and that the first item was long-pressed and selected,
          var gesture = await longPressDown(
            tester: tester,
            finder: firstItemFinder,
          );
          await tester.pump();

          // when dragging to the third item, passing through the second item,

          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: mainAxisItemsDistance,
          );
          await tester.pump();

          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: mainAxisItemsDistance,
          );
          await gesture.up();
          await tester.pump();

          // then the second and the third item get selected,
          // and the first item stills selected.
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.selectedIndexes, {0, 1, 2});
        },
        skip: false,
      );

      testWidgets(
        "Given that the grid has 4 columns and 3 lines, "
        "and that the first item was long-pressed and selected, "
        "and that the second and third items were selected by dragging, "
        ""
        "when dragging back to the first item, "
        "passing through the second item, "
        ""
        "then the third and the second item get UNSELECTED, "
        "and the first item stills selected.",
        (tester) async {
          // Given that the grid has 4 columns and 3 lines,
          await setUp(tester);

          // and that the first item was long-pressed and selected,
          var gesture = await longPressDown(
            tester: tester,
            finder: firstItemFinder,
          );
          await tester.pump();

          // and that the second and third items were selected by dragging,
          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: mainAxisItemsDistance * 2,
          );
          await tester.pump();

          // when dragging back to the first item,
          // passing through the second item,

          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: -mainAxisItemsDistance,
          );
          await tester.pump();

          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: -mainAxisItemsDistance,
          );
          await gesture.up();
          await tester.pump();

          // then the third and the second item get UNSELECTED,
          // and the first item stills selected.
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.selectedIndexes, {0});
        },
        skip: false,
      );

      testWidgets(
        "Given that the grid has 4 columns and 3 lines, "
        "and that the first item was long-pressed and selected, "
        ""
        "when dragging to the fifth item (at the bottom), "
        ""
        "then all items from the second to the fifth get selected, "
        "and the first item stills selected.",
        (tester) async {
          // Given that the grid has 4 columns and 3 lines,
          await setUp(tester);

          // and that the first item was long-pressed and selected,
          var gesture = await longPressDown(
            tester: tester,
            finder: firstItemFinder,
          );
          await tester.pump();

          // when dragging to the fifth item (at the bottom),
          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: crossAxisItemsDistance,
          );
          await gesture.up();
          await tester.pump();

          // then all items from the second to the fifth get selected,
          // and the first item stills selected.
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.selectedIndexes, {0, 1, 2, 3, 4});
        },
        skip: false,
      );

      testWidgets(
        "Given that the grid has 4 columns and 3 lines, "
        "and that the first item was long-pressed and selected, "
        "and that all items from the second to the fifth "
        "were selected by dragging, "
        ""
        "when dragging back to the first item, "
        ""
        "then all items from the fifth to the second get UNSELECTED, "
        "and the first item stills selected.",
        (tester) async {
          // Given that the grid has 4 columns and 3 lines,
          await setUp(tester);

          // and that the first item was long-pressed and selected,
          var gesture = await longPressDown(
            tester: tester,
            finder: firstItemFinder,
          );
          await tester.pump();

          // and that all items from the second to the fifth
          // were selected by dragging,
          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: crossAxisItemsDistance,
          );
          await tester.pump();

          // when dragging back to the first item,
          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: -crossAxisItemsDistance,
          );
          await gesture.up();
          await tester.pump();

          // then all items from the fifth to the second get UNSELECTED,
          // and the first item stills selected.
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.selectedIndexes, {0});
        },
        skip: false,
      );

      testWidgets(
        "When directly modifying the set of selected indexes "
        "of the grid-state, "
        "then and UnsupportedError is thrown, "
        "and the modifications are not materialized.",
        (tester) async {
          await setUp(tester);

          // When directly modifying the set of selected indexes
          // of the grid-state,
          // then and UnsupportedError is thrown,
          expect(
            () => dragSelectState.selectedIndexes.add(5),
            throwsUnsupportedError,
          );

          // and the modifications are not materialized.
          expect(dragSelectState.selectedIndexes, <int>{});
        },
        skip: false,
      );
    });

    group("Select by dragging backward.", () {
      testWidgets(
        "Given that the grid has 4 columns and 3 lines, "
        "and that the last item was long-pressed and selected, "
        ""
        "when dragging to the second to last item (at the left), "
        ""
        "then the second to last item gets selected, "
        "and the last item stills selected, "
        "and we get notified about selection changes.",
        (tester) async {
          var selectionChangeCount = 0;

          final gridController = DragSelectGridViewController()
            ..addListener(() => selectionChangeCount++);

          // Given that the grid has 4 columns and 3 lines,
          await setUp(tester, gridController: gridController);

          // and that the last item was long-pressed and selected,
          var gesture = await longPressDown(
            tester: tester,
            finder: lastItemFinder,
          );
          await tester.pump();

          // when dragging to the second to last item (at the left),
          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: -mainAxisItemsDistance,
          );
          await gesture.up();
          await tester.pump();

          // then the second to last item gets selected,
          // and the last item stills selected.
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.selectedIndexes, {10, 11});

          // and we get notified about selection changes.
          expect(selectionChangeCount, 2);
        },
        skip: false,
      );

      testWidgets(
        "Given that the grid has 4 columns and 3 lines, "
        "and that the last item was long-pressed and selected, "
        "and that the second to last item was selected by dragging, "
        ""
        "when dragging back to the last item, "
        ""
        "then the second to last item gets UNSELECTED, "
        "and the last item stills selected.",
        (tester) async {
          // Given that the grid has 4 columns and 3 lines,
          await setUp(tester);

          // and that the last item was long-pressed and selected,
          var gesture = await longPressDown(
            tester: tester,
            finder: lastItemFinder,
          );
          await tester.pump();

          // and that the second to last item was selected by dragging,
          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: -mainAxisItemsDistance,
          );
          await tester.pump();

          // when dragging back to the last item,
          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: mainAxisItemsDistance,
          );
          await gesture.up();
          await tester.pump();

          // then the second to last item gets UNSELECTED,
          // and the last item stills selected.
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.selectedIndexes, {11});
        },
        skip: false,
      );

      testWidgets(
        "Given that the grid has 4 columns and 3 lines, "
        "and that the last item was long-pressed and selected, "
        ""
        "when dragging to the third to last item, "
        "passing through the second to last item, "
        ""
        "then the second to last and the third to last item get selected, "
        "and the last item stills selected.",
        (tester) async {
          // Given that the grid has 4 columns and 3 lines,
          await setUp(tester);

          // and that the last item was long-pressed and selected,
          var gesture =
              await longPressDown(tester: tester, finder: lastItemFinder);
          await tester.pump();

          // when dragging to the third to last item,
          // passing through the second to last item,

          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: -mainAxisItemsDistance,
          );
          await tester.pump();

          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: -mainAxisItemsDistance,
          );
          await gesture.up();
          await tester.pump();

          // then the second to last and the third to last item get selected,
          // and the last item stills selected.
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.selectedIndexes, {9, 10, 11});
        },
        skip: false,
      );

      testWidgets(
        "Given that the grid has 4 columns and 3 lines, "
        "and that the last item was long-pressed and selected, "
        "and that the second to last and third to last item "
        "were selected by dragging, "
        ""
        "when dragging back to the last item, "
        "passing through the second to last item, "
        ""
        "then the third to last and the second to last item get UNSELECTED, "
        "and the last item stills selected.",
        (tester) async {
          // Given that the grid has 4 columns and 3 lines,
          await setUp(tester);

          // and that the last item was long-pressed and selected,
          var gesture = await longPressDown(
            tester: tester,
            finder: lastItemFinder,
          );
          await tester.pump();

          // and that the second to last and third to last item
          // were selected by dragging,

          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: -mainAxisItemsDistance * 2,
          );
          await tester.pump();

          // when dragging back to the last item,
          // passing through the second to last item,

          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: mainAxisItemsDistance,
          );
          await tester.pump();

          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: mainAxisItemsDistance,
          );
          await gesture.up();
          await tester.pump();

          // then the third to last and the second to last item get UNSELECTED,
          // and the last item stills selected.
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.selectedIndexes, {11});
        },
        skip: false,
      );

      testWidgets(
        "Given that the grid has 4 columns and 3 lines, "
        "and that the last item was long-pressed and selected, "
        ""
        "when dragging to the fifth to last item (at the top), "
        ""
        "then all items from the second to last to the fifth to last "
        "get selected, "
        "and the last item stills selected.",
        (tester) async {
          // Given that the grid has 4 columns and 3 lines,
          await setUp(tester);

          // and that the last item was long-pressed and selected,
          var gesture = await longPressDown(
            tester: tester,
            finder: lastItemFinder,
          );
          await tester.pump();

          // when dragging to the fifth to last item (at the top),
          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: -crossAxisItemsDistance,
          );
          await gesture.up();
          await tester.pump();

          // then all items from the second to last to the fifth to last
          // get selected,
          // and the last item stills selected.
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.selectedIndexes, {7, 8, 9, 10, 11});
        },
        skip: false,
      );

      testWidgets(
        "Given that the grid has 4 columns and 3 lines, "
        "and that the last item was long-pressed and selected, "
        "and that all items from the second to last to the fifth to last "
        "were selected by dragging, "
        ""
        "when dragging back to the last item, "
        ""
        "then all items from the fifth to last to the second to last "
        "get UNSELECTED, "
        "and the last item stills selected.",
        (tester) async {
          // Given that the grid has 4 columns and 3 lines,
          await setUp(tester);

          // and that the last item was long-pressed and selected,
          var gesture = await longPressDown(
            tester: tester,
            finder: lastItemFinder,
          );
          await tester.pump();

          // and that all items from the second to last to the fifth to last
          // were selected by dragging,
          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: -crossAxisItemsDistance,
          );
          await tester.pump();

          // when dragging back to the last item,
          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: crossAxisItemsDistance,
          );
          await gesture.up();
          await tester.pump();

          // then all items from the fifth to last to the second to last
          // get UNSELECTED,
          // and the last item stills selected.
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.selectedIndexes, {11});
        },
        skip: false,
      );
    });

    group('Selecting through grid-controller.', () {
      testWidgets(
        "When selecting the items 0 and 1 through the grid-controller, "
        "then the items 0 and 1 get selected in the grid-state.",
        (tester) async {
          final gridController = DragSelectGridViewController();
          await setUp(tester, gridController: gridController);

          // When selecting the items 0 and 1 through the grid-controller,
          gridController.value = Selection(const {0, 1});
          await tester.pump();

          // then the items 0 and 1 get selected in the grid-state.
          expect(dragSelectState.isDragging, isFalse);
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.selectedIndexes, {0, 1});
        },
        skip: false,
      );

      testWidgets(
        "Given that the grid has 4 columns and 3 lines, "
        "and that the first item was long-pressed and selected, "
        "and that the second item was selected by dragging, "
        ""
        "when selecting the items 2 and 3 through the grid-controller, "
        ""
        "then the drag gets interrupted, "
        "then the items 0 and 1 get UNSELECTED in the grid-state, "
        "and the items 2 and 3 get selected in the grid-state.",
        (tester) async {
          final gridController = DragSelectGridViewController();

          // Given that the grid has 4 columns and 3 lines,
          await setUp(tester, gridController: gridController);

          // and that the first item was long-pressed and selected,
          var gesture = await longPressDown(
            tester: tester,
            finder: firstItemFinder,
          );
          await tester.pump();

          // and that the second item was selected by dragging,
          gesture = await dragDown(
            tester: tester,
            previousGesture: gesture,
            offset: mainAxisItemsDistance,
          );
          await tester.pump();

          // when selecting the items 2 and 3 through the grid-controller,
          expect(dragSelectState.isDragging, isTrue);
          gridController.value = Selection(const {2, 3});
          await tester.pump();

          // then the drag gets interrupted,
          // then the items 0 and 1 get UNSELECTED in the grid-state,
          // and the items 2 and 3 get selected in the grid-state."
          expect(dragSelectState.isDragging, isFalse);
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.selectedIndexes, {2, 3});
        },
        skip: false,
      );

      testWidgets(
        "When creating a grid with pre-selected items, "
        "then the pre-selected items get selected in the grid-state, "
        "and LocalHistory entry is created.",
        (tester) async {
          // When creating a grid with pre-selected items,
          final gridController =
              DragSelectGridViewController(Selection(const {0, 1}));
          await setUp(tester, gridController: gridController);

          // then the pre-selected items get selected in the grid-state,
          expect(dragSelectState.isDragging, isFalse);
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.selectedIndexes, {0, 1});

          // and LocalHistory entry is created.
          final route = ModalRoute.of(tester.element(gridFinder));
          expect(route!.canPop, isTrue);
        },
        skip: false,
      );

      testWidgets(
        "Given a grid with a gridController, "
        "and selection is already active, "
        "when the user updates the selection controller, "
        "then the grid-state is updated accordingly.",
        (tester) async {
          // Given a grid with a gridController
          final gridController = DragSelectGridViewController(
            Selection(const {0}),
          );
          await setUp(tester, gridController: gridController);

          // and selection is already active
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.selectedIndexes, {0});

          // when the user updates the selection controller,
          gridController.value = Selection(const {1, 3});
          await tester.pumpAndSettle();

          // then the grid-state is updated accordingly.
          expect(dragSelectState.isSelecting, isTrue);
          expect(dragSelectState.selectedIndexes, {1, 3});
          expect(dragSelectState.selectedIndexes, isNot(contains(0)));
          expect(dragSelectState.selectedIndexes, contains(1));
          expect(dragSelectState.selectedIndexes, contains(3));
        },
      );
    });

    group("Local history.", () {
      testWidgets(
        "Given that the grid has an item selected, "
        "when trying to pop the route, "
        "then the item gets UNSELECTED.",
        (tester) async {
          await setUp(tester);

          // Given that the grid has an item selected,
          await tester.longPress(firstItemFinder, warnIfMissed: false);
          await tester.pump();

          // when trying to pop the route,
          // ignore: invalid_use_of_protected_member
          await tester.binding.handlePopRoute();

          // then the item gets UNSELECTED.
          expect(dragSelectState.isSelecting, isFalse);
          expect(dragSelectState.selectedIndexes, <int>{});
        },
        skip: false,
      );

      testWidgets(
        "Given that the grid has an item selected, "
        "when clearing the selection through the controller, "
        "then the widget removes the local history entry.",
        (tester) async {
          final controller = DragSelectGridViewController();
          await setUp(tester, gridController: controller);

          // Given that the grid has an item selected,
          await tester.longPress(firstItemFinder, warnIfMissed: false);
          await tester.pump();

          // when clearing the selection through the controller,
          controller.clear();

          // then the widget removes the local history entry.
          final route = ModalRoute.of(dragSelectState.context);
          expect(route!.willHandlePopInternally, isFalse);
        },
        skip: false,
      );
    });
  });

  group("Dragging to empty space in partial last row.", () {
    late DragSelectGridViewState partialRowState;
    late Offset partialRowMainAxisDist;
    late Offset partialRowCrossAxisDist;

    /// Creates a [DragSelectGridView] with 4 columns and 10 items,
    /// resulting in 2 full rows and 1 partial row with 2 items.
    Future<void> setUpPartialRow(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DragSelectGridView(
            itemCount: 10,
            itemBuilder: (_, index, __) => Container(
              key: ValueKey('grid-item-$index'),
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
            ),
          ),
        ),
      );

      partialRowState = tester.state(gridFinder);

      final firstItem = find.byKey(const ValueKey('grid-item-0'));
      final secondItem = find.byKey(const ValueKey('grid-item-1'));
      final fifthItem = find.byKey(const ValueKey('grid-item-4'));

      partialRowMainAxisDist =
          tester.getCenter(secondItem) - tester.getCenter(firstItem);
      partialRowCrossAxisDist =
          tester.getCenter(fifthItem) - tester.getCenter(firstItem);
    }

    testWidgets(
      "Given a grid with 10 items in 4 columns (partial last row), "
      "and the first item was long-pressed, "
      ""
      "when dragging to the empty space in the last row, "
      ""
      "then all items get selected.",
      (tester) async {
        await setUpPartialRow(tester);

        final firstItem = find.byKey(const ValueKey('grid-item-0'));
        final lastItem = find.byKey(const ValueKey('grid-item-9'));

        // Long-press the first item.
        var gesture = await longPressDown(
          tester: tester,
          finder: firstItem,
        );
        await tester.pump();

        // Drag to the empty space (one cell to the right of the last item).
        final emptySpacePos =
            tester.getCenter(lastItem) + partialRowMainAxisDist;
        final offset = emptySpacePos - tester.getCenter(firstItem);

        gesture = await dragDown(
          tester: tester,
          previousGesture: gesture,
          offset: offset,
        );
        await gesture.up();
        await tester.pump();

        expect(partialRowState.isSelecting, isTrue);
        expect(
          partialRowState.selectedIndexes,
          {0, 1, 2, 3, 4, 5, 6, 7, 8, 9},
        );
      },
      skip: false,
    );

    testWidgets(
      "Given a grid with 10 items in 4 columns (partial last row), "
      "and the first item in the last row was long-pressed, "
      ""
      "when dragging to the empty space in the last row, "
      ""
      "then the remaining item in the last row gets selected.",
      (tester) async {
        await setUpPartialRow(tester);

        final item8 = find.byKey(const ValueKey('grid-item-8'));

        // Long-press item 8 (first in the last row).
        var gesture = await longPressDown(
          tester: tester,
          finder: item8,
        );
        await tester.pump();

        // Drag to the empty space (two cells to the right of item 8,
        // which is past item 9).
        gesture = await dragDown(
          tester: tester,
          previousGesture: gesture,
          offset: partialRowMainAxisDist * 2,
        );
        await gesture.up();
        await tester.pump();

        expect(partialRowState.isSelecting, isTrue);
        expect(partialRowState.selectedIndexes, {8, 9});
      },
      skip: false,
    );

    testWidgets(
      "Given a grid with 10 items in 4 columns (partial last row), "
      "and the first item was long-pressed, "
      ""
      "when dragging below all items, "
      ""
      "then all items get selected.",
      (tester) async {
        await setUpPartialRow(tester);

        final firstItem = find.byKey(const ValueKey('grid-item-0'));

        // Long-press the first item.
        var gesture = await longPressDown(
          tester: tester,
          finder: firstItem,
        );
        await tester.pump();

        // Drag below all items (3 rows down + extra).
        gesture = await dragDown(
          tester: tester,
          previousGesture: gesture,
          offset: partialRowCrossAxisDist * 3,
        );
        await gesture.up();
        await tester.pump();

        expect(partialRowState.isSelecting, isTrue);
        expect(
          partialRowState.selectedIndexes,
          {0, 1, 2, 3, 4, 5, 6, 7, 8, 9},
        );
      },
      skip: false,
    );

    testWidgets(
      "Given a grid with 10 items in 4 columns (partial last row), "
      "and the last item was long-pressed, "
      ""
      "when dragging above all items, "
      ""
      "then all items get selected.",
      (tester) async {
        await setUpPartialRow(tester);

        final lastItem = find.byKey(const ValueKey('grid-item-9'));
        final firstItem = find.byKey(const ValueKey('grid-item-0'));

        // Long-press the last item.
        var gesture = await longPressDown(
          tester: tester,
          finder: lastItem,
        );
        await tester.pump();

        // Drag above all items (from last item to above the first item).
        final offset = tester.getCenter(firstItem) -
            tester.getCenter(lastItem) -
            partialRowCrossAxisDist;

        gesture = await dragDown(
          tester: tester,
          previousGesture: gesture,
          offset: offset,
        );
        await gesture.up();
        await tester.pump();

        expect(partialRowState.isSelecting, isTrue);
        expect(
          partialRowState.selectedIndexes,
          {0, 1, 2, 3, 4, 5, 6, 7, 8, 9},
        );
      },
      skip: false,
    );
  });

  group("Horizontal auto-scrolling integration tests.", () {
    testWidgets(
      "Given a horizontal scroll direction, "
      "when there's a long-press and drag to the left-hotspot, "
      "then backward auto-scroll is triggered.",
      (tester) async {
        await setUp(tester, scrollDirection: Axis.horizontal);

        expect(dragSelectState.autoScroll, AutoScroll.stopped());

        await longPressDownAndDrag(
          tester: tester,
          finder: gridFinder,
          offset: Offset(-(dragSelectState.context.size!.width / 2) + 1, 0),
        );
        await tester.pump();

        expect(
          dragSelectState.autoScroll.direction,
          AutoScrollDirection.backward,
        );
      },
      skip: false,
    );

    testWidgets(
      "Given a horizontal scroll direction and reversed, "
      "when there's a long-press and drag to the left-hotspot, "
      "then forward auto-scroll is triggered.",
      (tester) async {
        await setUp(
          tester,
          scrollDirection: Axis.horizontal,
          reverse: true,
        );

        await longPressDownAndDrag(
          tester: tester,
          finder: gridFinder,
          offset: Offset(-(dragSelectState.context.size!.width / 2) + 1, 0),
        );
        await tester.pump();

        expect(
          dragSelectState.autoScroll.direction,
          AutoScrollDirection.forward,
        );
      },
      skip: false,
    );

    testWidgets(
      "Given a horizontal scroll direction, "
      "when there's a long-press and drag to the right-hotspot, "
      "then forward auto-scroll is triggered.",
      (tester) async {
        await setUp(tester, scrollDirection: Axis.horizontal);

        await longPressDownAndDrag(
          tester: tester,
          finder: gridFinder,
          offset: Offset(dragSelectState.context.size!.width / 2, 0),
        );
        await tester.pump();

        expect(
          dragSelectState.autoScroll.direction,
          AutoScrollDirection.forward,
        );
      },
      skip: false,
    );

    testWidgets(
      "Given a horizontal scroll direction and reversed, "
      "when there's a long-press and drag to the right-hotspot, "
      "then backward auto-scroll is triggered.",
      (tester) async {
        await setUp(
          tester,
          scrollDirection: Axis.horizontal,
          reverse: true,
        );

        await longPressDownAndDrag(
          tester: tester,
          finder: gridFinder,
          offset: Offset(dragSelectState.context.size!.width / 2, 0),
        );
        await tester.pump();

        expect(
          dragSelectState.autoScroll.direction,
          AutoScrollDirection.backward,
        );
      },
      skip: false,
    );

    testWidgets(
      "Given a horizontal scroll direction, "
      "given that there were a long-press and drag to the left-hotspot, "
      "when the long-press is released, "
      "then the auto-scroll is disabled with `AutoScrollDirection.backward` "
      "and stop-event unconsumed.",
      (tester) async {
        await setUp(tester, scrollDirection: Axis.horizontal);

        final gesture = await longPressDownAndDrag(
          tester: tester,
          finder: gridFinder,
          offset: Offset(-(dragSelectState.context.size!.width / 2) + 1, 0),
        );
        await tester.pump();
        expect(
          dragSelectState.autoScroll.direction,
          AutoScrollDirection.backward,
        );

        await gesture.up();
        await tester.pump();

        expect(
          dragSelectState.autoScroll,
          AutoScroll.stopped(direction: AutoScrollDirection.backward),
        );
      },
      skip: false,
    );

    testWidgets(
      "Given a horizontal scroll direction, "
      "given that there were a long-press and drag to the right-hotspot, "
      "when dragged out of the right-hotspot, "
      "then the auto-scroll is disabled with `AutoScrollDirection.forward` "
      "and stop-event unconsumed.",
      (tester) async {
        await setUp(tester, scrollDirection: Axis.horizontal);

        final gesture = await longPressDownAndDrag(
          tester: tester,
          finder: gridFinder,
          offset: Offset(dragSelectState.context.size!.width / 2, 0),
        );
        await tester.pump();
        expect(
          dragSelectState.autoScroll.direction,
          AutoScrollDirection.forward,
        );

        await gesture.moveTo(tester.getCenter(gridFinder));
        await tester.pump();

        expect(
          dragSelectState.autoScroll,
          AutoScroll.stopped(direction: AutoScrollDirection.forward),
        );
      },
      skip: false,
    );
  });

  group("Auto-scrolling integration tests.", () {
    testWidgets(
      "When there's a long-press and drag to the upper-hotspot, "
      "then backward auto-scroll is triggered.",
      (tester) async {
        await setUp(tester);

        // Initially, autoScroll is stopped.
        expect(dragSelectState.autoScroll, AutoScroll.stopped());

        // When there's a long-press and drag to the upper-hotspot,
        await longPressDownAndDrag(
          tester: tester,
          finder: gridFinder,
          offset: Offset(0, -(dragSelectState.context.size!.height / 2) + 1),
        );
        await tester.pump();

        // then backward auto-scroll is triggered.
        expect(
          dragSelectState.autoScroll.direction,
          AutoScrollDirection.backward,
        );
      },
      skip: false,
    );

    testWidgets(
      "Given that the scroll is reversed, "
      "when there's a long-press and drag to the upper-hotspot, "
      "then forward auto-scroll is triggered.",
      (tester) async {
        // Given that the scroll is reversed,
        await setUp(tester, reverse: true);

        // when there's a long-press and drag to the upper-hotspot,
        await longPressDownAndDrag(
          tester: tester,
          finder: gridFinder,
          offset: Offset(0, -(dragSelectState.context.size!.height / 2) + 1),
        );
        await tester.pump();

        // then forward auto-scroll is triggered.
        expect(
          dragSelectState.autoScroll.direction,
          AutoScrollDirection.forward,
        );
      },
      skip: false,
    );

    testWidgets(
      "When there's a long-press and drag to the lower-hotspot, "
      "then forward auto-scroll is triggered.",
      (tester) async {
        await setUp(tester);

        // When there's a long-press and drag to the lower-hotspot,
        await longPressDownAndDrag(
          tester: tester,
          finder: gridFinder,
          offset: Offset(0, (dragSelectState.context.size!.height / 2)),
        );
        await tester.pump();

        // then forward auto-scroll is triggered.
        expect(
          dragSelectState.autoScroll.direction,
          AutoScrollDirection.forward,
        );
      },
      skip: false,
    );

    testWidgets(
      "Given that the scroll is reversed, "
      "when there's a long-press and drag to the lower-hotspot, "
      "then backward auto-scroll is triggered.",
      (tester) async {
        // Given that the scroll is reversed,
        await setUp(tester, reverse: true);

        // When there's a long-press and drag to the lower-hotspot,
        await longPressDownAndDrag(
          tester: tester,
          finder: gridFinder,
          offset: Offset(0, (dragSelectState.context.size!.height / 2)),
        );
        await tester.pump();

        // then backward auto-scroll is triggered.
        expect(
          dragSelectState.autoScroll.direction,
          AutoScrollDirection.backward,
        );
      },
      skip: false,
    );

    testWidgets(
      "Given that there were a long-press and drag to the upper-hotspot, "
      "when the long-press is released, "
      "then the auto-scroll is disabled with `AutoScrollDirection.backward` "
      "and stop-event unconsumed.",
      (tester) async {
        await setUp(tester);

        // Given that there were a long-press and drag to the upper-hotspot,
        final gesture = await longPressDownAndDrag(
          tester: tester,
          finder: gridFinder,
          offset: Offset(0, -(dragSelectState.context.size!.height / 2) + 1),
        );
        await tester.pump();
        expect(
          dragSelectState.autoScroll.direction,
          AutoScrollDirection.backward,
        );

        // when the long-press is released,
        await gesture.up();
        await tester.pump();

        // then the auto-scroll is disabled with `AutoScrollDirection.backward`
        // and stop-event unconsumed.
        expect(
          dragSelectState.autoScroll,
          AutoScroll.stopped(direction: AutoScrollDirection.backward),
        );
      },
      skip: false,
    );

    testWidgets(
      "Given that there were a long-press and drag to the lower-hotspot, "
      "when the long-press is released, "
      "then the auto-scroll is disabled with `AutoScrollDirection.forward` "
      "and stop-event unconsumed.",
      (tester) async {
        await setUp(tester);

        // Given that there were a long-press and drag to the lower-hotspot,
        final gesture = await longPressDownAndDrag(
          tester: tester,
          finder: gridFinder,
          offset: Offset(0, dragSelectState.context.size!.height / 2),
        );
        await tester.pump();
        expect(
          dragSelectState.autoScroll.direction,
          AutoScrollDirection.forward,
        );

        // when the long-press is released,
        await gesture.up();
        await tester.pump();

        // then the auto-scroll is disabled with `AutoScrollDirection.forward`
        // and stop-event unconsumed.
        expect(
          dragSelectState.autoScroll,
          AutoScroll.stopped(direction: AutoScrollDirection.forward),
        );
      },
      skip: false,
    );

    testWidgets(
      "Given that there were a long-press and drag to the lower-hotspot, "
      "when dragged out of the lower-hotspot, "
      "then the auto-scroll is disabled with `AutoScrollDirection.forward` "
      "and stop-event unconsumed.",
      (tester) async {
        await setUp(tester);

        // Given that there were a long-press and drag to the lower-hotspot,
        final gesture = await longPressDownAndDrag(
          tester: tester,
          finder: gridFinder,
          offset: Offset(0, dragSelectState.context.size!.height / 2),
        );
        await tester.pump();
        expect(
          dragSelectState.autoScroll.direction,
          AutoScrollDirection.forward,
        );

        // when dragged out of the lower-hotspot,
        await gesture.moveTo(tester.getCenter(gridFinder));
        await tester.pump();

        // then the auto-scroll is disabled with `AutoScrollDirection.forward`
        // and stop-event unconsumed.
        expect(
          dragSelectState.autoScroll,
          AutoScroll.stopped(direction: AutoScrollDirection.forward),
        );
      },
      skip: false,
    );
  });

  /// Moves [gesture] by [offset], split into two separate pointer moves
  /// instead of a single jump.
  ///
  /// A real drag reports movement incrementally; sending the whole [offset]
  /// as a single synthetic move only crosses the touch-slop threshold and
  /// starts the gesture, without also reporting an update for the rest of
  /// the movement.
  Future<void> dragInSteps(
    WidgetTester tester,
    TestGesture gesture,
    Offset offset,
  ) async {
    final firstStep = offset * 0.5;
    await gesture.moveBy(firstStep);
    await tester.pump();
    await gesture.moveBy(offset - firstStep);
    await tester.pump();
  }

  group("Horizontal-drag trigger.", () {
    test(
      "DragSelectGridView defaults dragSelectionTrigger to "
      "DragSelectionTrigger.longPress.",
      () {
        final widget = DragSelectGridView(
          itemCount: 1,
          itemBuilder: (_, __, ___) => Container(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
          ),
        );

        expect(widget.dragSelectionTrigger, DragSelectionTrigger.longPress);
      },
    );

    test(
      "Given that dragSelectionTrigger is DragSelectionTrigger.horizontalDrag, "
      "when scrollDirection is Axis.horizontal, "
      "then an assertion error is thrown, "
      "because both would compete for horizontal pointer movement.",
      () {
        expect(
          () => DragSelectGridView(
            dragSelectionTrigger: DragSelectionTrigger.horizontalDrag,
            scrollDirection: Axis.horizontal,
            itemCount: 1,
            itemBuilder: (_, __, ___) => Container(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
            ),
          ),
          throwsAssertionError,
        );
      },
    );

    group("DragSelectGridViewState.resolveDragSelectionTrigger.", () {
      test(
        "Given DragSelectionTrigger.horizontalDrag and Axis.horizontal, "
        "then it resolves to DragSelectionTrigger.longPress, "
        "as the release-mode (asserts stripped) safety net for the "
        "combination the constructor asserts against in debug builds.",
        () {
          expect(
            DragSelectGridViewState.resolveDragSelectionTrigger(
              trigger: DragSelectionTrigger.horizontalDrag,
              scrollDirection: Axis.horizontal,
            ),
            DragSelectionTrigger.longPress,
          );
        },
      );

      test(
        "Given DragSelectionTrigger.horizontalDrag and Axis.vertical, "
        "then it resolves to DragSelectionTrigger.horizontalDrag unchanged.",
        () {
          expect(
            DragSelectGridViewState.resolveDragSelectionTrigger(
              trigger: DragSelectionTrigger.horizontalDrag,
              scrollDirection: Axis.vertical,
            ),
            DragSelectionTrigger.horizontalDrag,
          );
        },
      );

      test(
        "Given DragSelectionTrigger.longPress, "
        "then it resolves to DragSelectionTrigger.longPress "
        "regardless of scrollDirection.",
        () {
          expect(
            DragSelectGridViewState.resolveDragSelectionTrigger(
              trigger: DragSelectionTrigger.longPress,
              scrollDirection: Axis.horizontal,
            ),
            DragSelectionTrigger.longPress,
          );
          expect(
            DragSelectGridViewState.resolveDragSelectionTrigger(
              trigger: DragSelectionTrigger.longPress,
              scrollDirection: Axis.vertical,
            ),
            DragSelectionTrigger.longPress,
          );
        },
      );
    });

    testWidgets(
      "Given a horizontal-drag trigger, "
      "when the first item is pressed and immediately dragged to the second, "
      "without waiting for a long-press hold, "
      ""
      "then the drag selection starts right away.",
      (tester) async {
        await setUp(
          tester,
          dragSelectionTrigger: DragSelectionTrigger.horizontalDrag,
        );

        expect(dragSelectState.isDragging, isFalse);

        final gesture = await tester.startGesture(
          tester.getCenter(firstItemFinder),
        );
        await dragInSteps(tester, gesture, mainAxisItemsDistance);

        expect(dragSelectState.isDragging, isTrue);
        expect(dragSelectState.selectedIndexes, {0, 1});

        await gesture.up();
        await tester.pump();
      },
    );

    testWidgets(
      "Given a horizontal-drag trigger, "
      "and that the pointer goes down near the right edge of the first item, "
      ""
      "when it's dragged just past the touch-slop threshold, "
      "which by itself lands over the second item, "
      ""
      "then the drag selection still anchors to the first item, "
      "i.e. the item under the original pointer-down position.",
      (tester) async {
        await setUp(
          tester,
          dragSelectionTrigger: DragSelectionTrigger.horizontalDrag,
        );

        final firstItemRect = tester.getRect(firstItemFinder);
        final downPosition = Offset(
          firstItemRect.right - 2,
          firstItemRect.center.dy,
        );

        final gesture = await tester.startGesture(downPosition);
        // 20 logical pixels clears `kTouchSlop` (18.0), and lands 18 pixels
        // inside the second item.
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump();

        expect(dragSelectState.isDragging, isTrue);
        expect(dragSelectState.selectedIndexes, {0});

        await gesture.up();
        await tester.pump();
      },
    );

    testWidgets(
      "Given a horizontal-drag trigger, "
      "and a grid tall enough to scroll, "
      ""
      "when the first item is pressed and dragged vertically, "
      ""
      "then no drag selection starts, "
      "and the grid scrolls instead.",
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DragSelectGridView(
              dragSelectionTrigger: DragSelectionTrigger.horizontalDrag,
              itemCount: 40,
              itemBuilder: (_, index, __) => Container(
                key: ValueKey('grid-item-$index'),
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
              ),
            ),
          ),
        );

        final state = tester.state(gridFinder) as DragSelectGridViewState;
        final item0 = find.byKey(const ValueKey('grid-item-0'));

        final gesture = await tester.startGesture(tester.getCenter(item0));
        await dragInSteps(tester, gesture, const Offset(0, -200));

        expect(state.isDragging, isFalse);
        expect(state.isSelecting, isFalse);
        expect(state.scrollController.offset, greaterThan(0));

        await gesture.up();
        await tester.pump();
      },
    );

    testWidgets(
      "Given a horizontal-drag trigger, "
      "and that dragging forward selected the first three items, "
      ""
      "when dragging back to the first item, "
      ""
      "then the extra items get UNSELECTED "
      "and the first item stills selected.",
      (tester) async {
        await setUp(
          tester,
          dragSelectionTrigger: DragSelectionTrigger.horizontalDrag,
        );

        final gesture = await tester.startGesture(
          tester.getCenter(firstItemFinder),
        );

        // Dragging forward selects the first three items.
        await dragInSteps(tester, gesture, mainAxisItemsDistance * 2);
        expect(dragSelectState.selectedIndexes, {0, 1, 2});

        // Dragging back to the first item unselects the extra ones.
        await dragInSteps(tester, gesture, -mainAxisItemsDistance * 2);
        expect(dragSelectState.selectedIndexes, {0});

        await gesture.up();
        await tester.pump();
      },
    );

    testWidgets(
      "Given a horizontal-drag trigger, "
      "and that the pointer is held stationary inside the auto-scroll "
      "hotspot, "
      ""
      "when the grid scrolls beneath it (as auto-scroll would), "
      ""
      "then the selection is replayed against the new layout "
      "and picks up the items now under the stationary pointer.",
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DragSelectGridView(
              dragSelectionTrigger: DragSelectionTrigger.horizontalDrag,
              itemCount: 40,
              itemBuilder: (_, index, __) => Container(
                key: ValueKey('grid-item-$index'),
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
              ),
            ),
          ),
        );

        final state = tester.state(gridFinder) as DragSelectGridViewState;

        final item0 = find.byKey(const ValueKey('grid-item-0'));
        final item1 = find.byKey(const ValueKey('grid-item-1'));
        final mainAxisDistance =
            tester.getCenter(item1) - tester.getCenter(item0);

        // Start the horizontal-drag selection, then move into and hold
        // inside the bottom auto-scroll hotspot.
        final gesture = await tester.startGesture(tester.getCenter(item0));
        await dragInSteps(tester, gesture, mainAxisDistance);

        final hotspotPosition = Offset(
          tester.getCenter(item0).dx,
          state.context.size!.height - 1,
        );
        await gesture.moveTo(hotspotPosition);
        await tester.pump();

        final selectedCountBeforeScroll = state.selectedIndexes.length;

        // Simulate the grid scrolling underneath the stationary pointer, as
        // auto-scroll would, and let the replay re-evaluate the selection
        // against the now-current layout.
        state.scrollController.jumpTo(state.scrollController.offset + 300);
        await tester.pump();
        state.handleScroll();

        expect(
          state.selectedIndexes.length,
          greaterThan(selectedCountBeforeScroll),
        );

        await gesture.up();
        await tester.pump();
      },
    );

    testWidgets(
      "Given a horizontal-drag trigger, "
      "and that a pointer is down but the drag hasn't started yet, "
      ""
      "when the widget rebuilds with dragSelectionTrigger switched "
      "to longPress, "
      ""
      "then the in-progress pointer sequence still completes "
      "as a horizontal-drag selection, "
      "because the trigger was frozen at pointer-down.",
      (tester) async {
        await tester.pumpWidget(
          createWidget(
            dragSelectionTrigger: DragSelectionTrigger.horizontalDrag,
          ),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(firstItemFinder),
        );
        await tester.pump();

        // The widget rebuilds mid-pointer-sequence, switching the
        // configured trigger before the horizontal-drag recognizer has
        // accepted the gesture.
        await tester.pumpWidget(
          createWidget(dragSelectionTrigger: DragSelectionTrigger.longPress),
        );

        final secondItemFinder = find.byKey(const ValueKey('grid-item-1'));
        final mainAxisDistance = tester.getCenter(secondItemFinder) -
            tester.getCenter(firstItemFinder);

        await dragInSteps(tester, gesture, mainAxisDistance);

        final state = tester.state(gridFinder) as DragSelectGridViewState;
        expect(state.isDragging, isTrue);
        expect(state.selectedIndexes, {0, 1});

        await gesture.up();
        await tester.pump();
      },
    );

    testWidgets(
      "Given a horizontal-drag trigger, "
      "and that a first pointer is down over the first item, "
      ""
      "when a second pointer touches down over a different item "
      "before the first pointer starts dragging, "
      ""
      "then no selection starts for that pointer sequence, "
      "even after the second pointer lifts "
      "and the first pointer alone continues to drag - "
      "the sequence was already contaminated "
      "by having two pointers down at once.",
      (tester) async {
        // A grid tall enough to scroll, so the grid's own vertical drag
        // recognizer is a genuine competitor in the gesture arena.
        await tester.pumpWidget(
          MaterialApp(
            home: DragSelectGridView(
              dragSelectionTrigger: DragSelectionTrigger.horizontalDrag,
              itemCount: 40,
              itemBuilder: (_, index, __) => Container(
                key: ValueKey('grid-item-$index'),
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
              ),
            ),
          ),
        );

        final state = tester.state(gridFinder) as DragSelectGridViewState;
        final item0 = find.byKey(const ValueKey('grid-item-0'));
        final item1 = find.byKey(const ValueKey('grid-item-1'));
        final item2 = find.byKey(const ValueKey('grid-item-2'));
        final mainAxisDistance =
            tester.getCenter(item1) - tester.getCenter(item0);

        final firstPointer = await tester.startGesture(
          tester.getCenter(item0),
        );
        final secondPointer = await tester.startGesture(
          tester.getCenter(item2),
        );
        await tester.pump();

        // The second pointer lifts before the first pointer starts
        // dragging, but the sequence is already contaminated: it had two
        // pointers down at once before any selection started.
        await secondPointer.up();
        await tester.pump();

        await dragInSteps(tester, firstPointer, mainAxisDistance);

        expect(state.isDragging, isFalse);
        expect(state.isSelecting, isFalse);

        await firstPointer.up();
        await tester.pump();
      },
    );

    testWidgets(
      "Given a horizontal-drag trigger, "
      "and that a pointer went down and up "
      "without moving enough to start a drag selection, "
      ""
      "when a brand new pointer sequence starts over a different item, "
      ""
      "then it anchors to that item, "
      "without any stale pointer-down state left over.",
      (tester) async {
        await setUp(
          tester,
          dragSelectionTrigger: DragSelectionTrigger.horizontalDrag,
        );

        // A stray touch-and-release over the first item, without enough
        // movement to start a drag selection.
        final strayPointer = await tester.startGesture(
          tester.getCenter(firstItemFinder),
        );
        await strayPointer.up();
        await tester.pump();

        expect(dragSelectState.isDragging, isFalse);

        // A brand new gesture, anchored to a different item, isn't affected
        // by the stray pointer's leftover state.
        final thirdItemFinder = find.byKey(const ValueKey('grid-item-2'));
        final gesture = await tester.startGesture(
          tester.getCenter(thirdItemFinder),
        );
        await dragInSteps(tester, gesture, mainAxisItemsDistance);

        expect(dragSelectState.selectedIndexes, {2, 3});

        await gesture.up();
        await tester.pump();
      },
    );

    testWidgets(
      "Given a horizontal-drag trigger, "
      "and that a first pointer went down over the first item "
      "and a second pointer went down over a different item, "
      ""
      "when the first pointer lifts before any drag starts "
      "and the second pointer then drags, "
      ""
      "then no selection starts either, "
      "because the sequence was already contaminated "
      "by having two pointers down at once, "
      "and normal single-pointer behavior only resumes "
      "once the whole sequence has fully ended.",
      (tester) async {
        // A grid tall enough to scroll, so the grid's own vertical drag
        // recognizer is a genuine competitor in the gesture arena.
        await tester.pumpWidget(
          MaterialApp(
            home: DragSelectGridView(
              dragSelectionTrigger: DragSelectionTrigger.horizontalDrag,
              itemCount: 40,
              itemBuilder: (_, index, __) => Container(
                key: ValueKey('grid-item-$index'),
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
              ),
            ),
          ),
        );

        final state = tester.state(gridFinder) as DragSelectGridViewState;
        final item0 = find.byKey(const ValueKey('grid-item-0'));
        final item2 = find.byKey(const ValueKey('grid-item-2'));
        final item3 = find.byKey(const ValueKey('grid-item-3'));
        final mainAxisDistance =
            tester.getCenter(item3) - tester.getCenter(item2);

        final firstPointer = await tester.startGesture(
          tester.getCenter(item0),
        );
        final secondPointer = await tester.startGesture(
          tester.getCenter(item2),
        );
        await tester.pump();

        // The first pointer (the original candidate) lifts before starting
        // a drag, but the sequence is already contaminated.
        await firstPointer.up();
        await tester.pump();

        await dragInSteps(tester, secondPointer, mainAxisDistance);

        expect(state.isDragging, isFalse);
        expect(state.isSelecting, isFalse);

        await secondPointer.up();
        await tester.pump();

        // Only once the whole pointer sequence has fully ended does a
        // fresh, single-pointer sequence behave normally again.
        final freshGesture = await tester.startGesture(
          tester.getCenter(item2),
        );
        await dragInSteps(tester, freshGesture, mainAxisDistance);

        expect(state.isDragging, isTrue);
        expect(state.selectedIndexes, {2, 3});

        await freshGesture.up();
        await tester.pump();
      },
    );

    testWidgets(
      "Given a horizontal-drag trigger, "
      "when two pointers are down simultaneously "
      "and the second pointer moves beyond the touch-slop threshold "
      "while the first pointer remains stationary, "
      ""
      "then no selection starts for that pointer sequence, "
      "and, once both pointers lift, "
      "a fresh single-pointer sequence still starts a selection normally.",
      (tester) async {
        // A grid tall enough to scroll, so the grid's own vertical drag
        // recognizer is a genuine competitor in the gesture arena.
        await tester.pumpWidget(
          MaterialApp(
            home: DragSelectGridView(
              dragSelectionTrigger: DragSelectionTrigger.horizontalDrag,
              itemCount: 40,
              itemBuilder: (_, index, __) => Container(
                key: ValueKey('grid-item-$index'),
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
              ),
            ),
          ),
        );

        final state = tester.state(gridFinder) as DragSelectGridViewState;
        final item0 = find.byKey(const ValueKey('grid-item-0'));
        final item1 = find.byKey(const ValueKey('grid-item-1'));
        final item2 = find.byKey(const ValueKey('grid-item-2'));
        final item3 = find.byKey(const ValueKey('grid-item-3'));
        final mainAxisDistance =
            tester.getCenter(item3) - tester.getCenter(item2);

        // Two pointers are down at the same time, before any drag starts.
        final firstPointer = await tester.startGesture(
          tester.getCenter(item0),
        );
        final secondPointer = await tester.startGesture(
          tester.getCenter(item2),
        );
        await tester.pump();

        // The second pointer moves beyond the touch-slop threshold, while
        // the first pointer never moves at all.
        await dragInSteps(tester, secondPointer, mainAxisDistance);

        // No selection starts for this pointer sequence - Flutter's
        // recognizer may have picked either pointer, so it isn't guessed.
        expect(state.isDragging, isFalse);
        expect(state.isSelecting, isFalse);

        await firstPointer.up();
        await secondPointer.up();
        await tester.pump();

        // Once the whole pointer sequence has fully ended, a fresh
        // single-pointer sequence still starts a selection normally.
        final freshGesture = await tester.startGesture(
          tester.getCenter(item0),
        );
        final freshDistance = tester.getCenter(item1) - tester.getCenter(item0);
        await dragInSteps(tester, freshGesture, freshDistance);

        expect(state.isDragging, isTrue);
        expect(state.selectedIndexes, {0, 1});

        await freshGesture.up();
        await tester.pump();
      },
    );

    testWidgets(
      "Given a horizontal-drag trigger, "
      "and that triggerSelectionOnTap is true, "
      ""
      "when an item is tapped without dragging, "
      ""
      "then the item gets selected, "
      "and, when tapped again, "
      "then the item gets UNSELECTED - "
      "taps still win arbitration against the horizontal-drag recognizer.",
      (tester) async {
        await setUp(
          tester,
          dragSelectionTrigger: DragSelectionTrigger.horizontalDrag,
          triggerSelectionOnTap: true,
        );

        expect(dragSelectState.isSelecting, isFalse);

        await tester.tap(firstItemFinder, warnIfMissed: false);
        await tester.pump();

        expect(dragSelectState.isSelecting, isTrue);
        expect(dragSelectState.selectedIndexes, {0});

        await tester.tap(firstItemFinder, warnIfMissed: false);
        await tester.pump();

        expect(dragSelectState.isSelecting, isFalse);
        expect(dragSelectState.selectedIndexes, <int>{});
      },
    );

    testWidgets(
      "Given a horizontal-drag trigger and that the scroll is reversed, "
      "when the first item is pressed and dragged to the second item, "
      ""
      "then the second item gets selected "
      "and the first item stills selected, "
      ""
      "and, when subsequently dragged into the upper hotspot, "
      "then forward auto-scroll is triggered, "
      "just like reverse flips auto-scroll direction for longPress.",
      (tester) async {
        await setUp(
          tester,
          reverse: true,
          dragSelectionTrigger: DragSelectionTrigger.horizontalDrag,
        );

        expect(dragSelectState.autoScroll, AutoScroll.stopped());

        final gesture = await tester.startGesture(
          tester.getCenter(firstItemFinder),
        );
        await dragInSteps(tester, gesture, mainAxisItemsDistance);

        expect(dragSelectState.isDragging, isTrue);
        expect(dragSelectState.selectedIndexes, {0, 1});

        // Dragging into the upper hotspot.
        await gesture.moveTo(
          Offset(tester.getCenter(firstItemFinder).dx, 1),
        );
        await tester.pump();

        expect(
          dragSelectState.autoScroll.direction,
          AutoScrollDirection.forward,
        );

        await gesture.up();
        await tester.pump();
      },
    );

    testWidgets(
      "Given a horizontal-drag trigger, "
      "and that a drag selection is active, "
      ""
      "when the pointer is cancelled instead of lifted, "
      ""
      "then the drag ends and the selection made so far is kept, "
      "and a fresh later gesture still works correctly, "
      "proving the pointer bookkeeping recovered.",
      (tester) async {
        await setUp(
          tester,
          dragSelectionTrigger: DragSelectionTrigger.horizontalDrag,
        );

        final gesture = await tester.startGesture(
          tester.getCenter(firstItemFinder),
        );
        await dragInSteps(tester, gesture, mainAxisItemsDistance);

        expect(dragSelectState.isDragging, isTrue);
        expect(dragSelectState.selectedIndexes, {0, 1});

        // The pointer is cancelled instead of lifted, e.g. as would happen
        // if the system showed a modal dialog on top of the app.
        await gesture.cancel();
        await tester.pump();

        expect(dragSelectState.isDragging, isFalse);
        expect(dragSelectState.selectedIndexes, {0, 1});

        // A fresh gesture afterward still anchors and drags correctly.
        final thirdItemFinder = find.byKey(const ValueKey('grid-item-2'));
        final freshGesture = await tester.startGesture(
          tester.getCenter(thirdItemFinder),
        );
        await dragInSteps(tester, freshGesture, mainAxisItemsDistance);

        expect(dragSelectState.isDragging, isTrue);
        expect(dragSelectState.selectedIndexes, {0, 1, 2, 3});

        await freshGesture.up();
        await tester.pump();
      },
    );

    testWidgets(
      "Given a long-press trigger (the default), "
      "and that a pointer is down but the long-press hasn't been "
      "recognized yet, "
      ""
      "when the widget rebuilds with dragSelectionTrigger switched "
      "to horizontalDrag, "
      ""
      "then the in-progress pointer sequence still completes "
      "as a long-press selection, "
      "because the trigger was frozen at pointer-down.",
      (tester) async {
        await tester.pumpWidget(createWidget());

        final gesture = await tester.startGesture(
          tester.getCenter(firstItemFinder),
        );
        await tester.pump();

        // The widget rebuilds mid-pointer-sequence, switching the
        // configured trigger before the long-press recognizer has
        // recognized the hold.
        await tester.pumpWidget(
          createWidget(
            dragSelectionTrigger: DragSelectionTrigger.horizontalDrag,
          ),
        );

        // Wait out the long-press hold, as the original (frozen) trigger
        // requires - a horizontal-drag recognizer would need movement
        // instead.
        await tester.pump(kLongPressTimeout + kPressTimeout);

        final state = tester.state(gridFinder) as DragSelectGridViewState;
        expect(state.isDragging, isTrue);
        expect(state.selectedIndexes, {0});

        await gesture.up();
        await tester.pump();
      },
    );

    testWidgets(
      "Given the default long-press trigger, "
      "and that pointer A went down and started long-pressing, "
      ""
      "when pointer B touches down before A's hold completes "
      "and never lifts, "
      "and A's hold then completes and A lifts (ending A's own drag) "
      "while B remains down, "
      "and the widget rebuilds with a different configured trigger, "
      ""
      "then no recognizer disposal assertion is thrown, "
      "because the trigger stays frozen until B's pointer sequence "
      "ends too - "
      "not just until A's own drag ends - "
      "and, once B lifts and the widget rebuilds back, "
      "a fresh pointer sequence still starts a selection normally.",
      (tester) async {
        // A long-press recognizer resolves `onLongPressEnd` off of its own
        // primary pointer alone, so pointer A's own end (not the whole
        // pointer sequence's end) is what drives `_endDragSelection()` here,
        // exercising the exact case the fix addresses: another pointer (B)
        // is still down in `_activePointerIds` at that moment.
        await setUp(tester);

        final pointerA = await tester.startGesture(
          tester.getCenter(firstItemFinder),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Pointer B touches down before A's long-press hold completes, and
        // never moves or lifts on its own.
        final thirdItemFinder = find.byKey(const ValueKey('grid-item-2'));
        final pointerB = await tester.startGesture(
          tester.getCenter(thirdItemFinder),
        );
        await tester.pump();

        // Waiting out the hold recognizes A's long-press.
        await tester.pump(kLongPressTimeout + kPressTimeout);

        expect(dragSelectState.isDragging, isTrue);
        expect(dragSelectState.selectedIndexes, {0});

        // A lifts, ending A's own drag, while B remains down.
        await pointerA.up();
        await tester.pump();

        // The widget rebuilds with a different configured trigger while B's
        // pointer sequence hasn't ended yet. This must not tear down a
        // recognizer that's still tracking B.
        await tester.pumpWidget(
          createWidget(
            dragSelectionTrigger: DragSelectionTrigger.horizontalDrag,
          ),
        );

        expect(tester.takeException(), isNull);

        // B finally lifts, fully ending the pointer sequence.
        await pointerB.up();
        await tester.pump();

        // Rebuilding back to the long-press trigger, a fresh pointer
        // sequence behaves normally again, now that the whole previous
        // sequence has fully ended.
        await tester.pumpWidget(createWidget());

        final freshItemFinder = find.byKey(const ValueKey('grid-item-3'));
        final freshGesture = await tester.startGesture(
          tester.getCenter(freshItemFinder),
        );
        await tester.pump(kLongPressTimeout + kPressTimeout);

        expect(dragSelectState.isDragging, isTrue);
        expect(dragSelectState.selectedIndexes, {0, 3});

        await freshGesture.up();
        await tester.pump();
      },
    );
  });
}

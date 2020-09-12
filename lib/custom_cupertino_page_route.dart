import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

const double _kBackGestureWidth = 20.0;
const double _kMinFlingVelocity = 1.0; // Screen widths per second.

// An eyeballed value for the maximum time it takes for a page to animate forward
// if the user releases a page mid swipe.
const int _kMaxDroppedSwipePageForwardAnimationTime = 800; // Milliseconds.

// The maximum time for a page to get reset to it's original position if the
// user releases a page mid swipe.
const int _kMaxPageBackAnimationTime = 300; // Milliseconds.

/// A modal route that replaces the entire screen with an iOS transition.
///
/// {@macro flutter.cupertino.cupertinoRouteTransitionMixin}
///
/// By default, when a modal route is replaced by another, the previous route
/// remains in memory. To free all the resources when this is not necessary, set
/// [maintainState] to false.
///
/// The type `T` specifies the return type of the route which can be supplied as
/// the route is popped from the stack via [Navigator.pop] when an optional
/// `result` can be provided.
///
/// See also:
///
///  * [CupertinoRouteTransitionMixin], for a mixin that provides iOS transition
///    for this modal route.
///  * [MaterialPageRoute], for an adaptive [PageRoute] that uses a
///    platform-appropriate transition.
///  * [CupertinoPageScaffold], for applications that have one page with a fixed
///    navigation bar on top.
///  * [CupertinoTabScaffold], for applications that have a tab bar at the
///    bottom with multiple pages.
///  * [CupertinoPage], for a [Page] version of this class.
class CustomCupertinoPageRoute<T> extends PageRoute<T> with CustomCupertinoRouteTransitionMixin<T> {
  /// Creates a page route for use in an iOS designed app.
  ///
  /// The [builder], [maintainState], and [fullscreenDialog] arguments must not
  /// be null.
  CustomCupertinoPageRoute({
    @required this.builder,
    this.title,
    RouteSettings settings,
    this.maintainState = true,
    bool fullscreenDialog = false,
    this.pageDidAppearCallback,
  })  : assert(builder != null),
        assert(maintainState != null),
        assert(fullscreenDialog != null),
        assert(opaque),
        super(settings: settings, fullscreenDialog: fullscreenDialog);

  @override
  final WidgetBuilder builder;

  @override
  final String title;

  @override
  final bool maintainState;

  @override
  String get debugLabel => '${super.debugLabel}(${settings.name})';

  final Function pageDidAppearCallback;
}

/// A mixin that replaces the entire screen with an iOS transition for a
/// [PageRoute].
///
/// {@template flutter.cupertino.cupertinoRouteTransitionMixin}
/// The page slides in from the right and exits in reverse. The page also shifts
/// to the left in parallax when another page enters to cover it.
///
/// The page slides in from the bottom and exits in reverse with no parallax
/// effect for fullscreen dialogs.
/// {@endtemplate}
///
/// See also:
///
///  * [MaterialRouteTransitionMixin], which is a mixin that provides
///    platform-appropriate transitions for a [PageRoute]
///  * [CupertinoPageRoute], which is a [PageRoute] that leverages this mixin.
mixin CustomCupertinoRouteTransitionMixin<T> on PageRoute<T> {
  /// Builds the primary contents of the route.
  WidgetBuilder get builder;

  /// {@template flutter.cupertino.cupertinoRouteTransitionMixin.title}
  /// A title string for this route.
  ///
  /// Used to auto-populate [CupertinoNavigationBar] and
  /// [CupertinoSliverNavigationBar]'s `middle`/`largeTitle` widgets when
  /// one is not manually supplied.
  /// {@endtemplate}
  String get title;

  ValueNotifier<String> _previousTitle;

  Function pageDidAppearCallback;

  /// The title string of the previous [CupertinoPageRoute].
  ///
  /// The [ValueListenable]'s value is readable after the route is installed
  /// onto a [Navigator]. The [ValueListenable] will also notify its listeners
  /// if the value changes (such as by replacing the previous route).
  ///
  /// The [ValueListenable] itself will be null before the route is installed.
  /// Its content value will be null if the previous route has no title or
  /// is not a [CupertinoPageRoute].
  ///
  /// See also:
  ///
  ///  * [ValueListenableBuilder], which can be used to listen and rebuild
  ///    widgets based on a ValueListenable.
  ValueListenable<String> get previousTitle {
    assert(
      _previousTitle != null,
      'Cannot read the previousTitle for a route that has not yet been installed',
    );
    return _previousTitle;
  }

  @override
  void didChangePrevious(Route<dynamic> previousRoute) {
    final String previousTitleString = previousRoute is CustomCupertinoRouteTransitionMixin ? previousRoute.title : null;
    if (_previousTitle == null) {
      _previousTitle = ValueNotifier<String>(previousTitleString);
    } else {
      _previousTitle.value = previousTitleString;
    }
    super.didChangePrevious(previousRoute);
  }

  @override
  // A relatively rigorous eyeball estimation.
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  Color get barrierColor => null;

  @override
  String get barrierLabel => null;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    // Don't perform outgoing animation if the next route is a fullscreen dialog.
    return nextRoute is CustomCupertinoRouteTransitionMixin && !nextRoute.fullscreenDialog;
  }

  /// True if an iOS-style back swipe pop gesture is currently underway for [route].
  ///
  /// This just check the route's [NavigatorState.userGestureInProgress].
  ///
  /// See also:
  ///
  ///  * [popGestureEnabled], which returns true if a user-triggered pop gesture
  ///    would be allowed.
  static bool isPopGestureInProgress(PageRoute<dynamic> route) {
    return route.navigator.userGestureInProgress;
  }

  /// True if an iOS-style back swipe pop gesture is currently underway for this route.
  ///
  /// See also:
  ///
  ///  * [isPopGestureInProgress], which returns true if a Cupertino pop gesture
  ///    is currently underway for specific route.
  ///  * [popGestureEnabled], which returns true if a user-triggered pop gesture
  ///    would be allowed.
  bool get popGestureInProgress => isPopGestureInProgress(this);

  /// Whether a pop gesture can be started by the user.
  ///
  /// Returns true if the user can edge-swipe to a previous route.
  ///
  /// Returns false once [isPopGestureInProgress] is true, but
  /// [isPopGestureInProgress] can only become true if [popGestureEnabled] was
  /// true first.
  ///
  /// This should only be used between frames, not during build.
  bool get popGestureEnabled => _isPopGestureEnabled(this);

  static bool _isPopGestureEnabled<T>(PageRoute<T> route) {
    // If there's nothing to go back to, then obviously we don't support
    // the back gesture.
    if (route.isFirst) return false;
    // If the route wouldn't actually pop if we popped it, then the gesture
    // would be really confusing (or would skip internal routes), so disallow it.
    if (route.willHandlePopInternally) return false;
    // If attempts to dismiss this route might be vetoed such as in a page
    // with forms, then do not allow the user to dismiss the route with a swipe.
    if (route.hasScopedWillPopCallback) return false;
    // Fullscreen dialogs aren't dismissible by back swipe.
    if (route.fullscreenDialog) return false;
    // If we're in an animation already, we cannot be manually swiped.
    if (route.animation.status != AnimationStatus.completed) return false;
    // If we're being popped into, we also cannot be swiped until the pop above
    // it completes. This translates to our secondary animation being
    // dismissed.
    if (route.secondaryAnimation.status != AnimationStatus.dismissed) return false;
    // If we're in a gesture already, we cannot start another.
    if (isPopGestureInProgress(route)) return false;

    // Looks like a back gesture would be welcome!
    return true;
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (this.pageDidAppearCallback != null) {
          this.pageDidAppearCallback();
        }
      }
    });

    final Widget child = builder(context);
    final Widget result = Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: child,
    );
    assert(() {
      if (child == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('The builder for route "${settings.name}" returned null.'),
          ErrorDescription('Route builders must never return null.'),
        ]);
      }
      return true;
    }());
    return result;
  }

  // Called by _CupertinoBackGestureDetector when a pop ("back") drag start
  // gesture is detected. The returned controller handles all of the subsequent
  // drag events.
  static _CupertinoBackGestureController<T> _startPopGesture<T>(PageRoute<T> route) {
    assert(_isPopGestureEnabled(route));

    return _CupertinoBackGestureController<T>(
      navigator: route.navigator,
      controller: route.controller, // protected access
    );
  }

  /// Returns a [CupertinoFullscreenDialogTransition] if [route] is a full
  /// screen dialog, otherwise a [CupertinoPageTransition] is returned.
  ///
  /// Used by [CupertinoPageRoute.buildTransitions].
  ///
  /// This method can be applied to any [PageRoute], not just
  /// [CupertinoPageRoute]. It's typically used to provide a Cupertino style
  /// horizontal transition for material widgets when the target platform
  /// is [TargetPlatform.iOS].
  ///
  /// See also:
  ///
  ///  * [CupertinoPageTransitionsBuilder], which uses this method to define a
  ///    [PageTransitionsBuilder] for the [PageTransitionsTheme].
  static Widget buildPageTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Check if the route has an animation that's currently participating
    // in a back swipe gesture.
    //
    // In the middle of a back gesture drag, let the transition be linear to
    // match finger motions.
    final bool linearTransition = isPopGestureInProgress(route);
    if (route.fullscreenDialog) {
      return CupertinoFullscreenDialogTransition(
        primaryRouteAnimation: animation,
        secondaryRouteAnimation: secondaryAnimation,
        child: child,
        linearTransition: linearTransition,
      );
    } else {
      return CupertinoPageTransition(
        primaryRouteAnimation: animation,
        secondaryRouteAnimation: secondaryAnimation,
        linearTransition: linearTransition,
        child: _CupertinoBackGestureDetector<T>(
          enabledCallback: () => _isPopGestureEnabled<T>(route),
          onStartPopGesture: () => _startPopGesture<T>(route),
          child: child,
        ),
      );
    }
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return buildPageTransitions<T>(this, context, animation, secondaryAnimation, child);
  }
}

/// A controller for an iOS-style back gesture.
///
/// This is created by a [CupertinoPageRoute] in response from a gesture caught
/// by a [_CupertinoBackGestureDetector] widget, which then also feeds it input
/// from the gesture. It controls the animation controller owned by the route,
/// based on the input provided by the gesture detector.
///
/// This class works entirely in logical coordinates (0.0 is new page dismissed,
/// 1.0 is new page on top).
///
/// The type `T` specifies the return type of the route with which this gesture
/// detector controller is associated.
class _CupertinoBackGestureController<T> {
  /// Creates a controller for an iOS-style back gesture.
  ///
  /// The [navigator] and [controller] arguments must not be null.
  _CupertinoBackGestureController({
    @required this.navigator,
    @required this.controller,
  })  : assert(navigator != null),
        assert(controller != null) {
    navigator.didStartUserGesture();
  }

  final AnimationController controller;
  final NavigatorState navigator;

  /// The drag gesture has changed by [fractionalDelta]. The total range of the
  /// drag should be 0.0 to 1.0.
  void dragUpdate(double delta) {
    controller.value -= delta;
  }

  /// The drag gesture has ended with a horizontal motion of
  /// [fractionalVelocity] as a fraction of screen width per second.
  void dragEnd(double velocity) {
    // Fling in the appropriate direction.
    // AnimationController.fling is guaranteed to
    // take at least one frame.
    //
    // This curve has been determined through rigorously eyeballing native iOS
    // animations.
    const Curve animationCurve = Curves.fastLinearToSlowEaseIn;
    bool animateForward;

    // If the user releases the page before mid screen with sufficient velocity,
    // or after mid screen, we should animate the page out. Otherwise, the page
    // should be animated back in.
    if (velocity.abs() >= _kMinFlingVelocity)
      animateForward = velocity <= 0;
    else
      animateForward = controller.value > 0.5;

    if (animateForward) {
      // The closer the panel is to dismissing, the shorter the animation is.
      // We want to cap the animation time, but we want to use a linear curve
      // to determine it.
      final int droppedPageForwardAnimationTime = min(
        lerpDouble(_kMaxDroppedSwipePageForwardAnimationTime, 0, controller.value).floor(),
        _kMaxPageBackAnimationTime,
      );
      controller.animateTo(1.0, duration: Duration(milliseconds: droppedPageForwardAnimationTime), curve: animationCurve);
    } else {
      // This route is destined to pop at this point. Reuse navigator's pop.
      navigator.pop();

      // The popping may have finished inline if already at the target destination.
      if (controller.isAnimating) {
        // Otherwise, use a custom popping animation duration and curve.
        final int droppedPageBackAnimationTime = lerpDouble(0, _kMaxDroppedSwipePageForwardAnimationTime, controller.value).floor();
        controller.animateBack(0.0, duration: Duration(milliseconds: droppedPageBackAnimationTime), curve: animationCurve);
      }
    }

    if (controller.isAnimating) {
      // Keep the userGestureInProgress in true state so we don't change the
      // curve of the page transition mid-flight since CupertinoPageTransition
      // depends on userGestureInProgress.
      AnimationStatusListener animationStatusCallback;
      animationStatusCallback = (AnimationStatus status) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(animationStatusCallback);
      };
      controller.addStatusListener(animationStatusCallback);
    } else {
      navigator.didStopUserGesture();
    }
  }
}

/// This is the widget side of [_CupertinoBackGestureController].
///
/// This widget provides a gesture recognizer which, when it determines the
/// route can be closed with a back gesture, creates the controller and
/// feeds it the input from the gesture recognizer.
///
/// The gesture data is converted from absolute coordinates to logical
/// coordinates by this widget.
///
/// The type `T` specifies the return type of the route with which this gesture
/// detector is associated.
class _CupertinoBackGestureDetector<T> extends StatefulWidget {
  const _CupertinoBackGestureDetector({
    Key key,
    @required this.enabledCallback,
    @required this.onStartPopGesture,
    @required this.child,
  })  : assert(enabledCallback != null),
        assert(onStartPopGesture != null),
        assert(child != null),
        super(key: key);

  final Widget child;

  final ValueGetter<bool> enabledCallback;

  final ValueGetter<_CupertinoBackGestureController<T>> onStartPopGesture;

  @override
  _CupertinoBackGestureDetectorState<T> createState() => _CupertinoBackGestureDetectorState<T>();
}

class _CupertinoBackGestureDetectorState<T> extends State<_CupertinoBackGestureDetector<T>> {
  _CupertinoBackGestureController<T> _backGestureController;

  HorizontalDragGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..onCancel = _handleDragCancel;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    assert(mounted);
    assert(_backGestureController == null);
    _backGestureController = widget.onStartPopGesture();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    assert(mounted);
    assert(_backGestureController != null);
    _backGestureController.dragUpdate(_convertToLogical(details.primaryDelta / context.size.width));
  }

  void _handleDragEnd(DragEndDetails details) {
    assert(mounted);
    assert(_backGestureController != null);
    _backGestureController.dragEnd(_convertToLogical(details.velocity.pixelsPerSecond.dx / context.size.width));
    _backGestureController = null;
  }

  void _handleDragCancel() {
    assert(mounted);
    // This can be called even if start is not called, paired with the "down" event
    // that we don't consider here.
    _backGestureController?.dragEnd(0.0);
    _backGestureController = null;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.enabledCallback()) _recognizer.addPointer(event);
  }

  double _convertToLogical(double value) {
    switch (Directionality.of(context)) {
      case TextDirection.rtl:
        return -value;
      case TextDirection.ltr:
        return value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasDirectionality(context));
    // For devices with notches, the drag area needs to be larger on the side
    // that has the notch.
    double dragAreaWidth = Directionality.of(context) == TextDirection.ltr ? MediaQuery.of(context).padding.left : MediaQuery.of(context).padding.right;
    dragAreaWidth = max(dragAreaWidth, _kBackGestureWidth);
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child,
        PositionedDirectional(
          start: 0.0,
          width: dragAreaWidth,
          top: 0.0,
          bottom: 0.0,
          child: Listener(
            onPointerDown: _handlePointerDown,
            behavior: HitTestBehavior.translucent,
          ),
        ),
      ],
    );
  }
}

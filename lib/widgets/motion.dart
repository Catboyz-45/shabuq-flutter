import 'package:flutter/material.dart';

/// Switches for the app's animations. Tests turn [loops] off because
/// repeating animations never let `pumpAndSettle` finish.
abstract final class Motion {
  static bool loops = true;

  /// True when the device asks for less motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Whether a looping animation (pulse, steam, ripple) should run.
  static bool canLoop(BuildContext context) => loops && !reduced(context);

  static const ease = Cubic(0.2, 0.8, 0.2, 1);
}

/// Fades and slides [child] up into place once, after [delay]. Used to let
/// lists and cards arrive one after another.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 480),
    this.offset = 16,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// How far below its place the child starts, in logical pixels.
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMicroseconds /
          (widget.delay + widget.duration).inMicroseconds,
      1,
      curve: Motion.ease,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isDismissed) {
      if (Motion.reduced(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      builder:
          (context, child) => Opacity(
            opacity: _progress.value,
            child: Transform.translate(
              offset: Offset(0, widget.offset * (1 - _progress.value)),
              child: child,
            ),
          ),
    );
  }
}

/// A small dot with a ring that keeps pulsing outwards: "this is live".
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.canLoop(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox.square(
      dimension: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                if (_controller.isAnimating)
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.55 * (1 - t)),
                    spreadRadius: size * 0.9 * t,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Repeats [builder] with a 0→1 value forever while looping is allowed;
/// otherwise builds once with [still].
class LoopingBuilder extends StatefulWidget {
  const LoopingBuilder({
    super.key,
    required this.duration,
    required this.builder,
    this.still = 0,
    this.child,
  });

  final Duration duration;
  final Widget Function(BuildContext context, double t, Widget? child) builder;

  /// Value used when the animation is not running.
  final double still;
  final Widget? child;

  @override
  State<LoopingBuilder> createState() => _LoopingBuilderState();
}

class _LoopingBuilderState extends State<LoopingBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.canLoop(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder:
          (context, child) => widget.builder(
            context,
            _controller.isAnimating ? _controller.value : widget.still,
            child,
          ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

enum GrandmaState { idle, listening, thinking, speaking }

/// Layered, live-animated grandma. All layers are 512x768 transparent PNGs that
/// stack 1:1 (no offsets).
///
/// ```dart
/// GrandmaAvatar(state: GrandmaState.speaking, height: 360);
/// // lip-sync to TTS / mic amplitude (0..1) instead of the built-in mouth loop:
/// GrandmaAvatar(state: GrandmaState.speaking, mouthLevel: amplitude);
/// ```
class GrandmaAvatar extends StatefulWidget {
  final GrandmaState state;
  final double height;

  /// Optional 0..1 audio level. When set (and state == speaking) it drives the
  /// mouth shape directly; otherwise a built-in talking loop is used.
  final double? mouthLevel;
  const GrandmaAvatar({
    super.key,
    this.state = GrandmaState.idle,
    this.height = 360,
    this.mouthLevel,
  });

  @override
  State<GrandmaAvatar> createState() => _GrandmaAvatarState();
}

class _GrandmaAvatarState extends State<GrandmaAvatar>
    with SingleTickerProviderStateMixin {
  static const _dir = 'assets/grandma';
  static const _frames = 48; // same 48-frame / 3.84 s loop as the GIFs
  static const _seq = [
    2,
    3,
    2,
    4,
    3,
    1,
    2,
    3,
    0,
    2,
    3,
    3,
    2,
    4,
    2,
    1,
    3,
    2,
    0,
    3,
    2,
    4,
    3,
    2,
  ];

  // pivots inside the 512x768 canvas, as Alignment (-1..1)
  static const _neck = Alignment(0, 265 / 768 * 2 - 1);
  static const _shoulder = Alignment(116 / 512 * 2 - 1, 332 / 768 * 2 - 1);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80 * _frames),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _l(String n) => Image.asset(
    '$_dir/$n.png',
    fit: BoxFit.contain,
    gaplessPlayback: true,
    filterQuality: FilterQuality.medium,
    excludeFromSemantics: true,
  );

  double _rad(double d) => d * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      return Image.asset(
        '$_dir/idle_still.png',
        height: widget.height,
        excludeFromSemantics: true,
      );
    }
    if (!_c.isAnimating) _c.repeat();
    final px = widget.height / 768; // canvas px -> logical px
    return SizedBox(
      height: widget.height,
      child: AspectRatio(
        aspectRatio: 512 / 768,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final k = _c.value * _frames;
            final ph = _c.value * 2 * math.pi;
            // Values below mirror the Python generator (which uses counter-clockwise-positive
            // degrees). Flutter rotates clockwise-positive, hence the sign flips.
            var tilt = 0.0,
                hdx = 0.0,
                hdy = 0.0,
                arm = -2 - 2 * math.sin(ph + 1);
            var eyes = 0, brows = 0, mouth = 0;
            final breath = -1.5 * (0.5 + 0.5 * math.sin(ph));
            switch (widget.state) {
              case GrandmaState.idle:
                tilt = 1.2 * math.sin(ph);
                eyes = (k >= 38 && k < 40) ? 1 : 0;
                mouth = (k >= 14 && k < 31) ? 1 : 0;
              case GrandmaState.listening:
                final nod = 3 * (0.5 - 0.5 * math.cos(2 * ph));
                tilt = -7 + 2 * math.sin(2 * ph);
                hdy = nod;
                hdx = 3;
                eyes = (k >= 30 && k < 32) ? 1 : 2;
                brows = 1;
                mouth = nod > 1.8 ? 1 : 0;
              case GrandmaState.thinking:
                tilt = 4 + 1.2 * math.sin(ph);
                eyes = (k >= 30 && k < 33) ? 1 : 0;
                brows = 1;
                mouth = 0;
              case GrandmaState.speaking:
                tilt = 2.2 * math.sin(2 * ph);
                hdy = -1.2 * (0.5 + 0.5 * math.sin(3 * ph));
                arm = -20 + 9 * math.sin(2 * ph - 0.5);
                eyes = (k >= 40 && k < 42) ? 1 : 0;
                brows = math.sin(2 * ph) > 0.6 ? 1 : 0;
                final lvl = widget.mouthLevel;
                mouth = lvl == null
                    ? _seq[(k ~/ 2) % _seq.length]
                    : (lvl < 0.08
                          ? 0
                          : lvl < 0.3
                          ? 2
                          : lvl < 0.65
                          ? 3
                          : 4);
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                _l('base'),
                Transform.translate(
                  offset: Offset(0, breath * px),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _l('arm_r'),
                      Transform.rotate(
                        angle: -_rad(arm),
                        alignment: _shoulder,
                        child: _l('arm_l'),
                      ),
                      _l('shawl'), // drapes over both arms
                    ],
                  ),
                ),
                Transform.translate(
                  offset: Offset(hdx * px, (hdy + breath) * px),
                  child: Transform.rotate(
                    angle: -_rad(tilt),
                    alignment: _neck,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _l('hair_back'),
                        _l('head'),
                        _l('eyes_$eyes'),
                        _l('mouth_$mouth'),
                        _l('hair_front'),
                        _l('glasses'),
                        _l('brows_$brows'),
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
}

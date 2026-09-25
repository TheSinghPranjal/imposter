import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/game_constants.dart';
import '../../../../core/utils/haptic_service.dart';
import '../../domain/entities/player_assignment.dart';

class SecretRevealCard extends StatefulWidget {
  const SecretRevealCard({
    super.key,
    required this.playerName,
    required this.assignment,
    required this.isRevealed,
    required this.onReveal,
    required this.haptics,
    this.animationsEnabled = true,
  });

  final String playerName;
  final PlayerAssignment assignment;
  final bool isRevealed;
  final VoidCallback onReveal;
  final HapticService haptics;
  final bool animationsEnabled;

  @override
  State<SecretRevealCard> createState() => _SecretRevealCardState();
}

class _SecretRevealCardState extends State<SecretRevealCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip;
  double _progress = 0;
  bool _holding = false;
  bool _midDone = false;
  DateTime? _started;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    if (widget.isRevealed) _flip.value = 1;
  }

  @override
  void didUpdateWidget(covariant SecretRevealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed && !oldWidget.isRevealed) {
      _flip.forward();
    } else if (!widget.isRevealed && oldWidget.isRevealed) {
      _flip.reverse();
      _progress = 0; _holding = false; _midDone = false;
    }
  }

  @override
  void dispose() { _flip.dispose(); super.dispose(); }

  Future<void> _startHold() async {
    if (widget.isRevealed) return;
    setState(() { _holding = true; _progress = 0; _midDone = false; _started = DateTime.now(); });
    await widget.haptics.light();
    _tick();
  }

  void _tick() {
    if (!_holding || !mounted || widget.isRevealed) return;
    final started = _started; if (started == null) return;
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    final p = (elapsed / GameConstants.holdToRevealMs).clamp(0.0, 1.0);
    setState(() => _progress = p);
    if (!_midDone && p >= 0.5) { _midDone = true; widget.haptics.selection(); }
    if (p >= 1) { _complete(); return; }
    Future<void>.delayed(const Duration(milliseconds: 16), _tick);
  }

  Future<void> _complete() async {
    _holding = false;
    await widget.haptics.medium();
    widget.onReveal();
    if (widget.animationsEnabled) { await _flip.forward(); } else { _flip.value = 1; }
  }

  void _endHold() {
    if (widget.isRevealed) return;
    setState(() { _holding = false; _progress = 0; _midDone = false; });
  }

  Future<void> _a11y() async {
    if (widget.isRevealed) return;
    await widget.haptics.medium();
    widget.onReveal();
    if (widget.animationsEnabled) { await _flip.forward(); } else { _flip.value = 1; }
  }

  @override
  Widget build(BuildContext context) {
    final a11y = MediaQuery.maybeOf(context)?.accessibleNavigation == true;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: widget.isRevealed
          ? 'Secret revealed for ${widget.playerName}'
          : 'Secret card for ${widget.playerName}. Press and hold to reveal.',
      button: true,
      child: Column(children: [
        AnimatedBuilder(
          animation: _flip,
          builder: (context, _) {
            final angle = _flip.value * math.pi;
            final showBack = angle >= math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..setEntry(3, 2, 0.0012)..rotateY(angle),
              child: showBack
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _Face(progress: 0, child: _Revealed(assignment: widget.assignment)),
                    )
                  : GestureDetector(
                      onLongPressStart: (_) => _startHold(),
                      onLongPressEnd: (_) => _endHold(),
                      onLongPressCancel: _endHold,
                      child: _Face(progress: _progress, child: const _Hidden()),
                    ),
            );
          },
        ),
        if (a11y && !widget.isRevealed) ...[
          const SizedBox(height: 12),
          TextButton(onPressed: _a11y, child: const Text('Tap to reveal (accessibility)')),
        ],
        if (widget.isRevealed) ...[
          const SizedBox(height: 18),
          Text('Keep this secret 🤫', style: AppTextStyles.title(onSurface)),
          const SizedBox(height: 4),
          Text(
            widget.assignment.isImposter ? 'Act natural.' : 'Remember your word.',
            style: AppTextStyles.body(onSurface.withValues(alpha: 0.7)),
          ),
        ],
      ]),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.child, required this.progress});
  final Widget child; final double progress;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 320,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          width: double.infinity, height: 320,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.indigo, AppColors.brightViolet],
            ),
            boxShadow: [BoxShadow(color: AppColors.brightViolet.withValues(alpha: 0.35), blurRadius: 28)],
          ),
          child: child,
        ),
        if (progress > 0)
          SizedBox(
            width: 88, height: 88,
            child: CircularProgressIndicator(
              value: progress, strokeWidth: 6,
              color: AppColors.warmYellow, backgroundColor: Colors.white24,
            ),
          ),
      ]),
    );
  }
}

class _Hidden extends StatelessWidget {
  const _Hidden();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.lock_rounded, size: 64, color: Colors.white),
      SizedBox(height: 16),
      Text('SECRET CARD', style: TextStyle(fontFamily: 'Nunito', fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2)),
      SizedBox(height: 12),
      Text('PRESS & HOLD TO\nREVEAL', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70, height: 1.3)),
    ]),
  );
}

class _Revealed extends StatelessWidget {
  const _Revealed({required this.assignment});
  final PlayerAssignment assignment;
  @override
  Widget build(BuildContext context) {
    final imposter = assignment.isImposter;
    return Container(
      width: double.infinity, height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: imposter
              ? const [Color(0xFF7A1020), AppColors.imposter]
              : const [Color(0xFF243B8A), AppColors.civilian],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(imposter ? '🚨 YOU ARE' : 'YOUR SECRET WORD', style: AppTextStyles.label(Colors.white70)),
        const SizedBox(height: 12),
        Text(imposter ? 'THE IMPOSTER' : (assignment.word ?? ''), textAlign: TextAlign.center, style: AppTextStyles.secret(Colors.white)),
        if (imposter && assignment.hint != null) ...[
          const SizedBox(height: 24),
          Text('HINT', style: AppTextStyles.label(AppColors.warmYellow)),
          const SizedBox(height: 6),
          Text(assignment.hint!, textAlign: TextAlign.center, style: AppTextStyles.headline(AppColors.warmYellow)),
        ],
      ]),
    );
  }
}

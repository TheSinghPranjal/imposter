import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/game_constants.dart';
import '../../../../core/utils/haptic_service.dart';
import '../../../../core/widgets/party_widgets.dart';
import '../../domain/enums/app_theme_mode.dart';
import '../../domain/enums/difficulty.dart';
import '../../domain/enums/game_phase.dart';
import '../providers/game_controller.dart';
import '../providers/game_session.dart';
import '../widgets/secret_reveal_card.dart';

class GameFlowScreen extends ConsumerStatefulWidget {
  const GameFlowScreen({super.key});

  @override
  ConsumerState<GameFlowScreen> createState() => _GameFlowScreenState();
}

class _GameFlowScreenState extends ConsumerState<GameFlowScreen>
    with WidgetsBindingObserver {
  final _nameController = TextEditingController();
  String? _nameError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      ref.read(gameControllerProvider.notifier).onAppObscured();
    }
  }

  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this round?'),
        content: const Text('Your secret cards are already assigned.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('KEEP PLAYING'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('EXIT ROUND'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      ref.read(gameControllerProvider.notifier).exitRound();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(gameControllerProvider);
    final ctrl = ref.read(gameControllerProvider.notifier);

    return PopScope(
      canPop: !session.phase.isRevealFlow,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && session.phase.isRevealFlow) {
          await _confirmExit();
        }
      },
      // Home and player setup draw their own full-bleed artwork, so they skip
      // the padded scaffold.
      child:
          session.phase == GamePhase.home ||
              session.phase == GamePhase.playerSetup
          ? _buildBody(session, ctrl)
          : PartyScaffold(child: _buildBody(session, ctrl)),
    );
  }

  Widget _buildBody(GameSession session, GameController ctrl) {
    switch (session.phase) {
      case GamePhase.splash:
        return const Center(child: CircularProgressIndicator());
      case GamePhase.home:
        return _HomeView(
          onStart: ctrl.startPlayerSetup,
          onSettings: ctrl.openSettings,
          onHowTo: ctrl.openHowToPlay,
        );
      case GamePhase.howToPlay:
        return _HowToPlayView(onBack: ctrl.goHome);
      case GamePhase.playerSetup:
        return _PlayerSetupView(
          session: session,
          nameController: _nameController,
          nameError: _nameError,
          onChanged: () => setState(() => _nameError = null),
          onAdd: () {
            final err = ctrl.addPlayer(_nameController.text);
            setState(() => _nameError = err);
            if (err == null) _nameController.clear();
          },
          onRemove: ctrl.removePlayer,
          onContinue: ctrl.goToConfiguration,
          onBack: ctrl.goHome,
        );
      case GamePhase.configuration:
        return _ConfigurationView(session: session, ctrl: ctrl);
      case GamePhase.passPhone:
      case GamePhase.readyToReveal:
      case GamePhase.revealing:
      case GamePhase.revealed:
        return _RevealView(session: session, ctrl: ctrl);
      case GamePhase.allRevealed:
        return _AllRevealedView(onContinue: ctrl.showRoundReady);
      case GamePhase.roundReady:
        return _RoundReadyView(
          session: session,
          onNext: ctrl.startNextRound,
          onHome: ctrl.goHome,
        );
      case GamePhase.settings:
        return _SettingsView(session: session, ctrl: ctrl);
      case GamePhase.error:
        return _ErrorView(
          message: session.errorMessage,
          onRetry: ctrl.bootstrap,
        );
    }
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView({
    required this.onStart,
    required this.onSettings,
    required this.onHowTo,
  });

  final VoidCallback onStart;
  final VoidCallback onSettings;
  final VoidCallback onHowTo;

  static const _background = 'assets/images/home_background.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Artwork already contains the logo, tagline and characters.
          Image.asset(
            _background,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, _, _) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF6EC6FF), Color(0xFFE8C48A)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CandyButton(
                    label: 'START GAME',
                    icon: Icons.play_arrow_rounded,
                    onPressed: onStart,
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: CandyButton(
                      label: 'HOW TO PLAY',
                      icon: Icons.menu_book_rounded,
                      style: CandyButtonStyle.secondary,
                      onPressed: onHowTo,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: CandyButton(
                      label: 'SETTINGS',
                      icon: Icons.settings_rounded,
                      style: CandyButtonStyle.secondary,
                      onPressed: onSettings,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowToPlayView extends StatelessWidget {
  const _HowToPlayView({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('ADD PLAYERS', "Enter everyone's name."),
      ('REVEAL', 'Pass the phone and secretly reveal your card.'),
      ('GIVE CLUES', 'Everyone describes the secret word.'),
      ('FIND THE IMPOSTER', 'Discuss and figure out who is bluffing.'),
      ('NEW ROUND', 'Start another round with one tap.'),
    ];
    final on = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Text('How to Play', style: AppTextStyles.title(on)),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: steps.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => GlowCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}. ${steps[i].$1}',
                    style: AppTextStyles.title(on),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[i].$2,
                    style: AppTextStyles.body(on.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ),
        ),
        PrimaryButton(label: 'GOT IT', onPressed: onBack),
      ],
    );
  }
}

class _PlayerSetupView extends StatelessWidget {
  const _PlayerSetupView({
    required this.session,
    required this.nameController,
    required this.nameError,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
    required this.onContinue,
    required this.onBack,
  });

  final GameSession session;
  final TextEditingController nameController;
  final String? nameError;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final void Function(String id) onRemove;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  static const _background = 'assets/images/players_background.png';
  static const _imageSize = Size(857, 1835);

  /// Bottom edge of the hanging "WHO'S PLAYING?" sign, in image pixels.
  static const _signBottom = 385.0;

  static const _avatarColors = [
    AppColors.brightViolet,
    AppColors.coral,
    Color(0xFF26A69A),
    Color(0xFFFFA726),
    AppColors.electricBlue,
    Color(0xFF66BB6A),
  ];

  @override
  Widget build(BuildContext context) {
    final players = session.players;
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    const ink = AppColors.deepPurple;

    // The sign is baked into the artwork, so push content below wherever
    // BoxFit.cover (top-aligned) ends up drawing it.
    final scale = math.max(
      media.size.width / _imageSize.width,
      media.size.height / _imageSize.height,
    );
    final contentTop = math.max(
      _signBottom * scale + 8 - media.padding.top,
      56.0,
    );

    return Scaffold(
      // Keep the artwork fixed when the keyboard opens; content pads itself.
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _background,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, _, _) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF6EC6FF), Color(0xFF8BD66B)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + keyboard),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: keyboard > 0 ? 56 : contentTop,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _RoundIconButton(
                          icon: Icons.arrow_back_rounded,
                          onPressed: onBack,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: _Pill(
                      child: Text(
                        GameConstants.bestWithLabel,
                        style: AppTextStyles.label(ink),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _NameInput(
                    controller: nameController,
                    error: nameError,
                    onChanged: onChanged,
                    onAdd: onAdd,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: players.isEmpty
                        ? Align(
                            alignment: const Alignment(0, -0.3),
                            child: _Pill(
                              child: Text(
                                'Add at least ${GameConstants.minPlayers} '
                                'players to start.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.body(ink),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 8),
                            itemCount: players.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final p = players[i];
                              return _PlayerTile(
                                initials: p.initials,
                                position: p.position,
                                name: p.name,
                                color: _avatarColors[i % _avatarColors.length],
                                onRemove: () => onRemove(p.id),
                              );
                            },
                          ),
                  ),
                  if (keyboard == 0) ...[
                    Center(
                      child: _Pill(
                        child: Text(
                          '${players.length} / ${GameConstants.maxPlayers} '
                          'players',
                          style: AppTextStyles.label(ink),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CandyButton(
                      label: 'CONTINUE',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: players.length >= GameConstants.minPlayers
                          ? onContinue
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted white pill used for small labels over the artwork.
class _Pill extends StatelessWidget {
  const _Pill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.deepPurple),
      ),
    );
  }
}

class _NameInput extends StatelessWidget {
  const _NameInput({
    required this.controller,
    required this.error,
    required this.onChanged,
    required this.onAdd,
  });

  final TextEditingController controller;
  final String? error;
  final VoidCallback onChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    const ink = AppColors.deepPurple;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 6, 6, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(
              color: error != null ? AppColors.imposter : Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brightViolet.withValues(alpha: 0.2),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: (_) => onChanged(),
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => onAdd(),
                  maxLength: GameConstants.maxNameLength,
                  style: AppTextStyles.title(ink),
                  cursorColor: AppColors.brightViolet,
                  decoration: InputDecoration(
                    hintText: 'Player name',
                    hintStyle: AppTextStyles.title(ink.withValues(alpha: 0.35)),
                    counterText: '',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              Material(
                color: AppColors.brightViolet,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onAdd,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: _Pill(
                child: Text(
                  error!,
                  style: AppTextStyles.label(AppColors.imposter),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.initials,
    required this.position,
    required this.name,
    required this.color,
    required this.onRemove,
  });

  final String initials;
  final int position;
  final String name;
  final Color color;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    const ink = AppColors.deepPurple;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color,
            child: Text(initials, style: AppTextStyles.label(Colors.white)),
          ),
          const SizedBox(width: 12),
          Text(
            position.toString().padLeft(2, '0'),
            style: AppTextStyles.label(ink.withValues(alpha: 0.45)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: AppTextStyles.title(ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.close_rounded, color: ink.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

class _ConfigurationView extends StatelessWidget {
  const _ConfigurationView({required this.session, required this.ctrl});

  final GameSession session;
  final GameController ctrl;

  @override
  Widget build(BuildContext context) {
    final on = Theme.of(context).colorScheme.onSurface;
    final maxImp = GameConstants.maxImpostersFor(session.players.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: ctrl.editPlayers,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Text('READY TO PLAY?', style: AppTextStyles.title(on)),
            ),
          ],
        ),
        Text(
          'Set the rules for this round.',
          style: AppTextStyles.body(on.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 16),
        Text(
          'Difficulty',
          style: AppTextStyles.label(on.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: Difficulty.values.map((d) {
            final selected = session.settings.difficulty == d;
            return ChoiceChip(
              label: Text('${d.emoji} ${d.label}'),
              selected: selected,
              onSelected: (_) => ctrl.setDifficulty(d),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        GlowCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Imposters', style: AppTextStyles.title(on)),
                    Text(
                      'Maximum for ${session.players.length} players: $maxImp',
                      style: AppTextStyles.label(on.withValues(alpha: 0.55)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () =>
                    ctrl.setImposterCount(session.settings.imposterCount - 1),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '${session.settings.imposterCount}',
                style: AppTextStyles.headline(on),
              ),
              IconButton(
                onPressed: () =>
                    ctrl.setImposterCount(session.settings.imposterCount + 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlowCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Show hint to imposter',
              style: AppTextStyles.title(on),
            ),
            subtitle: Text(
              'A tiny clue — never the word itself.',
              style: AppTextStyles.body(on.withValues(alpha: 0.65)),
            ),
            value: session.settings.showHint,
            onChanged: ctrl.setShowHint,
          ),
        ),
        const Spacer(),
        SecondaryButton(label: 'EDIT PLAYERS', onPressed: ctrl.editPlayers),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'CONTINUE',
          icon: Icons.casino_rounded,
          onPressed: ctrl.startRound,
        ),
      ],
    );
  }
}

class _RevealView extends StatelessWidget {
  const _RevealView({required this.session, required this.ctrl});

  final GameSession session;
  final GameController ctrl;

  @override
  Widget build(BuildContext context) {
    final on = Theme.of(context).colorScheme.onSurface;
    final player = session.currentPlayer;
    if (player == null) return const SizedBox.shrink();
    final haptics = HapticService(enabled: session.settings.hapticEnabled);

    if (session.privacyLocked || session.phase == GamePhase.passPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(
            session.privacyLocked
                ? 'Screen hidden for privacy.'
                : 'PASS THE PHONE',
            textAlign: TextAlign.center,
            style: AppTextStyles.label(on.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 12),
          Text(
            session.privacyLocked
                ? "Let's continue safely."
                : 'Give the phone to',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(on.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 8),
          Text(
            player.name.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppTextStyles.display(on),
          ),
          const SizedBox(height: 12),
          Text(
            'Only ${player.name} should look 👀',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(on.withValues(alpha: 0.7)),
          ),
          const Spacer(),
          PrimaryButton(
            label: "I'M READY",
            onPressed: session.privacyLocked
                ? ctrl.unlockPrivacy
                : ctrl.confirmReadyToReveal,
          ),
        ],
      );
    }

    final assignment = session.currentAssignment;
    if (assignment == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your turn, ${player.name} 👀',
          textAlign: TextAlign.center,
          style: AppTextStyles.title(on),
        ),
        const SizedBox(height: 8),
        Text(
          session.isCardRevealed ? 'Your secret is ready 🤫' : 'Hold to reveal',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(on.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 20),
        SecretRevealCard(
          playerName: player.name,
          assignment: assignment,
          isRevealed: session.isCardRevealed,
          onReveal: ctrl.revealCurrentPlayer,
          haptics: haptics,
          animationsEnabled: session.settings.animationsEnabled,
        ),
        const Spacer(),
        if (session.isCardRevealed)
          PrimaryButton(
            label: session.isLastPlayer ? 'START GAME' : 'PASS TO NEXT PLAYER',
            onPressed: () {
              if (session.isLastPlayer) {
                ctrl.finishRevealPhase();
              } else {
                ctrl.passToNextPlayer();
              }
            },
          ),
      ],
    );
  }
}

class _AllRevealedView extends StatelessWidget {
  const _AllRevealedView({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final on = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        const Spacer(),
        Text(
          'Everyone has seen their role.',
          textAlign: TextAlign.center,
          style: AppTextStyles.headline(on),
        ),
        const SizedBox(height: 12),
        Text(
          'Time to find the imposter.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(on.withValues(alpha: 0.7)),
        ),
        const Spacer(),
        PrimaryButton(label: 'START GAME', onPressed: onContinue),
      ],
    );
  }
}

class _RoundReadyView extends StatelessWidget {
  const _RoundReadyView({
    required this.session,
    required this.onNext,
    required this.onHome,
  });

  final GameSession session;
  final VoidCallback onNext;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final on = Theme.of(context).colorScheme.onSurface;
    final starter = session.startingPlayer;
    return Column(
      children: [
        const Spacer(),
        const Text('🎉', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 8),
        Text(
          "EVERYONE'S READY",
          style: AppTextStyles.label(on.withValues(alpha: 0.6)),
        ),
        Text(
          'THE ROUND BEGINS NOW',
          textAlign: TextAlign.center,
          style: AppTextStyles.headline(on),
        ),
        const SizedBox(height: 12),
        Text(
          'Give clues. Listen carefully.\nFind the imposter.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(on.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 28),
        GlowCard(
          child: Column(
            children: [
              Text(
                'STARTING PLAYER',
                style: AppTextStyles.label(AppColors.warmYellow),
              ),
              const SizedBox(height: 8),
              Text(
                '🗣️  ${starter?.name ?? "?"} starts!',
                textAlign: TextAlign.center,
                style: AppTextStyles.headline(on),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Put the phone down and start talking!',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(on.withValues(alpha: 0.65)),
        ),
        const Spacer(),
        PrimaryButton(label: 'AGAIN! 🔥', onPressed: onNext),
        const SizedBox(height: 12),
        SecondaryButton(label: 'HOME', onPressed: onHome),
      ],
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView({required this.session, required this.ctrl});

  final GameSession session;
  final GameController ctrl;

  @override
  Widget build(BuildContext context) {
    final on = Theme.of(context).colorScheme.onSurface;
    final s = session.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: ctrl.goHome,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Text('Settings', style: AppTextStyles.title(on)),
          ],
        ),
        Expanded(
          child: ListView(
            children: [
              Text(
                'APPEARANCE',
                style: AppTextStyles.label(on.withValues(alpha: 0.55)),
              ),
              const SizedBox(height: 8),
              GlowCard(
                child: Wrap(
                  spacing: 8,
                  children: AppThemeMode.values.map((m) {
                    return ChoiceChip(
                      label: Text(m.label),
                      selected: s.themeMode == m,
                      onSelected: (_) => ctrl.setThemeMode(m),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'GAMEPLAY',
                style: AppTextStyles.label(on.withValues(alpha: 0.55)),
              ),
              const SizedBox(height: 8),
              GlowCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Haptic feedback'),
                      value: s.hapticEnabled,
                      onChanged: ctrl.setHapticEnabled,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Animations'),
                      value: s.animationsEnabled,
                      onChanged: ctrl.setAnimationsEnabled,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sound effects'),
                      value: s.soundEnabled,
                      onChanged: ctrl.setSoundEnabled,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SecondaryButton(
                label: 'RESET SETTINGS',
                onPressed: ctrl.resetSettings,
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'HOW TO PLAY',
                onPressed: ctrl.openHowToPlay,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        const Icon(Icons.error_outline, size: 64, color: AppColors.imposter),
        const SizedBox(height: 12),
        Text(
          message ?? 'Something went wrong loading the word pack.',
          textAlign: TextAlign.center,
          style: AppTextStyles.title(Theme.of(context).colorScheme.onSurface),
        ),
        const Spacer(),
        PrimaryButton(label: 'TRY AGAIN', onPressed: onRetry),
      ],
    );
  }
}

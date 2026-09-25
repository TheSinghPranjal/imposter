enum GamePhase {
  splash,
  home,
  howToPlay,
  playerSetup,
  configuration,
  passPhone,
  readyToReveal,
  revealing,
  revealed,
  allRevealed,
  roundReady,
  settings,
  error,
}

extension GamePhaseX on GamePhase {
  bool get isRevealFlow =>
      this == GamePhase.passPhone ||
      this == GamePhase.readyToReveal ||
      this == GamePhase.revealing ||
      this == GamePhase.revealed;

  bool get showsSecret =>
      this == GamePhase.revealing || this == GamePhase.revealed;
}

/// Statistiques d'un joueur, calculées à la volée à partir des défis révélés.
///
/// Rien n'est stocké : tout se recalcule depuis les empreintes. Ça évite une
/// table de plus à maintenir cohérente, et surtout ça reste juste le jour où
/// on retouchera les poids du score — les classements passés suivront.
class PlayerStats {
  final String playerId;
  final String pseudo;

  /// Défis lancés (pets enregistrés).
  final int challengesCreated;

  /// Tentatives d'imitation envoyées.
  final int attempts;

  /// Défis remportés (meilleure imitation).
  final int wins;

  /// Podiums (top 3), pour ne pas récompenser que le premier.
  final int podiums;

  final double bestScore;
  final double avgScore;

  const PlayerStats({
    required this.playerId,
    required this.pseudo,
    this.challengesCreated = 0,
    this.attempts = 0,
    this.wins = 0,
    this.podiums = 0,
    this.bestScore = 0,
    this.avgScore = 0,
  });

  /// Taux de victoire sur les défis auxquels le joueur a participé.
  double get winRate => attempts == 0 ? 0 : wins / attempts * 100;

  PlayerStats copyWith({
    String? pseudo,
    int? challengesCreated,
    int? attempts,
    int? wins,
    int? podiums,
    double? bestScore,
    double? avgScore,
  }) =>
      PlayerStats(
        playerId: playerId,
        pseudo: pseudo ?? this.pseudo,
        challengesCreated: challengesCreated ?? this.challengesCreated,
        attempts: attempts ?? this.attempts,
        wins: wins ?? this.wins,
        podiums: podiums ?? this.podiums,
        bestScore: bestScore ?? this.bestScore,
        avgScore: avgScore ?? this.avgScore,
      );
}

import 'package:flutter/material.dart';

import 'challenges_screen.dart';
import 'profile_screen.dart';
import 'standings_screen.dart';

/// Navigation à trois onglets.
///
/// Volontairement trois, pas cinq comme les apps de référence : une boîte de
/// réception sans notifications et un onglet « monde » sans contenu seraient
/// des écrans en trompe-l'œil. On ajoutera quand il y aura quelque chose
/// dedans.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Conservés en mémoire pour que revenir sur un onglet ne relance pas tout.
  late final List<Widget> _pages = const [
    ChallengesScreen(),
    StandingsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.air_outlined),
            selectedIcon: Icon(Icons.air_rounded),
            label: 'Défis',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events_rounded),
            label: 'Classement',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

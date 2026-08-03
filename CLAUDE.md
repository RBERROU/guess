# Guess My Fart

Le matin, tu enregistres ton pet et tu donnes quelques indices. Tes potes
soumettent **à l'aveugle** une imitation à la bouche — ils ne l'ont jamais
entendu. Quand tout le monde a soumis, on révèle le vrai pet et le classement.
Le plus proche gagne.

> Le socle technique commun est dans `apps/CLAUDE.md`. Ici, le spécifique.

---

## Ce qui fait ce produit

**Le score de proximité *est* le produit.** Sans lui, c'est Just Fart avec des
potes. Toute décision se juge à l'aune de : est-ce que le classement paraît
mérité ?

Trois conséquences qui expliquent presque toutes les décisions du code :

**Le score n'a pas besoin d'être juste, seulement cohérent.** Toutes les
soumissions sont comparées à la même cible, donc les biais s'annulent. Seul
l'ordre compte. « Laquelle de ces cinq est la plus proche ? » est bien plus
facile que « à quel point est-ce ressemblant ? ».

**Les indices sont aussi les axes du score.** Durée, texture, rythme, hauteur :
on note les gens sur ce qu'on leur a dit. C'est ce qui rend le classement
défendable, et le détail par axe permet de dire « bonne durée mais trop aigu »
plutôt que d'asséner un nombre.

**La mesure pèse sur ce qu'un humain imite réellement** — durée, rythme,
hauteur — et **très peu sur le timbre**, qu'aucune bouche ne reproduit. Un
score qui pèserait sur le timbre punirait tout le monde à égalité et ne
classerait plus rien.

---

## Le cœur : `lib/scoring/`

| fichier | rôle |
|---|---|
| `fft.dart` | FFT radix-2 maison, sans dépendance |
| `wav.dart` | lecture WAV PCM 16 bits, parcours des chunks (pas d'en-tête supposé à 44 octets) |
| `fingerprint.dart` | extraction de l'empreinte : durée utile, enveloppe en 16 points, bouffées/seconde, centroïde, hauteur, souffle |
| `matcher.dart` | distance à quatre axes, poids réglables, classement |

**Tout tourne sur l'appareil, en Dart pur.** Pas de service à héberger, ça
reste gratuit, et surtout personne ne peut connaître son score avant la
révélation — donc personne ne peut réessayer jusqu'à ce que ça monte.

L'enregistrement se fait en **WAV 22 050 Hz mono** — et non en AAC comme Just
Fart. C'est ce qui donne accès aux échantillons bruts, et ça garde l'audio
source pour recalculer d'autres caractéristiques plus tard.

**Les poids ne sont pas calibrés.** Aucun classement machine n'a été comparé à
un classement humain. Ils vivent donc dans la table `score_weights` pour être
corrigés **sans republier l'app**, et les empreintes brutes sont conservées
pour recalculer les défis passés.

### Ce qui a été vérifié

Banc d'essai sur de vrais fichiers (`dart run tool/bench.dart cible.wav a.wav
b.wav`) : un son contre lui-même donne 100 partout, et sur des extraits
musicaux le classement obtenu correspond exactement à celui qu'une méthode
indépendante (`music/similar.py`) avait mesuré. Quatre tests unitaires
couvrent le décodage, l'identité, l'ordre et la pénalité de durée.

**Ce que ça ne prouve pas** : rien n'a encore été testé sur de vrais pets
contre de vrais bruits de bouche. C'est la seule validation qui compte, et
elle demande des enregistrements réels.

---

## La sécurité de la révélation

**Imposée par la base, jamais par l'interface.** Si on se contentait de cacher
le pet dans l'app, n'importe qui pourrait récupérer l'URL du fichier et
écouter avant de soumettre.

- Le secret (audio + empreinte) est dans une table séparée `challenge_secrets`,
  parce que RLS agit par ligne et ne peut pas masquer une colonne
  conditionnellement.
- Les policies sur `storage.objects` appliquent la même règle au fichier.
- On ne peut pas soumettre après la révélation, ni voir les tentatives des
  autres avant.
- `reveal_at` est la seule mécanique d'état : révélé = `now() >= reveal_at`.
  Pas de machine à états, et la condition RLS reste une comparaison de dates.

**Limite connue** : le score est calculé sur l'appareil puis écrit en base, donc
un client malveillant pourrait écrire un faux score. Acceptable entre potes, et
vérifiable par tous puisque les empreintes sont publiques après révélation. À
déplacer côté serveur si le jeu sort du cercle privé.

---

## Simplifications assumées du v0

- **Un seul groupe** (`AppConfig.groupCode = 'POTES'`). La colonne existe déjà
  en base, les groupes multiples n'exigeront aucune migration.
- Pas de notifications, pas de badges, pas de classement cumulé.
- Révélation automatique après 12 h ; l'auteur peut l'avancer.

---

## Démarrer

Le backend est déjà en place, les identifiants sont en clair dans
`lib/config/supabase_config.dart` (même convention que Just Fart : la clé
publiable est publique par conception). Un clone du dépôt fonctionne
immédiatement.

```
flutter pub get
flutter run -d chrome
```

**Deux réglages Supabase indispensables**, faciles à oublier sur un nouveau
projet : exécuter `supabase/schema.sql` **et** `migration_001_fk_profiles.sql`,
puis activer **Authentication → Sign In / Providers → Anonymous Sign-Ins**.
Sans ce dernier, personne ne peut ouvrir l'app.

La migration 001 existe parce que `challenges` et `submissions` référençaient
`auth.users` : l'API refusait alors de joindre le pseudo depuis `profiles`
(« Could not find relationship … in the schema cache »).

---

## Déploiement

| | |
|---|---|
| Dépôt | `github.com/RBERROU/guess` (le dépôt s'appelle `guess`, le projet Flutter `guessmyfart`, l'identifiant iOS `com.bematerial.guessmyfart` — trois noms, c'est normal) |
| ⚠️ Android | garde l'ancien `com.guessmyfart.app` : changer l'`applicationId` obligerait à déplacer l'arborescence Kotlin. Sans conséquence tant que rien n'est publié sur Play, mais à aligner avant la première publication Android. |
| Web | **guessmyfart.netlify.app**, redéployé à chaque push sur `main` (5-8 min : Netlify reclone le SDK Flutter) |
| Supabase | projet `hbycfyxcwydygjbwxvsl`, distinct de Just Fart |
| iOS | **sur TestFlight** depuis le 3 août 2026 (build 5, version 0.1.0), workflow Codemagic `ios-testflight`, déclenché **manuellement** |

Le micro exige HTTPS : Netlify le fournit, une adresse IP locale ou `http://`
ne marchera jamais. Un écran de **Diagnostic** (Profil → « Le micro ne marche
pas ? ») dit ce que le navigateur autorise vraiment et teste la capture en 2 s.

## Signature iOS — lire avant de toucher au build

**Le profil de provisionnement est déposé à la main dans Codemagic**
(`Code signing identities → iOS provisioning profiles`, nom `Guess My Fart`,
expire en juillet 2027), exactement comme celui de Just Fart.

C'est le point qui a coûté une après-midi le 3 août 2026 : le `codemagic.yaml`
demande une signature *automatique* (`ios_signing` + `distribution_type`), donc
Codemagic va chercher le profil chez Apple via la clé API. Cette requête
revenait vide — *« No matching profiles found »* — alors que l'identifiant, le
certificat, le profil et la fiche App Store Connect existaient tous. **Déposer
le fichier du profil dans Codemagic a suffi.**

Donc : si un jour la signature casse à nouveau, ne pars pas à la chasse chez
Apple. Vérifie d'abord que le profil est toujours présent dans Codemagic, et
redépose-le au besoin.

Autres pièges rencontrés, pour mémoire :
- L'identifiant `com.guessmyfart.app` est **pris par un autre développeur** —
  les bundle IDs sont uniques à l'échelle d'Apple. D'où `com.bematerial.guessmyfart`.
- Le certificat Apple Distribution est **unique pour tout le compte** et sert à
  toutes les apps. Un seul certificat pour deux apps est normal.
- `ITSAppUsesNonExemptEncryption = false` est dans l'`Info.plist` pour éviter la
  question « Missing Compliance » à chaque envoi.

## État au 3 août 2026

En ligne et utilisable. `flutter analyze` propre, 6 tests au vert.

**Les micros fonctionnent** sur iPhone et Android, après deux corrections : la
capture passe par le flux PCM avec repli sur fichier, et les messages
distinguent « origine non sécurisée » de « permission refusée ».

**Interface refaite** dans un style neutre calqué sur des captures de
référence — fond gris clair, cartes blanches, bleu système, couleurs vives
réservées aux icônes des tuiles de statistiques. Trois onglets : défis,
classement, profil. Le premier essai en vert/marron a été rejeté par Romain.

**Sécurité de la révélation vérifiée** en simulant trois joueurs : 9 tests
passés, dont l'impossibilité de lire le secret ou les tentatives des autres
avant la révélation, et d'en soumettre une après.

**Le vrai test n'a pas encore eu lieu** : un pet, plusieurs imitations à
l'aveugle, et **comparer le classement machine au classement de l'oreille**.
C'est lui qui dira si le jeu tient. Tout le reste n'est que de la plomberie.

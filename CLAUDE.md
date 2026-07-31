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

Il faut un projet Supabase **distinct de Just Fart** — les deux ont une table
`profiles`.

1. créer le projet sur supabase.com
2. y exécuter `supabase/schema.sql`
3. lancer :

```
flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=eyJ...
```

Sans ces variables, l'app démarre sur un écran qui explique quoi faire plutôt
que de planter.

---

## État au 31 juillet 2026

Projet créé, `flutter analyze` propre, 4 tests au vert. Le cœur de mesure, le
schéma, les quatre écrans (liste, création, soumission, révélation) sont
écrits.

**Jamais exécuté sur un vrai appareil** : le projet Supabase n'existe pas
encore, et il n'y a pas de son sur le PC de Romain — donc aucun enregistrement
réel n'a été fait.

**Prochaine étape** : créer le projet Supabase, lancer l'app sur un téléphone,
enregistrer un vrai pet et quelques imitations, et **comparer le classement
machine au classement de l'oreille**. C'est ce test qui dira si le jeu tient.

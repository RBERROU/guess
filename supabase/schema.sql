-- Guess My Fart — schéma v0
--
-- Principe de sécurité central : personne ne doit pouvoir entendre le pet, ni
-- lire son empreinte, AVANT la révélation. Si on se contentait de le cacher
-- dans l'interface, n'importe qui pourrait récupérer l'URL du fichier et
-- écouter avant de soumettre — et tout le jeu s'effondre.
-- La règle est donc imposée par la base, pas par l'app.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------- profils

create table if not exists profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  pseudo      text not null,
  created_at  timestamptz not null default now()
);

alter table profiles enable row level security;

create policy "profils lisibles par tous les connectés"
  on profiles for select to authenticated using (true);

create policy "chacun écrit son profil"
  on profiles for insert to authenticated with check (id = auth.uid());

create policy "chacun modifie son profil"
  on profiles for update to authenticated using (id = auth.uid());

-- ----------------------------------------------------------------- défis

-- `reveal_at` est la seule mécanique d'état : révélé = now() >= reveal_at.
-- Pas de machine à états à maintenir, et la condition RLS reste une simple
-- comparaison de dates. Pour révéler tout de suite, l'auteur avance la date.
create table if not exists challenges (
  id          uuid primary key default gen_random_uuid(),
  author_id   uuid not null references auth.users(id) on delete cascade,
  group_code  text not null,
  created_at  timestamptz not null default now(),
  reveal_at   timestamptz not null,
  -- les indices, visibles de tous dès la création : ce sont eux qui rendent
  -- l'imitation à l'aveugle jouable, et ils servent d'axes au score
  duration_hint text not null check (duration_hint in ('court','moyen','long')),
  texture_hint  text not null check (texture_hint  in ('sec','humide')),
  rhythm_hint   text not null check (rhythm_hint   in ('continu','saccade')),
  pitch_hint    text not null check (pitch_hint    in ('grave','aigu')),
  context       text
);

create index if not exists challenges_group_idx on challenges(group_code, created_at desc);

alter table challenges enable row level security;

create policy "défis du groupe lisibles"
  on challenges for select to authenticated using (true);

create policy "chacun crée ses défis"
  on challenges for insert to authenticated with check (author_id = auth.uid());

create policy "l'auteur peut avancer la révélation"
  on challenges for update to authenticated using (author_id = auth.uid());

create policy "l'auteur peut supprimer son défi"
  on challenges for delete to authenticated using (author_id = auth.uid());

-- Le secret est dans une table séparée : RLS agit par ligne, pas par colonne,
-- donc on ne peut pas masquer une colonne conditionnellement. Isoler le secret
-- est la façon propre de le protéger.
create table if not exists challenge_secrets (
  challenge_id uuid primary key references challenges(id) on delete cascade,
  audio_path   text not null,
  fingerprint  jsonb not null
);

alter table challenge_secrets enable row level security;

create policy "secret visible après révélation, ou par son auteur"
  on challenge_secrets for select to authenticated using (
    exists (
      select 1 from challenges c
      where c.id = challenge_id
        and (now() >= c.reveal_at or c.author_id = auth.uid())
    )
  );

create policy "l'auteur dépose le secret"
  on challenge_secrets for insert to authenticated with check (
    exists (
      select 1 from challenges c
      where c.id = challenge_id and c.author_id = auth.uid()
    )
  );

-- ----------------------------------------------------------- soumissions

create table if not exists submissions (
  id           uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references challenges(id) on delete cascade,
  player_id    uuid not null references auth.users(id) on delete cascade,
  created_at   timestamptz not null default now(),
  audio_path   text not null,
  fingerprint  jsonb not null,
  score        jsonb,
  unique (challenge_id, player_id)   -- une seule tentative par joueur
);

create index if not exists submissions_challenge_idx on submissions(challenge_id);

alter table submissions enable row level security;

-- Avant la révélation on ne voit que la sienne : sinon on pourrait s'inspirer
-- des autres, et surtout déduire la cible en comparant les tentatives.
create policy "sa propre soumission, ou toutes après révélation"
  on submissions for select to authenticated using (
    player_id = auth.uid()
    or exists (
      select 1 from challenges c
      where c.id = challenge_id and now() >= c.reveal_at
    )
  );

-- On ne peut pas soumettre après la révélation : sinon il suffirait
-- d'attendre, d'écouter, puis d'imiter.
create policy "soumettre pour soi, avant la révélation"
  on submissions for insert to authenticated with check (
    player_id = auth.uid()
    and exists (
      select 1 from challenges c
      where c.id = challenge_id and now() < c.reveal_at
    )
  );

create policy "chacun met à jour le score de sa soumission"
  on submissions for update to authenticated using (player_id = auth.uid());

-- ------------------------------------------------- poids du score (réglables)

-- Les poids ne sont pas calibrés : aucun classement machine n'a encore été
-- comparé à un classement humain. Ils vivent donc en base pour être corrigés
-- sans republier l'app, et les empreintes brutes sont conservées afin de
-- pouvoir recalculer les défis passés.
create table if not exists score_weights (
  id         int primary key default 1 check (id = 1),
  weights    jsonb not null,
  updated_at timestamptz not null default now()
);

alter table score_weights enable row level security;

create policy "poids lisibles par tous"
  on score_weights for select to authenticated using (true);

insert into score_weights (id, weights) values (1, '{
  "duration": 0.25,
  "rhythm": 0.35,
  "pitch": 0.25,
  "texture": 0.15,
  "durationTolerance": 0.8,
  "burstTolerance": 4.0,
  "pitchTolerance": 0.9,
  "centroidTolerance": 1.2
}'::jsonb)
on conflict (id) do nothing;

-- ------------------------------------------------------------- stockage

insert into storage.buckets (id, name, public)
values ('farts', 'farts', false), ('attempts', 'attempts', false)
on conflict (id) do nothing;

-- Convention de nommage : farts/<challenge_id>.wav
-- L'accès au fichier suit exactement la même règle que le secret.
create policy "audio du pet après révélation, ou par son auteur"
  on storage.objects for select to authenticated using (
    bucket_id = 'farts'
    and exists (
      select 1 from challenges c
      where c.id::text = split_part(name, '.', 1)
        and (now() >= c.reveal_at or c.author_id = auth.uid())
    )
  );

create policy "l'auteur dépose son pet"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'farts' and owner = auth.uid());

-- Convention : attempts/<challenge_id>/<player_id>.wav
create policy "tentatives après révélation, la sienne toujours"
  on storage.objects for select to authenticated using (
    bucket_id = 'attempts'
    and (
      owner = auth.uid()
      or exists (
        select 1 from challenges c
        where c.id::text = split_part(name, '/', 1)
          and now() >= c.reveal_at
      )
    )
  );

create policy "déposer sa tentative"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'attempts' and owner = auth.uid());

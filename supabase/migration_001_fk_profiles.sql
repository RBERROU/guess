-- Migration 001 — rattacher challenges et submissions à `profiles`
--
-- Symptôme corrigé : « Could not find relationship between challenges and
-- profiles in the schema cache ».
--
-- Cause : les deux tables référençaient `auth.users`. L'API ne sait rapatrier
-- le pseudo en une seule requête que s'il existe une clé étrangère vers
-- `profiles`. L'intégrité reste identique, puisque profiles.id référence
-- lui-même auth.users.
--
-- À exécuter une fois dans le SQL Editor. Sans effet sur une base créée à
-- partir du schema.sql à jour.

-- Un profil doit exister pour chaque auteur/joueur déjà présent, sinon la
-- nouvelle contrainte serait rejetée. (Cas des données de test.)
insert into profiles (id, pseudo)
select distinct c.author_id, 'Joueur ' || upper(substr(c.author_id::text, 1, 4))
from challenges c
where not exists (select 1 from profiles p where p.id = c.author_id)
on conflict (id) do nothing;

insert into profiles (id, pseudo)
select distinct s.player_id, 'Joueur ' || upper(substr(s.player_id::text, 1, 4))
from submissions s
where not exists (select 1 from profiles p where p.id = s.player_id)
on conflict (id) do nothing;

alter table challenges drop constraint if exists challenges_author_id_fkey;
alter table challenges
  add constraint challenges_author_id_fkey
  foreign key (author_id) references profiles(id) on delete cascade;

alter table submissions drop constraint if exists submissions_player_id_fkey;
alter table submissions
  add constraint submissions_player_id_fkey
  foreign key (player_id) references profiles(id) on delete cascade;

-- Force PostgREST à relire le schéma sans attendre.
notify pgrst, 'reload schema';

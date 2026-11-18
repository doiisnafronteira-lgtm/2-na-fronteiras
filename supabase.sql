-- =====================================================================
-- 2 na Fronteiras - estrutura do banco na Supabase
-- Rodar uma vez no SQL Editor do projeto (pode rodar de novo sem problema).
-- =====================================================================

-- 1) Lista de e-mails autorizados a usar o sistema -----------------------
create table if not exists public.membros (
  email     text primary key check (email = lower(email)),
  nome      text,
  criado_em timestamptz not null default now()
);
alter table public.membros enable row level security;
-- Sem nenhuma politica: pelo site ninguem le nem altera esta lista.
-- Ela so e editada aqui no painel da Supabase.
revoke all on public.membros from anon, authenticated;

-- Diz se quem esta logado esta na lista de membros
create or replace function public.eh_membro() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.membros
    where email = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
$$;
revoke all on function public.eh_membro() from public, anon;
grant execute on function public.eh_membro() to authenticated;

-- 2) Todos os dados do sistema (um documento JSON por registro) ---------
create table if not exists public.docs (
  colecao        text not null check (colecao in ('viagens','produtos','clientes','vendas','parcelas','config','notas')),
  id             text not null check (id ~ '^[A-Za-z0-9_.-]{1,120}$'),
  dados          jsonb not null default '{}'::jsonb check (jsonb_typeof(dados) = 'object'),
  atualizado     timestamptz not null default now(),
  atualizado_por uuid,
  primary key (colecao, id)
);
alter table public.docs enable row level security;
revoke all on public.docs from anon;
grant select, insert, update, delete on public.docs to authenticated;

drop policy if exists "membros leem"     on public.docs;
drop policy if exists "membros inserem"  on public.docs;
drop policy if exists "membros alteram"  on public.docs;
drop policy if exists "membros apagam"   on public.docs;
create policy "membros leem"    on public.docs for select to authenticated using (public.eh_membro());
create policy "membros inserem" on public.docs for insert to authenticated with check (public.eh_membro());
create policy "membros alteram" on public.docs for update to authenticated using (public.eh_membro()) with check (public.eh_membro());
create policy "membros apagam"  on public.docs for delete to authenticated using (public.eh_membro());

-- Registra quando e quem alterou
create or replace function public.docs_carimbo() returns trigger
language plpgsql set search_path = public as $$
begin
  new.atualizado := now();
  new.atualizado_por := auth.uid();
  return new;
end $$;
drop trigger if exists docs_carimbo on public.docs;
create trigger docs_carimbo before insert or update on public.docs
  for each row execute function public.docs_carimbo();

-- Junta campos num documento existente (equivale ao PATCH do servidor local)
create or replace function public.docs_juntar(p_colecao text, p_id text, p_dados jsonb) returns void
language sql security invoker set search_path = public as $$
  update public.docs set dados = dados || p_dados where colecao = p_colecao and id = p_id
$$;
revoke all on function public.docs_juntar(text, text, jsonb) from public, anon;
grant execute on function public.docs_juntar(text, text, jsonb) to authenticated;

-- 3) Fotos das notas (privadas) -----------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('notas', 'notas', false, 26214400, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "membros veem fotos"   on storage.objects;
drop policy if exists "membros enviam fotos" on storage.objects;
drop policy if exists "membros apagam fotos" on storage.objects;
create policy "membros veem fotos"   on storage.objects for select to authenticated using (bucket_id = 'notas' and public.eh_membro());
create policy "membros enviam fotos" on storage.objects for insert to authenticated with check (bucket_id = 'notas' and public.eh_membro());
create policy "membros apagam fotos" on storage.objects for delete to authenticated using (bucket_id = 'notas' and public.eh_membro());

-- 4) E-mails autorizados -------------------------------------------------
-- Para liberar alguem, rode (com o e-mail em letras minusculas):
--   insert into public.membros (email, nome) values ('email@exemplo.com', 'Nome');
-- Para tirar o acesso:
--   delete from public.membros where email = 'email@exemplo.com';

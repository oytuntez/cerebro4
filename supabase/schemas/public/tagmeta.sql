-- --------------------------------------------------------------
--                                                            --
--                       public.tagmeta                       --
--                                                            --
-- --------------------------------------------------------------

drop function if exists set_tag_meta;

drop table if exists tagmeta;

-- --------------------------------------------------------------

-- Create a table
create table tagmeta (
  id bigint generated by default as identity primary key,
  tag_id bigint references tags(id) on delete cascade not null,
  meta_key varchar(255) not null,
  meta_value text,
  unique (tag_id, meta_key)
);

-- Add table indexing
create index tagmeta_tag_id_idx on tagmeta (tag_id);
create index tagmeta_meta_key_idx on tagmeta (meta_key);

-- Secure the table
alter table tagmeta enable row level security;

-- Add row-level security
create policy "Public access for all users" on tagmeta for select to authenticated, anon using ( true );
create policy "User can insert tagmeta" on tagmeta for insert to authenticated with check ( true );
create policy "User can update tagmeta" on tagmeta for update to authenticated using ( true );
create policy "User can delete tagmeta" on tagmeta for delete to authenticated using ( true );

-- --------------------------------------------------------------

create or replace function set_tag_meta(tagid bigint, metakey text, metavalue text = null)
returns void
security definer set search_path = public
as $$
begin
  if exists (select 1 from tagmeta where tag_id = tagid and meta_key = metakey) then
    update tagmeta set meta_value = metavalue where tag_id = tagid and meta_key = metakey;
  else
    insert into tagmeta(tag_id, meta_key, meta_value) values(tagid, metakey, metavalue);
  end if;
end;
$$ language plpgsql;

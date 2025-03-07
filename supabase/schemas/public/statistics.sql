-- --------------------------------------------------------------
--                                                            --
--                     public.statistics                      --
--                                                            --
-- --------------------------------------------------------------

drop function if exists set_statistics;
drop function if exists truncate_statistics;
drop function if exists get_post_rank_by_views;

drop table if exists statistics;

-- --------------------------------------------------------------

-- Create a table
create table statistics (
  id bigint generated by default as identity primary key,
  created_at timestamptz default now() not null,
  visitor_id uuid not null,
  user_id uuid references users(id) on delete cascade,
  title text,
  location text,
  path text,
  query text,
  referrer text,
  ip inet,
  browser jsonb,
  user_agent text
);

-- Add table indexing
create index statistics_visitor_id_idx on statistics (visitor_id);
create index statistics_user_id_idx on statistics (user_id);

-- Secure the table
alter table statistics enable row level security;

-- Add row-level security
create policy "Public access for all users" on statistics for select to authenticated, anon using ( true );
create policy "User can insert statistics" on statistics for insert to authenticated with check ( true );
create policy "User can update statistics" on statistics for update to authenticated using ( true );
create policy "User can delete statistics" on statistics for delete to authenticated using ( true );

-- --------------------------------------------------------------

create or replace function set_statistics(data json)
returns void
security definer set search_path = public
as $$
begin
  insert into statistics
  (visitor_id,user_id,title,location,path,query,referrer,ip,browser,user_agent)
  values
  (
    (data ->> 'visitor_id')::uuid,
    coalesce((data ->> 'user_id')::uuid, null),
    (data ->> 'title')::text,
    (data ->> 'location')::text,
    (data ->> 'path')::text,
    (data ->> 'query')::text,
    (data ->> 'referrer')::text,
    (data ->> 'ip')::inet,
    (data ->> 'browser')::jsonb,
    (data ->> 'user_agent')::text
  );
end;
$$ language plpgsql;

-- --------------------------------------------------------------

create or replace function truncate_statistics()
returns void
security definer set search_path = public
as $$
begin
  truncate table statistics restart identity cascade;
end;
$$ language plpgsql;

-- --------------------------------------------------------------

create or replace function get_post_rank_by_views(
	username text,
	q text = '',
	order_by text = 'views',
	ascending boolean = true,
	per_page integer = 10,
	page integer = 1,
  head boolean = false
)
returns table(path text, title text, views bigint)
security definer set search_path = public
as $$
declare
  _command text;
  _order text;
  _offset integer;
begin
  _order := case when ascending is false then 'desc' else 'asc' end;
  _offset := (page - 1) * per_page;

  if q <> '' then
    if head then
      _command := 'select s.path, s.title, count(*) as views
      from statistics s
      where s.path like ''/'|| username ||'/%%''
        and s.path not like ''/'|| username ||'/favorites''
        and s.title ilike ''%%'|| q ||'%%''
      group by s.path, s.title ';
      return query execute format(_command) using username, q;
    else
      _command := 'select s.path, s.title, count(*) as views
      from statistics s
      where s.path like ''/'|| username ||'/%%''
        and s.path not like ''/'|| username ||'/favorites''
        and s.title ilike ''%%'|| q ||'%%''
      group by s.path, s.title
      order by %I %s limit %s offset %s ';
      return query execute format(_command, order_by, _order, per_page, _offset) using username, q;
    end if;
  else
    if head then
      _command := 'select s.path, s.title, count(*) as views
      from statistics s
      where s.path like ''/'|| username ||'/%%''
        and s.path not like ''/'|| username ||'/favorites''
      group by s.path, s.title ';
      return query execute format(_command) using username;
    else
      _command := 'select s.path, s.title, count(*) as views
      from statistics s
      where s.path like ''/'|| username ||'/%%''
        and s.path not like ''/'|| username ||'/favorites''
      group by s.path, s.title
      order by %I %s limit %s offset %s ';
      return query execute format(_command, order_by, _order, per_page, _offset) using username;
    end if;
  end if;

end;
$$ language plpgsql;

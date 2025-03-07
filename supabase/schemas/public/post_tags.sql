-- --------------------------------------------------------------
--                                                            --
--                      public.post_tags                      --
--                                                            --
-- --------------------------------------------------------------

drop function if exists set_post_tags;

drop table if exists post_tags;

-- --------------------------------------------------------------

-- Create a table
create table post_tags (
  id bigint generated by default as identity primary key,
  user_id uuid references users(id) on delete cascade not null,
  post_id bigint references posts(id) on delete cascade not null,
  tag_id bigint references tags(id) on delete cascade not null,
  unique (user_id, post_id, tag_id)
);

-- Add table indexing
create index post_tags_user_id_idx on post_tags (user_id);
create index post_tags_post_id_idx on post_tags (post_id);
create index post_tags_tag_id_idx on post_tags (tag_id);
create index post_tags_user_id_post_id_idx on post_tags (user_id, post_id);

-- Secure the table
alter table post_tags enable row level security;

-- Add row-level security
create policy "Public access for all users" on post_tags for select to authenticated, anon using ( true );
create policy "User can insert their own post_tags" on post_tags for insert to authenticated with check ( (select auth.uid()) = user_id );
create policy "User can update their own post_tags" on post_tags for update to authenticated using ( (select auth.uid()) = user_id );
create policy "User can delete their own post_tags" on post_tags for delete to authenticated using ( (select auth.uid()) = user_id );

-- --------------------------------------------------------------

create or replace function set_post_tags(
  userid uuid,
  postid bigint
)
returns void
security definer set search_path = public
as $$
declare
  tagnames text[];
  tagid bigint;
  metavalue text;
  element jsonb;
begin

	select array_agg(names) into tagnames from (select jsonb_array_elements(meta_value::jsonb)->>'text'::text as names from postmeta where post_id = postid and meta_key = 'tags') t;

 	if array_length(tagnames, 1) > 0 then
		delete from post_tags pt using tags t where pt.user_id = userid and pt.post_id = postid and pt.tag_id = t.id and t.name != all(coalesce(tagnames, array[]::text[]));
  else
		delete from post_tags where user_id = userid and post_id = postid;
 	end if;

  select meta_value into metavalue from postmeta where post_id = postid and meta_key = 'tags';

 	for element in (select * from jsonb_array_elements(metavalue::jsonb)) loop
 		if not exists (select 1 from post_tags pt join tags t on t.id = pt.tag_id where pt.user_id = userid and pt.post_id = postid and t.name = element->>'text') then
 			if exists (select 1 from tags where user_id = userid and name = element->>'text') then
 				select id into tagid from tags where user_id = userid and name = element->>'text';
 			else
	 			insert into tags(user_id, name, slug) values(userid, element->>'text', element->>'slug')
		    returning id into tagid;
	    end if;
 			insert into post_tags(user_id, post_id, tag_id) values(userid, postid, tagid);
 		end if;
 	end loop;

end;
$$ language plpgsql;

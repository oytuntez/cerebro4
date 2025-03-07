-- --------------------------------------------------------------
--                                                            --
--                       public.emails                        --
--                                                            --
-- --------------------------------------------------------------

-- Functions for tracking last modification time
create extension if not exists moddatetime schema extensions;

-- --------------------------------------------------------------

drop trigger if exists on_updated_at on emails;

drop table if exists emails;

-- --------------------------------------------------------------

-- Create a table
create table emails (
  id bigint generated by default as identity primary key,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null,
  user_id uuid references users(id) on delete cascade not null,
  email varchar(255) not null,
  email_confirmed_at timestamptz,
  unique (user_id, email)
);
comment on column emails.updated_at is 'on_updated_at';

-- Add table indexing
create index emails_user_id_idx on emails (user_id);
create index emails_email_idx on emails (email);

-- Secure the table
alter table emails enable row level security;

-- Add row-level security
create policy "User can select their own emails" on emails for select to authenticated using ( (select auth.uid()) = user_id );
create policy "User can insert their own emails" on emails for insert to authenticated with check ( (select auth.uid()) = user_id );
create policy "User can update their own emails" on emails for update to authenticated using ( (select auth.uid()) = user_id );
create policy "User can delete their own emails" on emails for delete to authenticated using ( (select auth.uid()) = user_id );

-- Trigger for tracking last modification time
create trigger on_updated_at before update on emails
  for each row execute procedure moddatetime (updated_at);

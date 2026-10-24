-- Run once in Supabase Dashboard > SQL Editor.
-- Manager profile images are uploaded by the ASP.NET server with its
-- existing service-role key. The bucket must be public so <img> works
-- for signed-in managers with a normal browser request.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('profile-photos', 'profile-photos', true, 2097152,
        ARRAY['image/jpeg', 'image/png']::text[])
ON CONFLICT (id) DO UPDATE
SET public = true,
    file_size_limit = 2097152,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png']::text[];

-- Keep existing profile photo links from the database accessible.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS photo_url text;

-- No public write policies: only the server's service-role key should
-- upload or delete manager profile photos.

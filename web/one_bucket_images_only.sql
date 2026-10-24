-- CUTTING EDGE: one bucket for NEW image uploads.
-- Run in Supabase Dashboard > SQL Editor.
-- Re-runnable; does not copy/delete images or remove old buckets.

INSERT INTO storage.buckets
    (id, name, public, file_size_limit, allowed_mime_types)
VALUES
    ('catalog-images', 'catalog-images', true, 5242880,
     ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']::text[])
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE public.promotions ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Allow an authenticated customer or stylist to upload/replace/delete
-- ONLY their own profile images. Manager, service, promotions and salon
-- pictures must be uploaded from ASP.NET using server-side credentials.
CREATE OR REPLACE FUNCTION public.can_edit_own_catalog_avatar(p_path TEXT)
RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT auth.uid() IS NOT NULL AND (
    (split_part(p_path, '/', 1) = 'customers'
      AND split_part(p_path, '/', 2) = auth.uid()::TEXT
      AND EXISTS (SELECT 1 FROM public.customers c WHERE c.customer_id = auth.uid()))
    OR
    (split_part(p_path, '/', 1) = 'stylists'
      AND split_part(p_path, '/', 2) = auth.uid()::TEXT
      AND EXISTS (SELECT 1 FROM public.stylists s WHERE s.profile_id = auth.uid()))
  );
$$;
REVOKE ALL ON FUNCTION public.can_edit_own_catalog_avatar(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_edit_own_catalog_avatar(TEXT) TO authenticated;

DROP POLICY IF EXISTS "cutting_edge_insert_own_avatar" ON storage.objects;
CREATE POLICY "cutting_edge_insert_own_avatar"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'catalog-images' AND public.can_edit_own_catalog_avatar(name));

-- Required by Supabase Storage when an authenticated user updates an object.
DROP POLICY IF EXISTS "cutting_edge_read_own_avatar" ON storage.objects;
CREATE POLICY "cutting_edge_read_own_avatar"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'catalog-images' AND public.can_edit_own_catalog_avatar(name));

DROP POLICY IF EXISTS "cutting_edge_update_own_avatar" ON storage.objects;
CREATE POLICY "cutting_edge_update_own_avatar"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'catalog-images' AND public.can_edit_own_catalog_avatar(name))
WITH CHECK (bucket_id = 'catalog-images' AND public.can_edit_own_catalog_avatar(name));

DROP POLICY IF EXISTS "cutting_edge_delete_own_avatar" ON storage.objects;
CREATE POLICY "cutting_edge_delete_own_avatar"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'catalog-images' AND public.can_edit_own_catalog_avatar(name));

-- Supabase PostgREST can take a moment to refresh after schema changes.
NOTIFY pgrst, 'reload schema';

SELECT id, public, file_size_limit, allowed_mime_types
FROM storage.buckets
WHERE id = 'catalog-images';

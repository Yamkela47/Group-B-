-- Run in Supabase SQL Editor if you haven't already run
-- Database/catalog_and_booking_rules.sql from your latest updated project.
-- This adds image storage only; it does not change existing promotions.
ALTER TABLE public.promotions
ADD COLUMN IF NOT EXISTS image_url text;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('catalog-images', 'catalog-images', true, 2097152,
        ARRAY['image/jpeg', 'image/png']::text[])
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 2097152,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png']::text[];

-- Checking existing promotions (optional):
-- SELECT promotion_id, title, image_url FROM public.promotions ORDER BY promotion_id;

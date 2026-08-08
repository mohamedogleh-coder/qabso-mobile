
-- Create storage bucket
INSERT INTO storage.buckets (id,name,public)
VALUES ('playground','playground',true)
    ON CONFLICT (id) DO UPDATE SET public = true;

-- Anyone can view files
CREATE POLICY "Anyone can view playground files"
ON storage.objects
FOR SELECT
               TO public
               USING (
               bucket_id = 'playground'
               );


-- Authenticated users can upload files
CREATE POLICY "Authenticated users can upload playground files"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'playground'
);


-- Authenticated users can update files
CREATE POLICY "Authenticated users can update playground files"
ON storage.objects
FOR UPDATE
                      TO authenticated
                      USING (
                      bucket_id = 'playground'
                      )
    WITH CHECK (
                      bucket_id = 'playground'
                      );


-- Authenticated users can delete files
CREATE POLICY "Authenticated users can delete playground files"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'playground'
);
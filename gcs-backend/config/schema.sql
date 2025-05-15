-- Enable pgcrypto extension for gen_random_uuid function
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Attempt to drop the problematic invoice_id column and related constraints if they exist
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='invoice_images' AND column_name='invoice_id') THEN
        -- Drop foreign key constraints that might depend on invoice_id if they were named differently
        -- For example, if expenses had a direct FK to an invoice_id on invoice_images
        -- ALTER TABLE IF EXISTS expenses DROP CONSTRAINT IF EXISTS fk_expenses_invoice_id;

        -- Drop the column
        ALTER TABLE invoice_images DROP COLUMN invoice_id;
        RAISE NOTICE 'Column invoice_id dropped from invoice_images.';
    ELSE
        RAISE NOTICE 'Column invoice_id does not exist in invoice_images, no action taken.';
    END IF;

    -- Attempt to drop old index if it exists
    DROP INDEX IF EXISTS idx_invoice_images_invoice_id;
    RAISE NOTICE 'Attempted to drop index idx_invoice_images_invoice_id.';

EXCEPTION
    WHEN undefined_table THEN
        RAISE NOTICE 'Table invoice_images does not exist, no action taken on invoice_id column.';
    WHEN others THEN
        RAISE NOTICE 'An error occurred while trying to drop invoice_id: %', SQLERRM;
END $$;

-- Projects Table
CREATE TABLE IF NOT EXISTS projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    location TEXT,
    start_date TIMESTAMP WITH TIME ZONE,
    end_date TIMESTAMP WITH TIME ZONE,
    budget DECIMAL(10, 2),
    is_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Invoice Images Table
CREATE TABLE IF NOT EXISTS invoice_images (
    id TEXT PRIMARY KEY,
    project_id UUID NOT NULL,
    user_id TEXT NOT NULL,
    gcs_path TEXT NOT NULL,
    status TEXT NOT NULL,
    is_invoice BOOLEAN,
    ocr_text TEXT,
    ocr_confidence DECIMAL(5, 2),
    ocr_text_blocks JSONB,
    ocr_processed_at TIMESTAMP WITH TIME ZONE,
    analysis_processed_at TIMESTAMP WITH TIME ZONE,
    invoice_date TIMESTAMP WITH TIME ZONE,
    invoice_sum DECIMAL(10, 2),
    invoice_currency TEXT,
    invoice_taxes DECIMAL(10, 2),
    invoice_location TEXT,
    invoice_category TEXT,
    invoice_taxonomy TEXT,
    gemini_analysis_json JSONB,
    error_message TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add foreign keys for invoice_images
DO $$
BEGIN
    ALTER TABLE invoice_images ADD CONSTRAINT fk_invoice_images_project_id FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
    WHEN undefined_table THEN NULL;
    WHEN undefined_column THEN NULL;
    WHEN others THEN RAISE NOTICE 'Error adding constraint: %', SQLERRM;
END $$;

-- Expenses Table
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL,
    user_id TEXT NOT NULL,
    invoice_image_id TEXT,
    amount DECIMAL(10, 2) NOT NULL,
    currency TEXT,
    category TEXT,
    description TEXT,
    date TIMESTAMP WITH TIME ZONE,
    location TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add foreign keys for expenses
DO $$
BEGIN
    ALTER TABLE expenses ADD CONSTRAINT fk_expenses_project_id FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
    WHEN undefined_table THEN NULL;
    WHEN undefined_column THEN NULL;
    WHEN others THEN RAISE NOTICE 'Error adding constraint: %', SQLERRM;
END $$;

DO $$
BEGIN
    ALTER TABLE expenses ADD CONSTRAINT fk_expenses_invoice_image_id FOREIGN KEY (invoice_image_id) REFERENCES invoice_images(id) ON DELETE SET NULL;
EXCEPTION
    WHEN duplicate_object THEN NULL;
    WHEN undefined_table THEN NULL;
    WHEN undefined_column THEN NULL;
    WHEN others THEN RAISE NOTICE 'Error adding constraint: %', SQLERRM;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_projects_user_id ON projects(user_id);
CREATE INDEX IF NOT EXISTS idx_invoice_images_project_id ON invoice_images(project_id);
CREATE INDEX IF NOT EXISTS idx_invoice_images_user_id ON invoice_images(user_id);
CREATE INDEX IF NOT EXISTS idx_expenses_project_id ON expenses(project_id);
CREATE INDEX IF NOT EXISTS idx_expenses_user_id ON expenses(user_id); 
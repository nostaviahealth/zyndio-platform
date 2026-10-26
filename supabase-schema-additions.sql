-- Meal Plans Table
CREATE TABLE IF NOT EXISTS meal_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  version INTEGER NOT NULL DEFAULT 1,
  week_start_date DATE NOT NULL,
  weekly_plan JSONB NOT NULL,
  approved BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  notes TEXT
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_meal_plans_profile_id ON meal_plans(profile_id);
CREATE INDEX IF NOT EXISTS idx_meal_plans_created_at ON meal_plans(created_at DESC);

-- Intelligence Data Table
CREATE TABLE IF NOT EXISTS intelligence_data (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  longevity_score INTEGER,
  bio_age INTEGER,
  pace_of_aging DECIMAL(3,2),
  health_grade VARCHAR(2),
  risk_level VARCHAR(20),
  key_insights JSONB,
  disease_risks JSONB,
  biomarker_summary JSONB,
  recommendations JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_intelligence_profile_id ON intelligence_data(profile_id);

-- Enable RLS (disabled for now, will enable after testing)
-- ALTER TABLE meal_plans ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE intelligence_data ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE meal_plans IS 'Stores weekly meal plans for patients';
COMMENT ON TABLE intelligence_data IS 'Stores AI-generated health intelligence for patients';

-- Terms & Conditions and PHI Consent Logging Tables
-- This migration creates tables for tracking user consent to T&C and PHI agreements
-- with full audit trails including timestamps, versions, IP addresses, and user agents

-- Consent documents table
-- Stores different versions of T&C and PHI consent documents
CREATE TABLE IF NOT EXISTS consent_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_type TEXT NOT NULL CHECK (document_type IN ('terms_and_conditions', 'phi_consent', 'privacy_policy')),
  version TEXT NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  effective_date TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(document_type, version)
);

-- User consent logs table
-- Tracks when users accept or revoke consent to specific documents
CREATE TABLE IF NOT EXISTS user_consent_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  document_id UUID NOT NULL REFERENCES consent_documents(id) ON DELETE RESTRICT,
  document_type TEXT NOT NULL,
  document_version TEXT NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('accepted', 'revoked', 'updated')),
  ip_address TEXT,
  user_agent TEXT,
  device_info JSONB DEFAULT '{}',
  location_data JSONB DEFAULT '{}',
  consent_method TEXT CHECK (consent_method IN ('onboarding', 'account_settings', 'forced_update', 'api')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Current user consent status table
-- Stores the current/active consent status for each user and document type
CREATE TABLE IF NOT EXISTS user_consent_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  document_type TEXT NOT NULL CHECK (document_type IN ('terms_and_conditions', 'phi_consent', 'privacy_policy')),
  document_id UUID NOT NULL REFERENCES consent_documents(id) ON DELETE RESTRICT,
  document_version TEXT NOT NULL,
  is_consented BOOLEAN DEFAULT true,
  consented_at TIMESTAMPTZ NOT NULL,
  ip_address TEXT,
  user_agent TEXT,
  consent_method TEXT,
  last_updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, document_type)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_consent_documents_type_active ON consent_documents(document_type, is_active);
CREATE INDEX IF NOT EXISTS idx_consent_documents_effective_date ON consent_documents(effective_date DESC);
CREATE INDEX IF NOT EXISTS idx_user_consent_logs_user_id ON user_consent_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_user_consent_logs_document_id ON user_consent_logs(document_id);
CREATE INDEX IF NOT EXISTS idx_user_consent_logs_created_at ON user_consent_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_consent_logs_user_document ON user_consent_logs(user_id, document_type);
CREATE INDEX IF NOT EXISTS idx_user_consent_status_user_id ON user_consent_status(user_id);
CREATE INDEX IF NOT EXISTS idx_user_consent_status_user_type ON user_consent_status(user_id, document_type);

-- Enable Row Level Security
ALTER TABLE consent_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_consent_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_consent_status ENABLE ROW LEVEL SECURITY;

-- RLS Policies for consent_documents
-- Anyone can view active consent documents (needed for signup flow)
CREATE POLICY "Anyone can view active consent documents"
  ON consent_documents FOR SELECT
  USING (is_active = true);

-- Only admins can insert/update/delete consent documents (future admin feature)
CREATE POLICY "Admins can manage consent documents"
  ON consent_documents FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.preferences->>'role' = 'admin'
    )
  );

-- RLS Policies for user_consent_logs
-- Users can view their own consent logs
CREATE POLICY "Users can view their own consent logs"
  ON user_consent_logs FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own consent logs
CREATE POLICY "Users can insert their own consent logs"
  ON user_consent_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Admins can view all consent logs (for compliance audits)
CREATE POLICY "Admins can view all consent logs"
  ON user_consent_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.preferences->>'role' = 'admin'
    )
  );

-- RLS Policies for user_consent_status
-- Users can view their own consent status
CREATE POLICY "Users can view their own consent status"
  ON user_consent_status FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own consent status
CREATE POLICY "Users can insert their own consent status"
  ON user_consent_status FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own consent status
CREATE POLICY "Users can update their own consent status"
  ON user_consent_status FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Admins can view all consent statuses
CREATE POLICY "Admins can view all consent statuses"
  ON user_consent_status FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.preferences->>'role' = 'admin'
    )
  );

-- Comments for documentation
COMMENT ON TABLE consent_documents IS 'Stores different versions of consent documents (T&C, PHI, Privacy Policy)';
COMMENT ON TABLE user_consent_logs IS 'Audit trail of all user consent actions with IP, user agent, and device info';
COMMENT ON TABLE user_consent_status IS 'Current active consent status for each user and document type';
COMMENT ON COLUMN user_consent_logs.ip_address IS 'IP address from which consent was given';
COMMENT ON COLUMN user_consent_logs.user_agent IS 'Browser/app user agent string';
COMMENT ON COLUMN user_consent_logs.device_info IS 'Device information (platform, OS, app version, etc.)';
COMMENT ON COLUMN user_consent_logs.location_data IS 'Optional geolocation data (country, region) for compliance';
COMMENT ON COLUMN user_consent_logs.consent_method IS 'Where the consent was captured (onboarding, settings, etc.)';

-- RizzMePlease Database Schema
-- Run this in your Supabase SQL Editor

-- ============================================================================
-- Enable Extensions
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- Users Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE,
    password_hash VARCHAR(255),
    is_anonymous BOOLEAN DEFAULT true,
    preferences JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_users_email ON users(email) WHERE email IS NOT NULL;
CREATE INDEX idx_users_deleted_at ON users(deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_users_created_at ON users(created_at DESC);

-- ============================================================================
-- Conversations Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    raw_text TEXT NOT NULL,
    goal VARCHAR(50) NOT NULL,
    tone VARCHAR(50) NOT NULL,
    context TEXT,
    prompt_version VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_conversations_user_id ON conversations(user_id);
CREATE INDEX idx_conversations_created_at ON conversations(created_at DESC);
CREATE INDEX idx_conversations_goal ON conversations(goal);
CREATE INDEX idx_conversations_deleted_at ON conversations(deleted_at) WHERE deleted_at IS NOT NULL;

-- ============================================================================
-- Suggestions Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS suggestions (
    id VARCHAR(36) PRIMARY KEY,
    suggestion_set_id VARCHAR(36) NOT NULL,
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    rank SMALLINT NOT NULL,
    text TEXT NOT NULL,
    rationale TEXT NOT NULL,
    confidence_score DECIMAL(4,3),
    copied_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_suggestions_conversation_id ON suggestions(conversation_id);
CREATE INDEX idx_suggestions_set_id ON suggestions(suggestion_set_id);
CREATE INDEX idx_suggestions_created_at ON suggestions(created_at DESC);

-- ============================================================================
-- Feedback Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS feedback (
    id VARCHAR(36) PRIMARY KEY,
    suggestion_id VARCHAR(36) NOT NULL REFERENCES suggestions(id) ON DELETE CASCADE,
    outcome VARCHAR(20) NOT NULL,
    follow_up_text TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_feedback_suggestion_id ON feedback(suggestion_id);
CREATE INDEX idx_feedback_outcome ON feedback(outcome);
CREATE INDEX idx_feedback_created_at ON feedback(created_at DESC);

-- Constraint: outcome must be one of the allowed values
ALTER TABLE feedback ADD CONSTRAINT chk_outcome 
    CHECK (outcome IN ('worked', 'no_response', 'negative', 'skipped'));

-- ============================================================================
-- Coach Analyses Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS coach_analyses (
    id VARCHAR(36) PRIMARY KEY,
    conversation_id VARCHAR(50) NOT NULL,  -- Can be UUID or temp_ prefix
    insights JSONB NOT NULL,
    overall_score SMALLINT,
    prompt_version VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_coach_analyses_conversation_id ON coach_analyses(conversation_id);
CREATE INDEX idx_coach_analyses_created_at ON coach_analyses(created_at DESC);

-- ============================================================================
-- Row Level Security (RLS)
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE suggestions ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE coach_analyses ENABLE ROW LEVEL SECURITY;

-- Users: users can only access their own row
CREATE POLICY users_own_data ON users
    FOR ALL USING (id = auth.uid());

-- Conversations: users can only access their own conversations
CREATE POLICY conversations_own_data ON conversations
    FOR ALL USING (user_id = auth.uid());

-- Suggestions: users can access suggestions for their conversations
CREATE POLICY suggestions_own_data ON suggestions
    FOR ALL USING (
        conversation_id IN (
            SELECT id FROM conversations WHERE user_id = auth.uid()
        )
    );

-- Feedback: users can access feedback for their suggestions
CREATE POLICY feedback_own_data ON feedback
    FOR ALL USING (
        suggestion_id IN (
            SELECT s.id FROM suggestions s
            JOIN conversations c ON s.conversation_id = c.id
            WHERE c.user_id = auth.uid()
        )
    );

-- Note: Service role bypasses RLS for backend operations

-- ============================================================================
-- Data Retention (Optional: Automatic cleanup)
-- ============================================================================

-- Function to clean up old deleted data (run via cron)
CREATE OR REPLACE FUNCTION cleanup_deleted_data() RETURNS void AS $$
BEGIN
    -- Delete users soft-deleted more than 72 hours ago
    DELETE FROM users 
    WHERE deleted_at IS NOT NULL 
    AND deleted_at < NOW() - INTERVAL '72 hours';
    
    -- Delete old conversations (90 days retention)
    DELETE FROM conversations 
    WHERE created_at < NOW() - INTERVAL '90 days'
    AND deleted_at IS NULL;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Success!
-- ============================================================================

-- Run this to verify tables were created:
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';

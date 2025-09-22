"""Add performance indexes

Revision ID: 002
Revises: 001
Create Date: 2024-01-01 00:01:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '002'
down_revision = '001'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Agents table indexes
    op.create_index('idx_agent_address', 'agents', ['agent_address'])
    op.create_index('idx_agent_domain', 'agents', ['agent_domain'])
    op.create_index('idx_agent_active', 'agents', ['is_active'])
    
    # Feedback table indexes
    op.create_index('idx_feedback_auth_id', 'feedback', ['feedback_auth_id'])
    op.create_index('idx_feedback_server_id', 'feedback', ['agent_server_id'])
    op.create_index('idx_feedback_client_id', 'feedback', ['agent_client_id'])
    op.create_index('idx_feedback_skill_id', 'feedback', ['agent_skill_id'])
    op.create_index('idx_feedback_task_id', 'feedback', ['task_id'])
    op.create_index('idx_feedback_created_at', 'feedback', ['created_at'])
    
    # Validation requests indexes
    op.create_index('idx_validation_req_hash', 'validation_requests', ['data_hash'])
    op.create_index('idx_validation_req_validator', 'validation_requests', ['agent_validator_id'])
    op.create_index('idx_validation_req_server', 'validation_requests', ['agent_server_id'])
    op.create_index('idx_validation_req_expires', 'validation_requests', ['expires_at'])
    
    # Validation responses indexes
    op.create_index('idx_validation_resp_hash', 'validation_responses', ['data_hash'])
    op.create_index('idx_validation_resp_validator', 'validation_responses', ['agent_validator_id'])
    op.create_index('idx_validation_resp_created', 'validation_responses', ['created_at'])


def downgrade() -> None:
    # Drop validation response indexes
    op.drop_index('idx_validation_resp_created')
    op.drop_index('idx_validation_resp_validator')
    op.drop_index('idx_validation_resp_hash')
    
    # Drop validation request indexes
    op.drop_index('idx_validation_req_expires')
    op.drop_index('idx_validation_req_server')
    op.drop_index('idx_validation_req_validator')
    op.drop_index('idx_validation_req_hash')
    
    # Drop feedback indexes
    op.drop_index('idx_feedback_created_at')
    op.drop_index('idx_feedback_task_id')
    op.drop_index('idx_feedback_skill_id')
    op.drop_index('idx_feedback_client_id')
    op.drop_index('idx_feedback_server_id')
    op.drop_index('idx_feedback_auth_id')
    
    # Drop agent indexes
    op.drop_index('idx_agent_active')
    op.drop_index('idx_agent_domain')
    op.drop_index('idx_agent_address')
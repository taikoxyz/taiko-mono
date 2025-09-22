"""Initial database schema for ERC-8004

Revision ID: 001
Revises: 
Create Date: 2024-01-01 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create agents table
    op.create_table('agents',
        sa.Column('agent_id', sa.Integer(), nullable=False),
        sa.Column('agent_address', sa.String(length=255), nullable=False),
        sa.Column('agent_domain', sa.String(length=255), nullable=False),
        sa.Column('agent_card', sa.JSON(), nullable=False),
        sa.Column('signature', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.PrimaryKeyConstraint('agent_id'),
        sa.UniqueConstraint('agent_address')
    )
    
    # Create feedback table
    op.create_table('feedback',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('feedback_auth_id', sa.String(length=255), nullable=False),
        sa.Column('agent_client_id', sa.Integer(), nullable=True),
        sa.Column('agent_server_id', sa.Integer(), nullable=True),
        sa.Column('agent_skill_id', sa.String(length=255), nullable=True),
        sa.Column('task_id', sa.String(length=255), nullable=True),
        sa.Column('context_id', sa.String(length=255), nullable=True),
        sa.Column('rating', sa.Integer(), nullable=True),
        sa.Column('proof_of_payment', sa.JSON(), nullable=True),
        sa.Column('data', sa.JSON(), nullable=True),
        sa.Column('signature', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('ipfs_hash', sa.String(length=255), nullable=True),
        sa.CheckConstraint('rating >= 0 AND rating <= 100', name='chk_rating_range'),
        sa.ForeignKeyConstraint(['agent_client_id'], ['agents.agent_id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['agent_server_id'], ['agents.agent_id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('feedback_auth_id')
    )
    
    # Create validation_requests table
    op.create_table('validation_requests',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('data_hash', sa.String(length=255), nullable=False),
        sa.Column('agent_validator_id', sa.Integer(), nullable=False),
        sa.Column('agent_server_id', sa.Integer(), nullable=False),
        sa.Column('data_uri', sa.Text(), nullable=False),
        sa.Column('validation_data', sa.JSON(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['agent_server_id'], ['agents.agent_id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['agent_validator_id'], ['agents.agent_id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('data_hash')
    )
    
    # Create validation_responses table
    op.create_table('validation_responses',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('data_hash', sa.String(length=255), nullable=False),
        sa.Column('agent_validator_id', sa.Integer(), nullable=False),
        sa.Column('response', sa.Integer(), nullable=False),
        sa.Column('evidence', sa.JSON(), nullable=True),
        sa.Column('validator_signature', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('ipfs_hash', sa.String(length=255), nullable=True),
        sa.CheckConstraint('response >= 0 AND response <= 100', name='chk_response_range'),
        sa.ForeignKeyConstraint(['agent_validator_id'], ['agents.agent_id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['data_hash'], ['validation_requests.data_hash'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )


def downgrade() -> None:
    op.drop_table('validation_responses')
    op.drop_table('validation_requests')
    op.drop_table('feedback')
    op.drop_table('agents')
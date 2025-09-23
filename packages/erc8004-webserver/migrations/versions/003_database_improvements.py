"""Database improvements: constraints, nullable validator, eager loading

Revision ID: 003_database_improvements
Revises: 002_add_indexes
Create Date: 2025-01-23 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '003_database_improvements'
down_revision = '002_add_indexes'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Make ValidationRequest.agent_validator_id nullable for public requests
    op.alter_column('validation_requests', 'agent_validator_id',
                    existing_type=sa.INTEGER(),
                    nullable=True)
    
    # Add composite unique constraints for feedback
    op.create_unique_constraint(
        'uq_feedback_client_task', 
        'feedback', 
        ['agent_client_id', 'task_id']
    )
    
    op.create_unique_constraint(
        'uq_feedback_client_server_skill_context', 
        'feedback', 
        ['agent_client_id', 'agent_server_id', 'agent_skill_id', 'context_id']
    )
    
    # Add composite indexes for better query performance
    op.create_index(
        'idx_feedback_server_skill', 
        'feedback', 
        ['agent_server_id', 'agent_skill_id']
    )
    
    op.create_index(
        'idx_feedback_client_server', 
        'feedback', 
        ['agent_client_id', 'agent_server_id']
    )


def downgrade() -> None:
    # Remove composite indexes
    op.drop_index('idx_feedback_client_server', table_name='feedback')
    op.drop_index('idx_feedback_server_skill', table_name='feedback')
    
    # Remove unique constraints
    op.drop_constraint('uq_feedback_client_server_skill_context', 'feedback', type_='unique')
    op.drop_constraint('uq_feedback_client_task', 'feedback', type_='unique')
    
    # Make ValidationRequest.agent_validator_id non-nullable again
    op.alter_column('validation_requests', 'agent_validator_id',
                    existing_type=sa.INTEGER(),
                    nullable=False)
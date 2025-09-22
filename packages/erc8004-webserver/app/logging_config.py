import structlog
import logging
import sys
from typing import Any, Dict
from datetime import datetime
from .config import settings


def setup_logging():
    """Setup structured logging configuration"""
    
    # Configure standard library logging
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=getattr(logging, settings.log_level.upper())
    )
    
    # Processors for structured logging
    processors = [
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
    ]
    
    # Add request context processor
    processors.append(add_request_context)
    
    # Add JSON renderer for production, plain for development
    if settings.environment == "production":
        processors.append(structlog.processors.JSONRenderer())
    else:
        processors.append(structlog.dev.ConsoleRenderer(colors=True))
    
    # Configure structlog
    structlog.configure(
        processors=processors,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )


def add_request_context(logger, method_name: str, event_dict: Dict[str, Any]) -> Dict[str, Any]:
    """Add request context to log entries"""
    
    # Add timestamp if not present
    if 'timestamp' not in event_dict:
        event_dict['timestamp'] = datetime.utcnow().isoformat()
    
    # Add service information
    event_dict['service'] = 'erc8004-webserver'
    event_dict['version'] = '1.0.0'
    event_dict['environment'] = settings.environment
    
    return event_dict


def get_logger(name: str = None):
    """Get a structured logger instance"""
    return structlog.get_logger(name or __name__)


# Security event logger
def log_security_event(
    event_type: str,
    details: Dict[str, Any],
    severity: str = "INFO",
    client_ip: str = None,
    agent_address: str = None
):
    """Log security-related events with special handling"""
    
    logger = get_logger("security")
    
    security_context = {
        "security_event": True,
        "event_type": event_type,
        "severity": severity,
        "timestamp": datetime.utcnow().isoformat(),
        **details
    }
    
    if client_ip:
        security_context["client_ip"] = client_ip
    
    if agent_address:
        security_context["agent_address"] = agent_address
    
    # Log at appropriate level
    log_method = getattr(logger, severity.lower(), logger.info)
    log_method("Security event", **security_context)


# Performance logger
def log_performance_event(
    operation: str,
    duration: float,
    details: Dict[str, Any] = None,
    threshold: float = 1.0
):
    """Log performance events, especially slow operations"""
    
    logger = get_logger("performance")
    
    performance_context = {
        "performance_event": True,
        "operation": operation,
        "duration_seconds": duration,
        "timestamp": datetime.utcnow().isoformat(),
        "slow_operation": duration > threshold
    }
    
    if details:
        performance_context.update(details)
    
    # Log as warning if operation is slow
    if duration > threshold:
        logger.warning("Slow operation detected", **performance_context)
    else:
        logger.debug("Performance metric", **performance_context)


# Business logic logger  
def log_business_event(
    event_type: str,
    entity_type: str,
    entity_id: str,
    action: str,
    details: Dict[str, Any] = None,
    agent_address: str = None
):
    """Log business events for audit trail"""
    
    logger = get_logger("business")
    
    business_context = {
        "business_event": True,
        "event_type": event_type,
        "entity_type": entity_type,
        "entity_id": entity_id,
        "action": action,
        "timestamp": datetime.utcnow().isoformat()
    }
    
    if details:
        business_context.update(details)
    
    if agent_address:
        business_context["agent_address"] = agent_address
    
    logger.info("Business event", **business_context)


# Error logger with context
def log_error_with_context(
    error: Exception,
    context: Dict[str, Any],
    operation: str = None,
    request_id: str = None
):
    """Log errors with full context for debugging"""
    
    logger = get_logger("error")
    
    error_context = {
        "error_event": True,
        "error_type": type(error).__name__,
        "error_message": str(error),
        "timestamp": datetime.utcnow().isoformat(),
        **context
    }
    
    if operation:
        error_context["operation"] = operation
    
    if request_id:
        error_context["request_id"] = request_id
    
    logger.error("Application error", **error_context, exc_info=True)
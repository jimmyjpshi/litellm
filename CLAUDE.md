# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Installation
- `make install-dev` - Install core development dependencies
- `make install-proxy-dev` - Install proxy development dependencies with full feature set
- `make install-dev-ci` - Install dev dependencies (CI-compatible, pins OpenAI)
- `make install-proxy-dev-ci` - Install proxy dev dependencies (CI-compatible)
- `make install-test-deps` - Install all test dependencies (includes enterprise package)
- `make install-helm-unittest` - Install helm unittest plugin

### Testing
- `make test` - Run all tests
- `make test-unit` - Run unit tests (tests/test_litellm) with 4 parallel workers
- `make test-integration` - Run integration tests (excludes unit tests)
- `make test-unit-helm` - Run helm unit tests
- `make test-llm-translation` - Run LLM translation tests (automated)
- `make test-llm-translation-single FILE=test_filename.py` - Run single LLM translation test file
- `pytest tests/` - Direct pytest execution
- `poetry run pytest tests/path/to/test_file.py -v` - Run specific test file
- `poetry run pytest tests/path/to/test_file.py::test_function -v` - Run specific test

### Code Quality
- `make lint` - Run all linting (Ruff, MyPy, Black check, circular imports, import safety)
- `make format` - Apply Black code formatting
- `make format-check` - Check Black code formatting (matches CI)
- `make lint-ruff` - Run Ruff linting only
- `make lint-mypy` - Run MyPy type checking only
- `make lint-black` - Check Black formatting (matches CI)
- `make check-circular-imports` - Check for circular imports
- `make check-import-safety` - Check import safety

## Architecture Overview

LiteLLM is a unified interface for 100+ LLM providers with two main components:

### Core Library (`litellm/`)
- **Main entry point**: `litellm/main.py` - Contains core completion() function
- **Provider implementations**: `litellm/llms/` - Each provider has its own subdirectory with handler/transformation pattern
- **Router system**: `litellm/router.py` + `litellm/router_utils/` + `litellm/router_strategy/` - Load balancing, fallback logic, and routing strategies
- **Type definitions**: `litellm/types/` - Pydantic models and type hints organized by functionality
- **Core utilities**: `litellm/litellm_core_utils/` - Shared utilities for logging, streaming, token counting, etc.
- **Integrations**: `litellm/integrations/` - Third-party observability, caching, logging (Langfuse, DataDog, etc.)
- **Caching**: `litellm/caching/` - Multiple cache backends (Redis, in-memory, S3, disk, dual cache, semantic caching)
- **Secret managers**: `litellm/secret_managers/` - AWS, Google, HashiCorp Vault, Azure integrations

### Proxy Server (`litellm/proxy/`)
- **Main server**: `proxy_server.py` - FastAPI application with comprehensive API routes
- **Authentication**: `auth/` - API key management, JWT, OAuth2, organization checks, model access controls
- **Database**: `db/` - Prisma ORM with PostgreSQL/SQLite support, spend tracking, audit logs
- **Management endpoints**: `management_endpoints/` - Admin APIs for keys, teams, models, budgets, organizations
- **Pass-through endpoints**: `pass_through_endpoints/` - Provider-specific API forwarding with streaming support
- **Guardrails**: `guardrails/` - Safety and content filtering hooks with registry system
- **Common utilities**: `common_utils/` - Shared proxy utilities for config loading, encryption, OpenAPI specs
- **Hooks**: `hooks/` - Event-driven hooks for rate limiting, budget enforcement, content safety

### Provider Architecture Pattern
Each provider in `litellm/llms/` follows a consistent structure:
- **`common_utils.py`** - Provider-specific utilities and configurations
- **`chat/transformation.py`** - Input/output transformation for chat completions
- **`chat/handler.py`** - HTTP request handling and API calls
- **`completion/`** - Text completion endpoint support
- **`embedding/`** - Embedding endpoint support
- **`cost_calculation.py`** - Provider-specific pricing calculations
- **`[feature]/transformation.py`** - Feature-specific transformations (images, audio, etc.)

## Key Development Patterns

### Transformation Pattern
- All providers use transformation functions to convert between OpenAI format and provider-specific formats
- Input transformation: `litellm_params` → provider format
- Output transformation: provider response → OpenAI format
- Streaming responses handled separately with iterator patterns

### Error Handling Strategy
- Provider-specific exceptions mapped to OpenAI-compatible errors in `litellm/exceptions.py`
- Fallback logic handled by Router system with cooldown mechanisms
- Comprehensive logging through `litellm/_logging.py` and callback managers
- Custom error mapping per provider in `exception_mapping_utils.py`

### Async/Sync Patterns
- All core functions support both sync and async operations
- Async clients managed through `litellm/custom_httpx/` with connection pooling
- Router system handles async request distribution and load balancing
- Streaming responses use async generators for efficiency

### Configuration Management
- YAML config files for proxy server (see `litellm/proxy/example_config_yaml/`)
- Environment variables for API keys and settings
- Database schema managed via Prisma (`litellm/proxy/schema.prisma`)
- Dynamic model loading and configuration updates
- Multi-instance configuration support

## Development Guidelines

### Adding New Providers
1. Create provider directory in `litellm/llms/[provider_name]/`
2. Implement `chat/transformation.py` with input/output transformations
3. Add `chat/handler.py` for HTTP request handling
4. Create `common_utils.py` for provider-specific utilities
5. Add cost calculations in `cost_calculation.py`
6. Update `litellm/model_prices_and_context_window.json`
7. Add comprehensive tests in `tests/llm_translation/`

### Testing Best Practices
- Unit tests in `tests/test_litellm/` for core functionality
- Integration tests in `tests/llm_translation/` for each provider
- Proxy tests in `tests/proxy_unit_tests/` for server functionality
- Load tests in `tests/load_tests/` for performance validation
- Use pytest markers for test categorization (slow, integration)
- Mock external API calls in unit tests

### Code Quality Standards
- Black formatter with 120-character line length
- Ruff linting with specific ignores in `ruff.toml`
- MyPy type checking with strict mode
- Pydantic v2 for all data models
- Type hints required for all public APIs
- Async/await patterns for I/O operations

### Database Operations
- Prisma ORM for all database interactions
- Schema defined in `litellm/proxy/schema.prisma`
- Migrations auto-generated with `prisma migrate dev`
- Support both PostgreSQL and SQLite
- Spend tracking and audit logging built-in
- Connection pooling and optimization

### Enterprise Integration
- Enterprise-specific code in `enterprise/` directory
- Feature flags controlled via environment variables
- Separate licensing and authentication flows
- Optional enterprise dependencies
- Backwards compatibility maintained
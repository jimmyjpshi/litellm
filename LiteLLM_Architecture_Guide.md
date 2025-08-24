# LiteLLM Architecture & Provider Integration Guide

## Overview

LiteLLM provides a unified interface to 100+ LLM providers through a consistent OpenAI-compatible API. This guide outlines the core architecture patterns, design principles, and execution flow for understanding and extending the provider ecosystem.

**Design Principles:**
- Clean, clear, concise documentation with hierarchical structure  
- Essential information without repetition
- References to official documentation and provider APIs
- Facilitates seamless integration of additional providers

**Official Documentation:** [docs.litellm.ai](https://docs.litellm.ai)

## 1. Core Architecture

### 1.1 High-Level Components

```
┌─────────────────────────────────────────────────────────┐
│                    User Interface                       │
├─────────────────────────────────────────────────────────┤
│  litellm.completion() - Unified Entry Point            │
├─────────────────────────────────────────────────────────┤
│  Router System - Load Balancing & Fallback Logic       │
├─────────────────────────────────────────────────────────┤
│  Provider Layer - Individual LLM Integrations          │
├─────────────────────────────────────────────────────────┤
│  HTTP Layer - Custom HTTP Handlers & Connection Pool   │
└─────────────────────────────────────────────────────────┘
```

### 1.2 Core Library Structure (`litellm/`)

- **`main.py`** - Primary entry point with `completion()` function
- **`llms/`** - Provider-specific implementations 
- **`router.py`** - Load balancing and routing logic
- **`types/`** - Type definitions and data models
- **`litellm_core_utils/`** - Shared utilities and helpers
- **`integrations/`** - Third-party observability and logging
- **`caching/`** - Multi-backend caching system

## 2. Request Execution Flow

### 2.1 Main Entry Point to Provider Response

```
User Request → litellm.completion() → Provider Handler → API Response → OpenAI Format
     ↓              ↓                    ↓              ↓             ↓
┌─────────────┬─────────────┬──────────────────┬─────────────┬─────────────┐
│   Input     │   Route     │    Transform     │   HTTP      │   Output    │
│ Validation  │ Detection   │   & Execute      │  Response   │ Transform   │
└─────────────┴─────────────┴──────────────────┴─────────────┴─────────────┘
```

#### Step 1: Entry Point (`litellm/main.py:874`)
```python
def completion(model: str, messages: List, **kwargs) -> ModelResponse:
    # 1. Parameter validation and preprocessing
    # 2. Provider detection via get_llm_provider()
    # 3. Route to provider-specific handler
```

#### Step 2: Provider Detection (`litellm/utils.py`)
```python
model, custom_llm_provider, dynamic_api_key, api_base = get_llm_provider(
    model=model,
    custom_llm_provider=custom_llm_provider,
    api_base=api_base,
    api_key=api_key,
)
# Example: model="claude-3-sonnet" → custom_llm_provider="anthropic"
```

#### Step 3: Provider Routing (`litellm/main.py:2191`)
```python
elif custom_llm_provider == "anthropic":
    # Set provider-specific configurations
    api_key = api_key or os.environ.get("ANTHROPIC_API_KEY")
    api_base = api_base or "https://api.anthropic.com/v1/messages"
    
    # Call provider handler
    response = anthropic.completion(
        model=model, messages=messages, api_key=api_key, 
        api_base=api_base, **optional_params
    )
```

#### Step 4: Provider Handler (`litellm/llms/anthropic/chat/handler.py`)
```python
def completion(...) -> Union[ModelResponse, CustomStreamWrapper]:
    # 1. Transform OpenAI format → Anthropic format
    data = transform_request(model, messages, optional_params, litellm_params)
    
    # 2. Make HTTP request to provider API
    response = httpx.post(api_base, json=data, headers=headers)
    
    # 3. Transform Anthropic format → OpenAI format  
    return transform_response(response, model_response, logging_obj, ...)
```

#### Step 5: Response Transformation (`litellm/llms/anthropic/chat/transformation.py`)
```python
def transform_response(...) -> ModelResponse:
    # Convert provider response to OpenAI-compatible format
    model_response.choices[0].message.content = response.content
    model_response.usage = calculate_usage(response.usage)
    return model_response
```

## 3. Provider Architecture Pattern

### 2.1 Standard Provider Structure

Each provider follows a consistent directory structure under `litellm/llms/[provider_name]/`:

```
provider_name/
├── common_utils.py           # Provider-specific utilities
├── cost_calculation.py       # Pricing calculations
├── chat/
│   ├── transformation.py     # I/O format transformations
│   └── handler.py           # HTTP request handling
├── completion/              # Text completion support
├── embedding/               # Embedding endpoint support
└── [feature]/               # Additional features (images, audio, etc.)
    ├── transformation.py
    └── handler.py
```

### 2.2 Key Design Patterns

#### Transformation Pattern
**Purpose:** Convert between OpenAI format and provider-specific formats

```python
# Input transformation: OpenAI → Provider format  
def transform_request(litellm_params: dict) -> dict:
    """Convert LiteLLM parameters to provider-specific format"""
    
# Output transformation: Provider → OpenAI format
def transform_response(response: dict) -> ModelResponse:
    """Convert provider response to OpenAI-compatible format"""
```

#### Handler Pattern
**Purpose:** Manage HTTP requests and provider-specific API calls

```python
def chat_completion_handler(
    model: str,
    messages: list,
    api_key: str,
    **kwargs
) -> Union[ModelResponse, CustomStreamWrapper]:
    """Handle chat completion requests for specific provider"""
```

## 3. Core Integration Points

### 3.1 Main Entry Point (`litellm/main.py:874`)

The `completion()` function serves as the unified entry point:
- Model routing and provider detection
- Parameter validation and transformation
- Error handling and fallback logic
- Response formatting and streaming

### 3.2 Provider Detection

Provider selection is based on:
1. **Model name prefixes** (e.g., `claude-*` → Anthropic)
2. **Explicit provider parameter** 
3. **API base URL patterns**
4. **Custom model mappings**

### 3.3 Error Handling Strategy

```python
# Provider-specific exceptions mapped to OpenAI-compatible errors
class AnthropicError(BaseLLMException):
    def __init__(self, status_code: int, message, headers=None):
        super().__init__(status_code=status_code, message=message, headers=headers)
```

## 4. Adding a New Provider

### 4.1 Implementation Checklist

1. **Create provider directory structure**
2. **Implement transformation functions**
3. **Add HTTP handler logic**
4. **Define provider-specific utilities**
5. **Add cost calculations**
6. **Update model registry**
7. **Write comprehensive tests**

### 4.2 Required Components

#### A. Common Utils (`common_utils.py`)
```python
class ProviderError(BaseLLMException):
    """Provider-specific error handling"""

class ProviderModelInfo(BaseLLMModelInfo):
    """Model information and capabilities"""

def validate_environment(api_key: str) -> dict:
    """Validate required environment variables"""
```

#### B. Chat Transformation (`chat/transformation.py`)
```python
def transform_request(
    model: str,
    messages: List[Dict],
    optional_params: Dict,
    litellm_params: Dict,
    headers: Dict,
) -> Dict:
    """Transform OpenAI format to provider format"""

def transform_response(
    model: str,
    raw_response: httpx.Response,
    model_response: ModelResponse,
    logging_obj: Any,
    request_data: Dict,
    messages: List[Dict],
    optional_params: Dict,
    litellm_params: Dict,
    encoding: str,
    api_key: str,
    json_mode: Optional[bool] = None,
) -> ModelResponse:
    """Transform provider response to OpenAI format"""
```

#### C. Chat Handler (`chat/handler.py`)
```python
def completion(
    model: str,
    messages: list,
    api_base: str,
    model_response: ModelResponse,
    print_verbose: Callable,
    encoding: str,
    api_key: str,
    logging_obj: Any,
    custom_prompt_dict: dict,
    acompletion: bool = False,
    litellm_params: Optional[dict] = None,
    logger_fn: Optional[Callable] = None,
    headers: Optional[dict] = None,
    timeout: Optional[Union[float, httpx.Timeout]] = None,
    client=None,
) -> Union[ModelResponse, CustomStreamWrapper]:
    """Main completion handler for provider"""
```

### 4.3 Configuration Updates

#### Model Registry (`litellm/model_prices_and_context_window.json`)
```json
{
  "provider-model-name": {
    "max_tokens": 4096,
    "max_input_tokens": 200000,
    "max_output_tokens": 4096,
    "input_cost_per_token": 0.00001,
    "output_cost_per_token": 0.00003,
    "litellm_provider": "provider_name",
    "mode": "chat"
  }
}
```

#### Constants (`litellm/constants.py`)
```python
PROVIDER_CHAT_PROVIDERS = ["provider_name"]
```

## 5. Key Implementation Considerations

### 5.1 HTTP Client Management

- Use `litellm/custom_httpx/` for HTTP handling
- Implement connection pooling for efficiency
- Support both sync and async operations
- Handle provider-specific timeout and retry logic

### 5.2 Streaming Support

```python
def handle_streaming_response(response: httpx.Response) -> Iterator[str]:
    """Handle server-sent events for streaming responses"""
    for line in response.iter_lines():
        if line.startswith("data: "):
            yield line[6:]  # Remove "data: " prefix
```

### 5.3 Authentication Patterns

Support multiple authentication methods:
- API keys in headers
- Bearer tokens
- Custom authentication schemes
- Environment variable resolution

### 5.4 Cost Calculation

Implement accurate token counting and cost calculation:
```python
def cost_calculation(
    model: str,
    usage: Dict,
    custom_pricing: Optional[Dict] = None,
) -> float:
    """Calculate request cost based on token usage"""
```

## 6. Testing Strategy

### 6.1 Test Structure
- **Unit tests:** `tests/test_litellm/test_[provider].py`
- **Integration tests:** `tests/llm_translation/test_[provider].py` 
- **Load tests:** `tests/load_tests/`

### 6.2 Test Categories
```python
# Basic functionality
def test_completion()
def test_streaming() 
def test_async_completion()

# Error handling
def test_invalid_api_key()
def test_rate_limiting()
def test_timeout_handling()

# Advanced features  
def test_tool_calling()
def test_image_inputs()
def test_function_calling()
```

## 7. Best Practices

### 7.1 Code Quality
- Follow Black formatting (120 character limit)
- Use Ruff linting with project configuration
- Implement comprehensive type hints
- Use Pydantic v2 for data validation

### 7.2 Error Handling
- Map provider errors to OpenAI-compatible exceptions
- Implement proper retry logic with backoff
- Log errors appropriately for debugging

### 7.3 Performance
- Minimize memory allocations in hot paths
- Use async/await for I/O operations
- Implement efficient token counting
- Cache expensive operations when possible

## 8. Reference Documentation

### 8.1 LiteLLM Resources
- **Main Documentation:** [docs.litellm.ai](https://docs.litellm.ai)
- **Provider Docs:** [docs.litellm.ai/docs/providers](https://docs.litellm.ai/docs/providers)
- **API Reference:** [docs.litellm.ai/docs/completion](https://docs.litellm.ai/docs/completion)
- **GitHub Issues:** [github.com/BerriAI/litellm/issues](https://github.com/BerriAI/litellm/issues)

### 8.2 Provider API Documentation
When adding a new provider, reference their official API documentation:

- **OpenAI:** [platform.openai.com/docs/api-reference](https://platform.openai.com/docs/api-reference)
- **Anthropic:** [docs.anthropic.com/api](https://docs.anthropic.com/api)
- **Google Gemini:** [ai.google.dev/api](https://ai.google.dev/api)
- **Cohere:** [docs.cohere.com/reference](https://docs.cohere.com/reference)

### 8.3 Development Commands
```bash
# Setup
make install-dev

# Testing  
make test                    # All tests
make test-unit              # Unit tests only
pytest tests/llm_translation/test_[provider].py -v

# Code Quality
make lint                   # All linting
make format                 # Apply formatting
```

## 9. Future Enhancement: LLM-Powered Adaptive Transformations

**Current Limitation**: All providers use static pattern matching for transformations, lacking adaptability when APIs evolve.

**Proposed Solution**: Hybrid approach with LLM-assisted transformation for complex cases.

**Benefits:**
- Adaptive to API changes without manual updates
- Semantic understanding vs. simple field mapping
- Easier integration of unique provider paradigms

**Implementation:**
```python
def adaptive_transform(openai_request, provider):
    if is_standard_case(openai_request):
        return pattern_match_transform(openai_request, provider)
    return llm_assisted_transform(openai_request, provider)

def llm_assisted_transform(openai_request, provider_config):
    transformation_prompt = f"""
    Convert this OpenAI API request to {provider_config.name} format:
    Request: {json.dumps(openai_request)}
    Provider API Schema: {provider_config.schema}
    Previous Examples: {get_cached_examples(provider_config.name)}
    
    Return the transformed request in JSON format.
    """
    
    # Use lightweight, fast model for transformation
    response = litellm.completion(
        model="gpt-4o-mini",  
        messages=[{"role": "user", "content": transformation_prompt}],
        response_format={"type": "json_object"}
    )
    
    transformed_request = json.loads(response.choices[0].message.content)
    cache_transformation(openai_request, transformed_request, provider_config)
    return transformed_request
```

**Optimizations:** Aggressive caching, fallback to pattern matching, cost budgeting.

---

This architecture guide provides the foundation for understanding and extending LiteLLM's provider ecosystem. Follow these patterns to ensure consistent, maintainable, and high-quality integrations.
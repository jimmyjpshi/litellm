#!/bin/bash
# LiteLLM Development Startup Script

# Add Python user bin to PATH
export PATH="$HOME/Library/Python/3.13/bin:$PATH"

# Set current directory as PYTHONPATH for development
export PYTHONPATH="/Users/jimmy/code/litellm:$PYTHONPATH"

echo "🚀 Starting LiteLLM from local development directory..."
echo "📁 Working directory: $(pwd)"
echo "🐍 Using Python: $(which python)"
echo "📦 LiteLLM version: $(litellm --version)"

# Start LiteLLM with provided arguments or default
if [ $# -eq 0 ]; then
    echo "📋 Starting with default model (gpt-3.5-turbo) on port 8080"
#    litellm --model openai/gpt-3.5-turbo --port 8080
   litellm --config ../mcp-server-new/litellm_real.yaml --port 8000 -host localhost
else
    echo "📋 Starting with provided arguments: $@"
    litellm "$@"
fi

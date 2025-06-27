# Configuration Guide

## Ollama Configuration

The Ollama URL and port are now configurable through environment variables. This allows you to easily point the application to different Ollama instances without modifying code.

### Environment Variables

Configure your Ollama settings in the `.env` file:

```bash
# Ollama Configuration
OLLAMA_HOST=localhost
OLLAMA_PORT=11434
OLLAMA_BASE_URL=http://localhost:11434

# Default Ollama Model (optional)
OLLAMA_DEFAULT_MODEL=llama2

# Flask Configuration
FLASK_ENV=development
PORT=5000
```

### Configuration Options

- **OLLAMA_HOST**: The hostname where Ollama is running (default: `localhost`)
- **OLLAMA_PORT**: The port where Ollama is running (default: `11434`)
- **OLLAMA_BASE_URL**: Full URL to Ollama API (default: constructed from host and port)
- **OLLAMA_DEFAULT_MODEL**: Default model to use if none specified (default: `llama2`) - Will be auto-selected in the frontend dropdown

### How It Works

1. **Backend Configuration**: The Python backend reads configuration from environment variables
2. **Frontend Defaults**: The frontend loads these values from the backend and uses them as defaults
3. **Runtime Override**: Users can still override the URL in the frontend form if needed

### Examples

#### Local Ollama Instance
```bash
OLLAMA_HOST=localhost
OLLAMA_PORT=11434
OLLAMA_BASE_URL=http://localhost:11434
```

#### Remote Ollama Instance
```bash
OLLAMA_HOST=192.168.1.100
OLLAMA_PORT=11434
OLLAMA_BASE_URL=http://192.168.1.100:11434
```

#### Custom Port
```bash
OLLAMA_HOST=localhost
OLLAMA_PORT=8080
OLLAMA_BASE_URL=http://localhost:8080
```

### Configuration Endpoint

The backend now provides a `/api/config` endpoint that returns current configuration:

```json
{
  "ollama": {
    "url": "http://localhost:11434",
    "host": "localhost", 
    "port": "11434",
    "default_model": "llama2"
  }
}
```

### Migration from Hardcoded Values

Previously, the frontend had a hardcoded URL (`http://192.168.1.148:11434`). Now:

1. The frontend loads the URL from backend configuration
2. Environment variables provide the default values
3. Users can still override the URL in the UI if needed
4. No code changes required to point to different Ollama instances

### Restart Required

After changing environment variables in `.env`, restart the application for changes to take effect:

```bash
python app.py
```

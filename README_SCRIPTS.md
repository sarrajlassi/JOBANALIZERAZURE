# Job Analyzer - Batch Scripts Guide

## Available Scripts

This project includes several batch scripts to make setup and running easier on Windows:

### 1. `install_and_run.bat` (Recommended for first-time setup)
**What it does:**
- Checks if Python is installed
- Creates a virtual environment (if not exists)
- Installs all dependencies from requirements.txt
- Starts the Flask server
- Shows helpful error messages and warnings

**When to use:** First time running the application or when you want to ensure everything is properly set up.

### 2. `run.bat` (Quick start)
**What it does:**
- Activates virtual environment (if exists)
- Starts the Flask server immediately
- Minimal setup checks

**When to use:** When dependencies are already installed and you just want to start the server quickly.

### 3. `install.bat` (Dependencies only)
**What it does:**
- Creates virtual environment
- Installs dependencies only
- Does NOT start the server

**When to use:** When you want to install dependencies but start the server manually later.

## Quick Start Guide

### Option 1: Complete Setup and Run (Recommended)
```cmd
# Double-click or run from command prompt:
install_and_run.bat
```

### Option 2: Manual Steps
```cmd
# Step 1: Install dependencies
install.bat

# Step 2: Start server
run.bat
```

## Configuration

### Environment Variables (.env file)
The scripts will warn you if the `.env` file is missing. Create one with your API configurations:

```env
# Ollama Configuration
OLLAMA_HOST=localhost
OLLAMA_PORT=11434
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_DEFAULT_MODEL=llama2

# OpenAI Configuration
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_DEFAULT_MODEL=gpt-4o-mini

# DeepSeek Configuration
DEEPSEEK_API_KEY=your_deepseek_api_key_here
DEEPSEEK_DEFAULT_MODEL=deepseek-chat
```

## Prerequisites

- **Python 3.7+** must be installed and added to PATH
- **pip** should be available (usually comes with Python)
- **Internet connection** for downloading dependencies

## Troubleshooting

### Common Issues:

1. **"Python is not recognized"**
   - Install Python from https://python.org
   - Make sure to check "Add Python to PATH" during installation

2. **"Failed to create virtual environment"**
   - Run Command Prompt as Administrator
   - Check if you have write permissions in the project directory

3. **"Failed to install dependencies"**
   - Check your internet connection
   - Try running: `pip install --upgrade pip` first

4. **"Server failed to start"**
   - Check if port 5000 is already in use
   - Verify your .env file configuration
   - Look for error messages in the console

### Manual Virtual Environment Commands:
```cmd
# Create virtual environment
python -m venv venv

# Activate (Windows)
venv\Scripts\activate.bat

# Install dependencies
pip install -r requirements.txt

# Run application
python app.py
```

## Access the Application

Once the server starts successfully, open your web browser and go to:
- **http://localhost:5000** or **http://127.0.0.1:5000**

## Stopping the Server

- Press **Ctrl+C** in the command prompt window to stop the server
- Close the command prompt window

## Features

- **Ollama Integration**: Use local AI models
- **OpenAI Integration**: Use OpenAI's GPT models  
- **DeepSeek Integration**: Use DeepSeek's models
- **Multiple Input Types**: Text, URL, or PDF file upload
- **JSON Syntax Highlighting**: Beautiful formatted output
- **Copy to Clipboard**: Easy copying of results

## Support

If you encounter issues:
1. Check the error messages in the console
2. Verify your .env configuration
3. Ensure all dependencies are installed
4. Check if required services (like Ollama) are running

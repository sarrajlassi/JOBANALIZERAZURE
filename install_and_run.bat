@echo off
echo =============================================
echo   Job Analyzer - Setup and Launch Script
echo =============================================
echo.

:: Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.7+ from https://python.org
    pause
    exit /b 1
)

echo Python version:
python --version
echo.

:: Check if pip is installed
pip --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: pip is not installed or not in PATH
    pause
    exit /b 1
)

echo Pip version:
pip --version
echo.

:: Create virtual environment if it doesn't exist
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
    if %errorlevel% neq 0 (
        echo ERROR: Failed to create virtual environment
        pause
        exit /b 1
    )
    echo Virtual environment created successfully!
    echo.
) else (
    echo Virtual environment already exists.
    echo.
)

:: Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat
if %errorlevel% neq 0 (
    echo ERROR: Failed to activate virtual environment
    pause
    exit /b 1
)

echo Virtual environment activated!
echo.

:: Upgrade pip
echo Upgrading pip...
python -m pip install --upgrade pip
echo.

:: Install dependencies
echo Installing dependencies from requirements.txt...
pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)

echo.
echo =============================================
echo   All dependencies installed successfully!
echo =============================================
echo.

:: Check if .env file exists
if not exist ".env" (
    echo WARNING: .env file not found!
    echo Please create a .env file with your API configurations.
    echo Example .env content:
    echo.
    echo # Ollama Configuration
    echo OLLAMA_HOST=localhost
    echo OLLAMA_PORT=11434
    echo OLLAMA_BASE_URL=http://localhost:11434
    echo OLLAMA_DEFAULT_MODEL=llama2
    echo.
    echo # OpenAI Configuration
    echo OPENAI_API_KEY=your_openai_api_key_here
    echo OPENAI_DEFAULT_MODEL=gpt-4o-mini
    echo.
    echo # DeepSeek Configuration
    echo DEEPSEEK_API_KEY=your_deepseek_api_key_here
    echo DEEPSEEK_DEFAULT_MODEL=deepseek-chat
    echo.
    echo Press any key to continue without .env file or Ctrl+C to exit and create .env file...
    pause >nul
    echo.
)

:: Start the Flask application
echo Starting Flask application...
echo.
echo =============================================
echo   Server is starting on http://localhost:5000
echo   Press Ctrl+C to stop the server
echo =============================================
echo.

python app.py

:: Pause before closing if there was an error
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Server failed to start
    pause
)

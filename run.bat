@echo off
echo =============================================
echo   Job Analyzer - Quick Start
echo =============================================
echo.

:: Activate virtual environment if it exists
if exist "venv" (
    echo Activating virtual environment...
    call venv\Scripts\activate.bat
    echo.
)

:: Check if .env file exists
if not exist ".env" (
    echo WARNING: .env file not found!
    echo The application may not work properly without API configurations.
    echo.
)

:: Start the Flask application
echo Starting Flask application...
echo.
echo =============================================
echo   Server running on http://localhost:5000
echo   Press Ctrl+C to stop the server
echo =============================================
echo.

python app.py

:: Pause before closing if there was an error
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Server failed to start
    echo Try running install_and_run.bat first to install dependencies
    pause
)

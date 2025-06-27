from flask import Flask, request, jsonify, render_template, send_from_directory
from flask_cors import CORS
import requests
import json
import os
from dotenv import load_dotenv
import PyPDF2
from io import BytesIO
import base64
from bs4 import BeautifulSoup
import openai
import traceback

# Load environment variables
load_dotenv()

app = Flask(__name__, 
           template_folder='templates',
           static_folder='static')
CORS(app)

# Configuration
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# Ollama Configuration from environment variables
OLLAMA_HOST = os.getenv('OLLAMA_HOST', 'localhost')
OLLAMA_PORT = os.getenv('OLLAMA_PORT', '11434')
OLLAMA_BASE_URL = os.getenv('OLLAMA_BASE_URL', f'http://{OLLAMA_HOST}:{OLLAMA_PORT}')
DEFAULT_OLLAMA_MODEL = os.getenv('OLLAMA_DEFAULT_MODEL', 'llama2')

# OpenAI Configuration from environment variables
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
DEFAULT_OPENAI_MODEL = os.getenv('OPENAI_DEFAULT_MODEL', 'gpt-4o-mini')

# DeepSeek Configuration from environment variables
DEEPSEEK_API_KEY = os.getenv('DEEPSEEK_API_KEY')
DEFAULT_DEEPSEEK_MODEL = os.getenv('DEEPSEEK_DEFAULT_MODEL', 'deepseek-chat')

class AIProvider:
    @staticmethod
    def get_system_prompt():
        return """You are a job posting analyzer. Extract key information from the following job posting and return it as a valid JSON object with these fields:

{
  "jobTitle": "string",
  "company": "string",
  "location": "string",
  "workType": "string (remote/hybrid/onsite)",
  "employmentType": "string (full-time/part-time/contract)",
  "contractType": "string (ex: 'A durée indéterminée', 'Intérimaire', 'A durée déterminée', 'Contrat de remplacement', 'Autonome', 'Apprentissage', etc. ou null si non mentionné)",
  "salaryRange": {
    "min": "number or null",
    "max": "number or null",
    "currency": "string"
  },
  "experience": {
    "yearsRequired": "number or null",
    "level": "string (entry/mid/senior/executive)"
  },
  "skills": ["array of required skills"],
  "qualifications": ["array of required qualifications"],
  "driverLicense": "string (Code Permis de conduire / Libellé permis, ou null si non mentionné)",
  "educationLevel": "string ( null si non mentionné)", 
  "benefits": ["array of benefits mentioned"],
  "department": "string",
  "industry": "string",
  "description": "string (brief summary)"
}

Return only the JSON object, no additional text or formatting."""

class OllamaProvider(AIProvider):
    @staticmethod
    def call_api(url, model, job_content):
        try:
            prompt = f"{AIProvider.get_system_prompt()}\n\nJob Posting:\n{job_content}"
            
            response = requests.post(
                f"{url}/api/generate",
                json={
                    "model": model,
                    "prompt": prompt,
                    "stream": False,
                    "options": {
                        "temperature": 0.1,
                        "top_p": 0.9
                    }
                },
                timeout=120
            )
            
            if response.status_code != 200:
                raise Exception(f"Ollama API error: {response.status_code}")
                
            data = response.json()
            return data.get('response', '')
            
        except requests.exceptions.Timeout:
            raise Exception("Ollama request timed out")
        except requests.exceptions.ConnectionError:
            raise Exception("Cannot connect to Ollama server")
        except Exception as e:
            raise Exception(f"Ollama error: {str(e)}")

    @staticmethod
    def get_models(url):
        try:
            response = requests.get(f"{url}/api/tags", timeout=10)
            if response.status_code != 200:
                raise Exception(f"Failed to fetch models: {response.status_code}")
            
            data = response.json()
            models = []
            for model in data.get('models', []):
                models.append({
                    'name': model['name'],
                    'size': model.get('size', 0),
                    'modified_at': model.get('modified_at', '')
                })
            
            return models
        except Exception as e:
            raise Exception(f"Error fetching Ollama models: {str(e)}")

class OpenAIProvider(AIProvider):
    @staticmethod
    def call_api(api_key, model, job_content):
        try:
            client = openai.OpenAI(api_key=api_key)
            
            response = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": AIProvider.get_system_prompt()},
                    {"role": "user", "content": f"Job Posting:\n{job_content}"}
                ],
                temperature=0.1,
                max_tokens=2000
            )
            
            return response.choices[0].message.content
            
        except openai.AuthenticationError:
            raise Exception("Invalid OpenAI API key")
        except openai.RateLimitError:
            raise Exception("OpenAI rate limit exceeded")
        except openai.APIError as e:
            raise Exception(f"OpenAI API error: {str(e)}")
        except Exception as e:
            raise Exception(f"OpenAI error: {str(e)}")

class DeepSeekProvider(AIProvider):
    @staticmethod
    def call_api(api_key, model, job_content):
        try:
            headers = {
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {api_key}'
            }
            
            data = {
                'model': model,
                'messages': [
                    {"role": "system", "content": AIProvider.get_system_prompt()},
                    {"role": "user", "content": f"Job Posting:\n{job_content}"}
                ],
                'temperature': 0.1,
                'max_tokens': 2000
            }
            
            response = requests.post(
                'https://api.deepseek.com/v1/chat/completions',
                headers=headers,
                json=data,
                timeout=60
            )
            
            if response.status_code == 401:
                raise Exception("Invalid DeepSeek API key")
            elif response.status_code == 429:
                raise Exception("DeepSeek rate limit exceeded")
            elif response.status_code != 200:
                error_data = response.json() if response.content else {}
                error_msg = error_data.get('error', {}).get('message', f'HTTP {response.status_code}')
                raise Exception(f"DeepSeek API error: {error_msg}")
            
            data = response.json()
            return data['choices'][0]['message']['content']
            
        except requests.exceptions.Timeout:
            raise Exception("DeepSeek request timed out")
        except Exception as e:
            if "DeepSeek" in str(e):
                raise e
            raise Exception(f"DeepSeek error: {str(e)}")

def extract_text_from_pdf(file_data):
    """Extract text from PDF file data"""
    try:
        pdf_file = BytesIO(file_data)
        pdf_reader = PyPDF2.PdfReader(pdf_file)
        
        text = ""
        for page in pdf_reader.pages:
            text += page.extract_text() + "\n"
        
        if not text.strip():
            raise Exception("No text could be extracted from the PDF")
            
        return text.strip()
    except Exception as e:
        raise Exception(f"PDF extraction error: {str(e)}")

def extract_text_from_url(url):
    """Extract text from webpage URL"""
    try:
        # List of CORS proxies to try
        proxies = [
            #f"https://api.allorigins.win/raw?url={requests.utils.quote(url)}",
            #f"https://corsproxy.io/?{requests.utils.quote(url)}"
            f"https://proxy.cors.sh/{requests.utils.quote(url)}"
        ]
        
        content = None
        
        # Try direct fetch first
        try:
            response = requests.get(url, timeout=100, headers={
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'x-cors-api-key': 'temp_47fbee13cc866f724d75708c3a170402'
            }, verify=False)
            if response.status_code == 200:
                content = response.text
        except:
            print("----------failed with direct access -----------")
            pass
        
        # Try proxy services if direct fetch failed
        if not content:
            for proxy_url in proxies:
                try:
                    print(f"get ==> {proxy_url}")
                    response = requests.get(proxy_url, timeout=150,headers={
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                    'x-cors-api-key': 'temp_47fbee13cc866f724d75708c3a170402'
            }, verify=False)
                    if response.status_code == 200:
                        content = response.text
                        break
                except Exception as e:
                    print(e)
                    continue
        
        if not content:
            raise Exception("Unable to fetch content from URL")
        
        # Parse HTML and extract text
        soup = BeautifulSoup(content, 'html.parser')
        
        # Remove unwanted elements
        for element in soup(['script', 'style', 'nav', 'header', 'footer', 'aside']):
            element.decompose()
        
        # Extract text
        text = soup.get_text()
        clean_text = ' '.join(text.split())  # Clean whitespace
        
        if len(clean_text) < 100:
            raise Exception("Insufficient content extracted from URL")
            
        return clean_text
        
    except Exception as e:
        raise Exception(f"URL extraction error: {str(e)}")

def extract_json_from_response(response_text):
    """Extract and validate JSON from AI response"""
    try:
        # Try to find JSON in the response
        import re
        json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
        if json_match:
            json_str = json_match.group(0)
        else:
            json_str = response_text
        
        # Parse JSON
        parsed_data = json.loads(json_str)
        
        # Validate required fields
        required_fields = ['jobTitle', 'company', 'location']
        for field in required_fields:
            if field not in parsed_data:
                parsed_data[field] = None
                
        return parsed_data
        
    except json.JSONDecodeError as e:
        raise Exception(f"Invalid JSON response from AI: {str(e)}")

# Web Routes

@app.route('/')
def index():
    """Serve the main application page"""
    return render_template('index.html')

@app.route('/static/<path:filename>')
def static_files(filename):
    """Serve static files"""
    return send_from_directory('static', filename)

# API Routes

@app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({"status": "healthy", "message": "Job Analyzer API is running"})

@app.route('/api/config', methods=['GET'])
def get_config():
    """Return configuration values for the frontend"""
    return jsonify({
        "ollama": {
            "default_model": DEFAULT_OLLAMA_MODEL
        },
        "openai": {
            "default_model": DEFAULT_OPENAI_MODEL,
            "api_key_configured": bool(OPENAI_API_KEY)
        },
        "deepseek": {
            "default_model": DEFAULT_DEEPSEEK_MODEL,
            "api_key_configured": bool(DEEPSEEK_API_KEY)
        }
    })

@app.route('/api/ollama/models', methods=['POST'])
def get_ollama_models():
    try:
        # Use configured Ollama URL from environment variables
        models = OllamaProvider.get_models(OLLAMA_BASE_URL)
        return jsonify({"success": True, "models": models})
        
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 400

@app.route('/api/extract', methods=['POST'])
def extract_job_info():
    try:
        data = request.get_json()
        
        # Get provider and configuration
        provider = data.get('provider', 'ollama')
        config = data.get('config', {})
        
        # Get job content based on input type
        input_type = data.get('input_type', 'text')
        job_content = ""
        
        if input_type == 'text':
            job_content = data.get('content', '')
            if not job_content.strip():
                raise Exception("No content provided")
                
        elif input_type == 'url':
            url = data.get('content', '')
            if not url:
                raise Exception("No URL provided")
            job_content = extract_text_from_url(url)
            
        elif input_type == 'pdf':
            pdf_data = data.get('content', '')
            if not pdf_data:
                raise Exception("No PDF data provided")
            
            # Decode base64 PDF data
            try:
                pdf_bytes = base64.b64decode(pdf_data.split(',')[1] if ',' in pdf_data else pdf_data)
                job_content = extract_text_from_pdf(pdf_bytes)
            except Exception as e:
                raise Exception(f"PDF processing error: {str(e)}")
        
        if not job_content.strip():
            raise Exception("No content to analyze")
        
        # Call appropriate AI provider
        ai_response = ""
        
        if provider == 'ollama':
            model = config.get('model', DEFAULT_OLLAMA_MODEL)
            if not model:
                raise Exception("No Ollama model specified")
            ai_response = OllamaProvider.call_api(OLLAMA_BASE_URL, model, job_content)
            
        elif provider == 'openai':
            if not OPENAI_API_KEY:
                raise Exception("OpenAI API key not configured in server")
            model = config.get('model', DEFAULT_OPENAI_MODEL)
            ai_response = OpenAIProvider.call_api(OPENAI_API_KEY, model, job_content)
            
        elif provider == 'deepseek':
            if not DEEPSEEK_API_KEY:
                raise Exception("DeepSeek API key not configured in server")
            model = config.get('model', DEFAULT_DEEPSEEK_MODEL)
            ai_response = DeepSeekProvider.call_api(DEEPSEEK_API_KEY, model, job_content)
            
        else:
            raise Exception(f"Unsupported provider: {provider}")
        
        # Extract and validate JSON from response
        extracted_data = extract_json_from_response(ai_response)
        
        return jsonify({
            "success": True,
            "data": extracted_data,
            "provider": provider,
            "content_length": len(job_content)
        })
        
    except Exception as e:
        print(f"Error in extract_job_info: {str(e)}")
        print(traceback.format_exc())
        return jsonify({"success": False, "error": str(e)}), 400

@app.route('/api/url-preview', methods=['POST'])
def preview_url():
    try:
        data = request.get_json()
        url = data.get('url', '')
        
        if not url:
            raise Exception("No URL provided")
        
        content = extract_text_from_url(url)
        
        # Get title from original URL if possible
        title = "Job Posting"
        try:
            response = requests.get(url, timeout=5, headers={
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            })
            if response.status_code == 200:
                soup = BeautifulSoup(response.text, 'html.parser')
                title_tag = soup.find('title')
                if title_tag:
                    title = title_tag.get_text().strip()
        except:
            pass
        
        preview = content[:300] + ("..." if len(content) > 300 else "")
        
        return jsonify({
            "success": True,
            "title": title,
            "preview": preview,
            "length": len(content),
            "url": url
        })
        
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 400

@app.errorhandler(404)
def not_found(e):
    return render_template('404.html'), 404

@app.errorhandler(500)
def server_error(e):
    return jsonify({"error": "Internal server error"}), 500

if __name__ == '__main__':
    # Create directories if they don't exist
    os.makedirs('templates', exist_ok=True)
    os.makedirs('static', exist_ok=True)
    
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_ENV') == 'development'
    app.run(host='0.0.0.0', port=port, debug=debug)
    
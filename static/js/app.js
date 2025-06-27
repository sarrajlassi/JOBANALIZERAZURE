// Configuration - now using relative URLs since served by Flask
const API_BASE_URL = '/api';

let currentTab = 'text';
let selectedFile = null;
let urlContent = null;
let currentProvider = 'ollama';

document.addEventListener('DOMContentLoaded', function() {
    loadConfig();
    setupFileUpload();
    
    // Add sample job posting
    const sampleJobPosting = `Senior Software Engineer - Full Stack
Company: TechCorp Solutions
Location: San Francisco, CA (Hybrid)
Salary: $130,000 - $160,000 per year

About the Role:
We are seeking an experienced Senior Software Engineer to join our dynamic engineering team. You will be responsible for developing and maintaining both frontend and backend systems for our SaaS platform.

Requirements:
• 5+ years of software development experience
• Proficiency in JavaScript, React, Node.js
• Experience with cloud platforms (AWS, Azure)
• Strong knowledge of databases (PostgreSQL, MongoDB)
• Bachelor's degree in Computer Science or related field

Benefits:
• Health, dental, and vision insurance
• 401(k) with company matching
• Flexible work arrangements
• Professional development budget
• Unlimited PTO

Join our team and help build the future of enterprise software solutions!`;
    
    document.getElementById('jobPosting').value = sampleJobPosting;
});

// Load configuration from backend
async function loadConfig() {
    try {
        const response = await fetch(`${API_BASE_URL}/config`);
        const config = await response.json();
        
        if (config.ollama) {
            // Store default Ollama model from backend configuration
            const ollamaModelSelect = document.getElementById('ollamaModel');
            if (ollamaModelSelect && config.ollama.default_model) {
                ollamaModelSelect.setAttribute('data-default-model', config.ollama.default_model);
            }
        }
        
        if (config.openai) {
            // Set default OpenAI model and update status
            const openaiModelSelect = document.getElementById('openaiModel');
            const openaiModelStatus = document.getElementById('openaiModelStatus');
            if (openaiModelSelect && config.openai.default_model) {
                openaiModelSelect.value = config.openai.default_model;
            }
            if (openaiModelStatus) {
                openaiModelStatus.textContent = config.openai.api_key_configured ? 
                    '✅ API key configured on server' : 
                    '❌ API key not configured on server';
            }
        }
        
        if (config.deepseek) {
            // Set default DeepSeek model and update status
            const deepseekModelSelect = document.getElementById('deepseekModel');
            const deepseekModelStatus = document.getElementById('deepseekModelStatus');
            if (deepseekModelSelect && config.deepseek.default_model) {
                deepseekModelSelect.value = config.deepseek.default_model;
            }
            if (deepseekModelStatus) {
                deepseekModelStatus.textContent = config.deepseek.api_key_configured ? 
                    '✅ API key configured on server' : 
                    '❌ API key not configured on server';
            }
        }
        
        // Load Ollama models after configuration is set
        loadOllamaModels();
        
    } catch (error) {
        console.error('Error loading config:', error);
        // Fallback to loading models with default URL
        loadOllamaModels();
    }
}

function switchProvider() {
    const provider = document.querySelector('input[name="provider"]:checked').value;
    currentProvider = provider;
    
    // Hide all config sections
    document.querySelectorAll('.api-config').forEach(config => {
        config.classList.remove('active');
    });
    
    // Show selected provider config
    document.getElementById(provider + 'Config').classList.add('active');
}

async function loadOllamaModels() {
    const modelSelect = document.getElementById('ollamaModel');
    const modelStatus = document.getElementById('ollamaModelStatus');
    
    modelSelect.disabled = true;
    modelStatus.textContent = 'Loading models...';
    
    try {
        const response = await fetch(`${API_BASE_URL}/ollama/models`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({})
        });
        
        const data = await response.json();
        
        if (data.success) {
            const models = data.models;
            const defaultModel = modelSelect.getAttribute('data-default-model');
            modelSelect.innerHTML = '';
            
            if (models.length === 0) {
                modelSelect.innerHTML = '<option value="">No models available</option>';
                modelStatus.textContent = 'No models found. Make sure Ollama is running and has models installed.';
            } else {
                let defaultFound = false;
                models.forEach(model => {
                    const option = document.createElement('option');
                    option.value = model.name;
                    option.textContent = `${model.name} (${formatBytes(model.size)})`;
                    
                    // Select the default model if it matches
                    if (defaultModel && model.name === defaultModel) {
                        option.selected = true;
                        defaultFound = true;
                    }
                    
                    modelSelect.appendChild(option);
                });
                
                let statusText = `Found ${models.length} model(s)`;
                if (defaultModel) {
                    if (defaultFound) {
                        statusText += ` - Default model '${defaultModel}' selected`;
                    } else {
                        statusText += ` - Default model '${defaultModel}' not found`;
                    }
                }
                modelStatus.textContent = statusText;
            }
        } else {
            throw new Error(data.error);
        }
        
    } catch (error) {
        console.error('Error loading models:', error);
        modelSelect.innerHTML = '<option value="">Error loading models</option>';
        modelStatus.textContent = `Error: ${error.message}`;
    } finally {
        modelSelect.disabled = false;
    }
}

function formatBytes(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function switchTab(tab) {
    currentTab = tab;
    
    document.querySelectorAll('.tab').forEach(btn => {
        btn.classList.remove('active');
    });
    event.target.classList.add('active');
    
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.remove('active');
    });
    document.getElementById(tab + 'Tab').classList.add('active');
}

async function validateAndPreviewUrl() {
    const jobUrl = document.getElementById('jobUrl').value;
    const urlPreview = document.getElementById('urlPreview');
    const validateBtn = event.target;
    
    if (!jobUrl) {
        showError('Please enter a URL first.');
        return;
    }
    
    try {
        new URL(jobUrl);
    } catch (error) {
        showError('Please enter a valid URL.');
        return;
    }
    
    validateBtn.disabled = true;
    validateBtn.textContent = 'Loading...';
    
    try {
        const response = await fetch(`${API_BASE_URL}/url-preview`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ url: jobUrl })
        });
        
        const data = await response.json();
        
        if (data.success) {
            urlContent = data.preview; // Store for later use
            
            urlPreview.innerHTML = `
                <h4>✅ ${data.title}</h4>
                <p><strong>URL:</strong> ${data.url}</p>
                <p><strong>Content Preview:</strong> ${data.preview}</p>
                <p><strong>Total Length:</strong> ${data.length} characters</p>
            `;
            urlPreview.style.display = 'block';
        } else {
            throw new Error(data.error);
        }
        
    } catch (error) {
        showError(`Error fetching URL: ${error.message}`);
        urlPreview.style.display = 'none';
        urlContent = null;
    } finally {
        validateBtn.disabled = false;
        validateBtn.textContent = 'Preview';
    }
}

function setupFileUpload() {
    const fileLabel = document.getElementById('fileLabel');
    const fileInput = document.getElementById('pdfFile');
    
    fileLabel.addEventListener('dragover', (e) => {
        e.preventDefault();
        fileLabel.classList.add('dragover');
    });
    
    fileLabel.addEventListener('dragleave', () => {
        fileLabel.classList.remove('dragover');
    });
    
    fileLabel.addEventListener('drop', (e) => {
        e.preventDefault();
        fileLabel.classList.remove('dragover');
        
        const files = e.dataTransfer.files;
        if (files.length > 0 && files[0].type === 'application/pdf') {
            fileInput.files = files;
            handleFileSelect({ target: fileInput });
        }
    });
}

function handleFileSelect(event) {
    const file = event.target.files[0];
    const fileInfo = document.getElementById('fileInfo');
    const fileLabel = document.getElementById('fileLabel');
    
    if (file) {
        selectedFile = file;
        fileInfo.style.display = 'block';
        fileInfo.innerHTML = `
            <strong>Selected:</strong> ${file.name}<br>
            <strong>Size:</strong> ${formatBytes(file.size)}<br>
            <strong>Type:</strong> ${file.type}
        `;
        
        fileLabel.innerHTML = `
            <div>✅ ${file.name} selected</div>
            <div style="font-size: 14px; color: #6b7280; margin-top: 8px;">Click to select a different file</div>
        `;
    }
}

async function fileToBase64(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.readAsDataURL(file);
        reader.onload = () => resolve(reader.result);
        reader.onerror = error => reject(error);
    });
}

function getProviderConfig() {
    const config = {};
    
    if (currentProvider === 'ollama') {
        config.model = document.getElementById('ollamaModel').value;
    } else if (currentProvider === 'openai') {
        config.model = document.getElementById('openaiModel').value;
    } else if (currentProvider === 'deepseek') {
        config.model = document.getElementById('deepseekModel').value;
    }
    
    return config;
}

async function extractJobInfo() {
    let content = '';
    let inputType = currentTab;
    
    // Get content based on current tab
    if (currentTab === 'text') {
        content = document.getElementById('jobPosting').value;
        if (!content.trim()) {
            showError('Please enter a job posting to analyze.');
            return;
        }
    } else if (currentTab === 'url') {
        const jobUrl = document.getElementById('jobUrl').value;
        if (!jobUrl) {
            showError('Please enter and preview a URL first.');
            return;
        }
        content = jobUrl;
    } else if (currentTab === 'pdf') {
        if (!selectedFile) {
            showError('Please select a PDF file to analyze.');
            return;
        }
        
        try {
            content = await fileToBase64(selectedFile);
        } catch (error) {
            showError('Error reading PDF file.');
            return;
        }
    }
    
    const extractBtn = document.getElementById('extractBtn');
    const loading = document.getElementById('loading');
    const result = document.getElementById('result');
    const error = document.getElementById('error');
    const successInfo = document.getElementById('successInfo');
    
    // Show loading state
    extractBtn.disabled = true;
    loading.style.display = 'block';
    result.style.display = 'none';
    error.style.display = 'none';
    document.getElementById('loadingText').textContent = `Processing with ${currentProvider.toUpperCase()}...`;
    
    try {
        const requestData = {
            provider: currentProvider,
            config: getProviderConfig(),
            input_type: inputType,
            content: content
        };
        
        const response = await fetch(`${API_BASE_URL}/extract`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(requestData)
        });
        
        const data = await response.json();
        
        if (data.success) {
            displayResult(data.data);
            
            // Show success info
            successInfo.innerHTML = `
                ✅ <strong>Analysis Complete!</strong><br>
                Provider: ${data.provider.toUpperCase()}<br>
                Content Length: ${data.content_length} characters<br>
                Processing Time: ${new Date().toLocaleTimeString()}
            `;
            successInfo.style.display = 'block';
        } else {
            throw new Error(data.error);
        }
        
    } catch (error) {
        console.error('Error:', error);
        showError(`Failed to extract job information: ${error.message}`);
    } finally {
        extractBtn.disabled = false;
        loading.style.display = 'none';
    }
}

function displayResult(data) {
    const result = document.getElementById('result');
    const jsonOutput = document.getElementById('jsonOutput');
    
    // Format JSON with proper indentation
    const formattedJson = JSON.stringify(data, null, 2);
    
    // Set the JSON content
    jsonOutput.textContent = formattedJson;
    
    // Trigger Prism.js syntax highlighting
    if (window.Prism) {
        Prism.highlightElement(jsonOutput);
    }
    
    result.style.display = 'block';
    result.scrollIntoView({ behavior: 'smooth' });
}

function copyJsonToClipboard() {
    const jsonOutput = document.getElementById('jsonOutput');
    const copyBtn = event.target;
    
    if (jsonOutput && jsonOutput.textContent) {
        navigator.clipboard.writeText(jsonOutput.textContent).then(() => {
            // Show success feedback
            const originalText = copyBtn.textContent;
            copyBtn.textContent = '✅ Copied!';
            copyBtn.style.background = '#10b981';
            
            setTimeout(() => {
                copyBtn.textContent = originalText;
                copyBtn.style.background = '#7c3aed';
            }, 2000);
        }).catch(err => {
            console.error('Failed to copy: ', err);
            // Fallback for older browsers
            const textArea = document.createElement('textarea');
            textArea.value = jsonOutput.textContent;
            document.body.appendChild(textArea);
            textArea.select();
            document.execCommand('copy');
            document.body.removeChild(textArea);
            
            const originalText = copyBtn.textContent;
            copyBtn.textContent = '✅ Copied!';
            copyBtn.style.background = '#10b981';
            
            setTimeout(() => {
                copyBtn.textContent = originalText;
                copyBtn.style.background = '#7c3aed';
            }, 2000);
        });
    }
}

function showError(message) {
    const error = document.getElementById('error');
    error.textContent = message;
    error.style.display = 'block';
    
    error.scrollIntoView({ behavior: 'smooth' });
}

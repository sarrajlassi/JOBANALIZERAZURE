#!/bin/bash

# ==============================================================================
# Script d'installation et de déploiement pour l'application Flask Job Analyzer
# sur une VM Azure (Ubuntu).
# Ce script est conçu pour être exécuté via Azure "Run Command"
# ou une extension de script personnalisée, SANS ACCÈS SSH DIRECT initial.
# ==============================================================================

echo "--- Démarrage du script d'installation setup_azure.sh ---"
echo "Date et heure de début : $(date)"

# --- Configuration des variables ---
# ==================================
# !!! TRÈS IMPORTANT : MODIFIEZ CES VALEURS POUR CORRESPONDRE À VOTRE PROJET !!!
# ==================================

# 1. Informations sur votre dépôt Git
#    Remplacez par votre nom d'utilisateur GitHub / organisation et le nom de votre dépôt.
#    Exemple : GITHUB_REPO="monutilisateur/job-analyzer-app"
GITHUB_REPO="sarrajlassi/JOBANALIZERAZURE" # <--- CONFIRMÉ ET CORRIGÉ !
BRANCH_NAME="main" # Ou "master", ou la branche que vous utilisez pour le déploiement.

# 2. Chemin d'installation de l'application sur la VM
APP_DIR="/home/azureuser/JOBANALIZERAZURE" # <--- CONFIRMÉ ET CORRIGÉ !

# 3. Noms de fichiers et modules Flask
FLASK_APP_FILE="app.py"    # Nom de votre fichier Flask principal (ex: app.py).
FLASK_APP_MODULE="app"     # Nom de l'instance Flask dans app.py (la variable "app = Flask(...)").

# 4. Configuration des ports
APP_PORT="5000" # Port interne sur lequel Flask/Gunicorn va écouter. Nginx redirigera le trafic du port 80 vers ce port.

# 5. Configuration Ollama (si vous l'utilisez)
OLLAMA_HOST="localhost" # Ollama est sur la même VM, donc localhost.
OLLAMA_PORT="11434"     # Port par défaut d'Ollama.
# Modèle Ollama à télécharger par défaut au démarrage de la VM.
# Assurez-vous que la VM a suffisamment de RAM pour ce modèle.
# Exemples : llama2, mistral, gemma:2b, phi-3-mini
DEFAULT_OLLAMA_MODEL="llama2" 

# 6. Clés API pour les services externes (OpenAI, DeepSeek)
#    Sécurité : Idéalement, ces clés ne devraient PAS être en clair dans un script.
#    Pour un premier test, vous pouvez les mettre ici. Pour la production,
#    envisagez Azure Key Vault et les identités managées, ou les ajouter
#    manuellement au fichier .env après le déploiement via Azure Bastion.
OPENAI_API_KEY="" # Laissez vide si vous ne l'utilisez pas ou configurez via .env manuellement.
DEEPSEEK_API_KEY="" # Laissez vide si vous ne l'utilisez pas ou configurez via .env manuellement.


echo "Variables configurées :
  GITHUB_REPO=$GITHUB_REPO
  BRANCH_NAME=$BRANCH_NAME
  APP_DIR=$APP_DIR
  DEFAULT_OLLAMA_MODEL=$DEFAULT_OLLAMA_MODEL
  APP_PORT=$APP_PORT"

# --- 1. Mise à jour du système et installation des prérequis ---
echo "--- Étape 1: Mise à jour du système et installation des prérequis ---"
sudo apt update -y
sudo apt upgrade -y
# git: pour cloner le dépôt
# python3, python3-pip, python3-venv: pour l'environnement Python
# nginx: pour le serveur web proxy
# curl: pour l'installation d'Ollama
# unzip, tar: pour la décompression d'archives si vous aviez besoin de transférer manuellement
sudo apt install -y git python3 python3-pip python3-venv nginx curl unzip tar

if [ $? -ne 0 ]; then
    echo "ERREUR: Échec de l'installation des paquets APT. Vérifiez la connectivité internet de la VM ou les dépôts."
    exit 1
fi
echo "Prérequis système installés."


# --- 2. Clonage du dépôt Git ---
echo "--- Étape 2: Clonage du dépôt Git ---"
# Nettoyage des anciens dossiers pour un déploiement propre
echo "Nettoyage des anciens répertoires d'application..."
sudo rm -rf "/home/azureuser/job-analyzer-app"
sudo rm -rf "/home/azureuser/JobAnalizer"
if [ -d "$APP_DIR" ]; then
    echo "Répertoire d'application existant ($APP_DIR). Suppression..."
    sudo rm -rf "$APP_DIR"
fi

# Pour un dépôt privé, l'URL doit inclure le PAT :
# git clone "https://oauth2:ghp_YOUR_SUPER_SECRET_PAT_HERE@github.com/$GITHUB_REPO.git" "$APP_DIR"
# Remplacez 'ghp_YOUR_SUPER_SECRET_PAT_HERE' par votre jeton réel.
# Si le dépôt est public, la ligne ci-dessous est suffisante :
echo "Clonage de https://github.com/$GITHUB_REPO.git vers $APP_DIR..."
git clone "https://github.com/$GITHUB_REPO.git" "$APP_DIR"
# Ou si votre dépôt est privé:
# git clone "https://oauth2:VOTRE_PAT_GITHUB_ICI@github.com/$GITHUB_REPO.git" "$APP_DIR"


if [ $? -ne 0 ]; then
    echo "ERREUR: Échec du clonage du dépôt Git. Vérifiez 'GITHUB_REPO' et la connectivité. (Si dépôt privé, utilisez PAT dans l'URL)."
    exit 1
fi

# Correction de la propriété du dossier cloné !
echo "Correction de la propriété du répertoire '$APP_DIR' vers azureuser:azureuser..."
sudo chown -R azureuser:azureuser "$APP_DIR"
if [ $? -ne 0 ]; then
    echo "ERREUR: Échec du changement de propriété du répertoire d'application. Permissions problématiques."
    exit 1
fi

cd "$APP_DIR"
git checkout $BRANCH_NAME
if [ $? -ne 0 ]; then
    echo "AVERTISSEMENT: Échec du checkout de la branche $BRANCH_NAME."
fi
echo "Dépôt cloné avec succès dans $APP_DIR."


# --- 3. Configuration de l'environnement Python ---
echo "--- Étape 3: Configuration de l'environnement Python ---"
PYTHON_ENV_DIR="$APP_DIR/venv" # Chemin complet de l'environnement virtuel

echo "Création de l'environnement virtuel Python dans $PYTHON_ENV_DIR..."
sudo -u azureuser python3 -m venv "$PYTHON_ENV_DIR"
if [ $? -ne 0 ]; then
    echo "ERREUR: Échec de la création de l'environnement virtuel Python."
    exit 1
fi

echo "Activation de l'environnement virtuel et installation des dépendances..."
sudo -u azureuser bash -c "source \"$PYTHON_ENV_DIR/bin/activate\" && pip install --upgrade pip && pip install -r requirements.txt"
if [ $? -ne 0 ]; then
    echo "ERREUR: Échec de l'installation des dépendances Python. Vérifiez 'requirements.txt' ou la connectivité."
    exit 1
fi
echo "Dépendances Python installées."


# --- 4. Installation et Configuration d'Ollama ---
echo "--- Étape 4: Installation et Configuration d'Ollama ---"
echo "Exécution du script d'installation d'Ollama..."
curl -fsSL https://ollama.com/install.sh | sh
if [ $? -ne 0 ]; then
    echo "AVERTISSEMENT: Échec de l'installation d'Ollama. Continuez, mais le service Ollama pourrait ne pas être fonctionnel."
fi

echo "Attente de 15 secondes pour le démarrage du service Ollama..."
sleep 15 # Donner un peu plus de temps à Ollama pour démarrer et s'initialiser

echo "Vérification du statut du service Ollama..."
sudo systemctl status ollama --no-pager
if [ $? -ne 0 ]; then
    echo "AVERTISSEMENT: Le service Ollama n'est pas actif. Veuillez vérifier manuellement plus tard."
fi

echo "Tentative de définition de \$HOME pour Ollama..."
export HOME="/home/azureuser" # <--- CORRECTION POUR OLLAMA

echo "Téléchargement du modèle Ollama par défaut ($DEFAULT_OLLAMA_MODEL)..."
sudo -u azureuser ollama pull "$DEFAULT_OLLAMA_MODEL"
if [ $? -ne 0 ]; then
    echo "AVERTISSEMENT: Échec du téléchargement du modèle Ollama '$DEFAULT_OLLAMA_MODEL'. Vérifiez le nom du modèle ou la connectivité. (L'erreur 'panic: $HOME is not defined' suggère un problème d'environnement.)"
fi
echo "Ollama installé et modèle tenté de télécharger."


# --- 5. Configuration des variables d'environnement (.env) ---
echo "--- Étape 5: Configuration des variables d'environnement (.env) ---"
# *** MODIFICATION ICI : Vérifie et assure les permissions du .env existant ***
if [ -f "$APP_DIR/.env" ]; then
    echo "Le fichier .env existe déjà dans le dépôt cloné. Vérification et correction des permissions..."
    sudo chown azureuser:azureuser "$APP_DIR/.env"
    sudo chmod 644 "$APP_DIR/.env" # Lecture/Écriture pour l'utilisateur, Lecture seule pour le groupe/autres
    if [ $? -ne 0 ]; then
        echo "AVERTISSEMENT: Échec de la correction des permissions pour '$APP_DIR/.env'."
    fi
    echo "Fichier .env prêt."
else
    echo "ERREUR: Le fichier '$APP_DIR/.env' est introuvable dans le dépôt cloné."
    echo "Veuillez vous assurer que le fichier '.env' est bien présent à la racine de votre dépôt GitHub."
    echo "Note: La pratique recommandée est d'utiliser un fichier '.env.example' et de ne pas commiter le '.env' directement sur GitHub."
    exit 1 # Exit car le .env est critique pour l'application
fi


# Injecter les clés API si elles sont définies dans ce script (moins sécurisé mais direct)
# Utiliser sudo -u azureuser pour s'assurer que les écritures sont faites avec les bonnes permissions
# Note: Si le .env est déjà complet dans le dépôt, ces ajouts peuvent être redondants.
if [ -n "$OPENAI_API_KEY" ]; then
    # Utiliser grep pour vérifier si la ligne existe déjà avant d'ajouter
    if ! sudo -u azureuser grep -q "^OPENAI_API_KEY=" "$APP_DIR/.env"; then
        sudo -u azureuser bash -c "echo \"OPENAI_API_KEY=$OPENAI_API_KEY\" >> \"$APP_DIR/.env\""
        echo "Clé OpenAI ajoutée/mise à jour dans .env."
    else
        echo "Clé OpenAI déjà présente dans .env, non modifiée par le script."
    fi
fi
if [ -n "$DEEPSEEK_API_KEY" ]; then
    if ! sudo -u azureuser grep -q "^DEEPSEEK_API_KEY=" "$APP_DIR/.env"; then
        sudo -u azureuser bash -c "echo \"DEEPSEEK_API_KEY=$DEEPSEEK_API_KEY\" >> \"$APP_DIR/.env\""
        echo "Clé DeepSeek ajoutée/mise à jour dans .env."
    else
        echo "Clé DeepSeek déjà présente dans .env, non modifiée par le script."
    fi
fi


# --- 6. Configuration de Gunicorn avec Systemd ---
echo "--- Étape 6: Configuration de Gunicorn avec Systemd ---"
SERVICE_NAME="${FLASK_APP_MODULE}.service"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"

# Créer le fichier de service Systemd pour Gunicorn
sudo bash -c "cat > ${SERVICE_FILE}" <<EOL
[Unit]
Description=Gunicorn instance to serve the Flask Job Analyzer App
After=network.target

[Service]
User=azureuser # L'utilisateur sous lequel le service s'exécute (par défaut sur Azure VM)
Group=www-data # Groupe pour les permissions de socket (Nginx a besoin d'y accéder)
WorkingDirectory=$APP_DIR
# IMPORTANT : Inclure le chemin de l'environnement virtuel pour que gunicorn soit trouvé
Environment="PATH=$PYTHON_ENV_DIR/bin:/usr/local/bin:/usr/bin:/bin"
# Charger les variables d'environnement depuis le fichier .env
EnvironmentFile=$APP_DIR/.env
ExecStart=$PYTHON_ENV_DIR/bin/gunicorn --workers 4 --bind unix:$APP_DIR/job_analyzer.sock -m 007 $FLASK_APP_MODULE:app
Restart=always

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload # Recharger les configurations Systemd
sudo systemctl enable "${SERVICE_NAME}" # Activer le service pour qu'il démarre au boot
sudo systemctl start "${SERVICE_NAME}" # Démarrer le service maintenant
if [ $? -ne 0 ]; then
    echo "ERREUR: Échec du démarrage du service Gunicorn '${SERVICE_NAME}'. Vérifiez les logs avec 'sudo journalctl -u ${SERVICE_NAME} --no-pager'."
    exit 1
fi
echo "Service Gunicorn '${SERVICE_NAME}' créé, activé et démarré."


# --- 7. Configuration de Nginx (Reverse Proxy) ---
echo "--- Étape 7: Configuration de Nginx (Reverse Proxy) ---"
NGINX_CONF_FILE="/etc/nginx/sites-available/job_analyzer_nginx.conf"

# Supprimer l'ancien lien symbolique si existant (pour éviter "File exists")
sudo rm -f /etc/nginx/sites-enabled/job_analyzer_nginx.conf

# Créer le fichier de configuration Nginx
sudo bash -c "cat > ${NGINX_CONF_FILE}" <<EOL
server {
    listen 80;
    server_name _; # Écoute toutes les IP. Remplacez par votre IP publique ou nom de domaine si vous en avez un.

    location / {
        include proxy_params;
        proxy_pass http://unix:$APP_DIR/job_analyzer.sock; # Point vers le socket Gunicorn
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Optionnel : Servir les fichiers statiques directement via Nginx pour de meilleures performances
    location /static/ {
        alias $APP_DIR/static/;
        expires 30d; # Mette en cache les fichiers statiques pendant 30 jours
        add_header Cache-Control "public, no-transform";
    }
}
EOL

# Supprimer le site Nginx par défaut (si existant) et créer un lien symbolique vers notre config
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -s "$NGINX_CONF_FILE" /etc/nginx/sites-enabled/
if [ $? -ne 0 ]; then
    echo "AVERTISSEMENT: Échec de la création du lien symbolique pour la configuration Nginx. Cela peut se produire si le lien existe déjà."
fi

echo "Vérification de la syntaxe de la configuration Nginx..."
sudo nginx -t
if [ $? -ne 0 ]; then
    echo "ERREUR: Erreur de syntaxe dans la configuration Nginx. Vérifiez ${NGINX_CONF_FILE}."
    exit 1
fi

echo "Redémarrage du service Nginx..."
sudo systemctl restart nginx
if [ $? -ne 0 ]; then
    echo "ERREUR: Échec du redémarrage de Nginx. Vérifiez les logs de Nginx (/var/log/nginx/error.log)."
    exit 1
fi
echo "Nginx configuré et redémarré avec succès."

echo "--- Script d'installation terminé ! ---"
echo "Date et heure de fin : $(date)"
echo "Votre application Flask devrait maintenant être accessible via l'IP publique de la VM sur le port 80 (HTTP)."
echo "Pour vérifier les logs de l'application, utilisez : sudo journalctl -u ${SERVICE_NAME} --no-pager"
echo "Pour les logs d'erreurs Nginx : sudo tail -f /var/log/nginx/error.log"

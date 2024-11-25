#!/bin/bash

# Vérifier que les paramètres ont été fournis
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <git_repo_url> <container_name> "
    exit 1
fi

# Définir les variables à partir des paramètres
GIT_REPO_URL="$1"         # URL du dépôt GitHub
CONTAINER_NAME="$2"       # Nom du conteneur
DIR_TO_REMOVE="$CONTAINER_NAME"  # Le dossier porte le même nom que le conteneur

# Cloner le dépôt GitHub dans le répertoire courant si ce n'est pas déjà fait
REPO_DIR="$(basename "$GIT_REPO_URL" .git)"  # Nom du dossier du dépôt (sans le .git)
if [ ! -d "$REPO_DIR" ]; then
    echo "Clonage du dépôt GitHub : $GIT_REPO_URL"
    git clone "$GIT_REPO_URL"
else
    echo "Le dépôt est déjà cloné, mise à jour en cours..."
    cd "$REPO_DIR" && git pull && cd ..
fi

# Charger les variables depuis le fichier .env du dépôt cloné
if [ -f "$REPO_DIR/.env" ]; then
    echo "Chargement des variables depuis le fichier .env"
    export $(grep -v '^#' "$REPO_DIR/.env" | xargs)
else
    echo "Le fichier .env n'a pas été trouvé dans le dépôt cloné. Assurez-vous qu'il existe."
    exit 1
fi

# Vérifier si le conteneur existe déjà
container_exists() {
    docker ps -a --format '{{.Names}}' | grep -w "$CONTAINER_NAME" > /dev/null 2>&1
}

# Supprimer le dossier associé si nécessaire
if [ -d "$DIR_TO_REMOVE" ]; then
    echo "Suppression du dossier : $DIR_TO_REMOVE"
    rm -rf "$DIR_TO_REMOVE"
    if [ $? -eq 0 ]; then
        echo "Dossier $DIR_TO_REMOVE supprimé avec succès."
    else
        echo "Erreur : Impossible de supprimer le dossier $DIR_TO_REMOVE."
        exit 1
    fi
else
    echo "Aucun dossier nommé $DIR_TO_REMOVE à supprimer."
fi

# Construire l'image Docker
echo "Construction de l'image Docker : $IMAGE_NAME"
docker build -t "$IMAGE_NAME" .

# Vérifier si un conteneur avec le même nom existe
if container_exists; then
    echo "Un conteneur avec le nom $CONTAINER_NAME existe déjà."

    # Arrêter le conteneur existant
    echo "Arrêt du conteneur existant..."
    docker stop "$CONTAINER_NAME"

    # Supprimer le conteneur existant
    echo "Suppression du conteneur existant..."
    docker rm "$CONTAINER_NAME"
fi

# Lancer un nouveau conteneur
echo "Lancement d'un nouveau conteneur : $CONTAINER_NAME"
docker run -d -p "$PORT_IN":"$PORT_OUT" --name "$CONTAINER_NAME" "$CONTAINER_NAME"

# Vérifier si le conteneur a démarré avec succès
if [ $? -eq 0 ]; then
    echo "Le conteneur $CONTAINER_NAME a été lancé avec succès sur le port $PORT_IN."
else
    echo "Erreur : Impossible de lancer le conteneur $CONTAINER_NAME."
    exit 1
fi

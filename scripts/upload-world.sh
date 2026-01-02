#!/bin/bash
# Script para fazer upload de um mundo local para o servidor Valheim
# Uso: ./upload-world.sh <IP_SERVIDOR> <CAMINHO_DO_MUNDO> [USUARIO_SSH]

set -e

SERVER_IP=${1:-""}
WORLD_PATH=${2:-""}
SSH_USER=${3:-"root"}

if [ -z "$SERVER_IP" ] || [ -z "$WORLD_PATH" ]; then
    echo "Uso: ./upload-world.sh <IP_SERVIDOR> <CAMINHO_DO_MUNDO> [USUARIO_SSH]"
    echo ""
    echo "Exemplo Windows (Git Bash):"
    echo "  ./upload-world.sh 192.168.1.100 '/c/Users/SeuUser/AppData/LocalLow/IronGate/Valheim/worlds_local/MeuMundo'"
    echo ""
    echo "Exemplo Linux/Mac:"
    echo "  ./upload-world.sh 192.168.1.100 ~/.config/unity3d/IronGate/Valheim/worlds_local/MeuMundo"
    echo ""
    echo "Arquivos necessários no diretório do mundo:"
    echo "  - MeuMundo.fwl"
    echo "  - MeuMundo.db"
    exit 1
fi

WORLD_NAME=$(basename "$WORLD_PATH")

echo "=== Upload de Mundo Valheim ==="
echo "Servidor: $SERVER_IP"
echo "Mundo: $WORLD_NAME"
echo "Caminho: $WORLD_PATH"
echo ""

# Verificar se os arquivos existem
if [ ! -f "${WORLD_PATH}.fwl" ] || [ ! -f "${WORLD_PATH}.db" ]; then
    echo "ERRO: Arquivos do mundo não encontrados!"
    echo "Esperado:"
    echo "  - ${WORLD_PATH}.fwl"
    echo "  - ${WORLD_PATH}.db"
    exit 1
fi

echo "Arquivos encontrados:"
ls -lh "${WORLD_PATH}".{fwl,db}
echo ""

read -p "Continuar com o upload? (s/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Cancelado."
    exit 0
fi

echo ""
echo "1. Parando o servidor Valheim..."
ssh ${SSH_USER}@${SERVER_IP} "cd /opt/valheim-server && docker compose stop valheim"

echo ""
echo "2. Fazendo backup do mundo atual (se existir)..."
ssh ${SSH_USER}@${SERVER_IP} "docker run --rm -v valheim-server_valheim-config:/config alpine sh -c 'mkdir -p /config/worlds_backup && cp /config/worlds_local/* /config/worlds_backup/ 2>/dev/null || true'"

echo ""
echo "3. Enviando arquivos do mundo..."
# Criar diretório temporário no servidor
ssh ${SSH_USER}@${SERVER_IP} "mkdir -p /tmp/valheim-upload"

# Enviar arquivos
scp "${WORLD_PATH}.fwl" "${WORLD_PATH}.db" ${SSH_USER}@${SERVER_IP}:/tmp/valheim-upload/

echo ""
echo "4. Copiando para o volume Docker..."
ssh ${SSH_USER}@${SERVER_IP} << EOF
docker run --rm \
  -v valheim-server_valheim-config:/config \
  -v /tmp/valheim-upload:/upload:ro \
  alpine sh -c "mkdir -p /config/worlds_local && cp /upload/* /config/worlds_local/ && chown -R 1000:1000 /config/worlds_local"

rm -rf /tmp/valheim-upload
EOF

echo ""
echo "5. Reiniciando o servidor..."
ssh ${SSH_USER}@${SERVER_IP} "cd /opt/valheim-server && docker compose start valheim"

echo ""
echo "=== Upload concluído! ==="
echo ""
echo "IMPORTANTE: Certifique-se que WORLD_NAME no .env corresponde ao nome do mundo: ${WORLD_NAME}"
echo "Se necessário, edite /opt/valheim-server/.env no servidor e reinicie:"
echo "  ssh ${SSH_USER}@${SERVER_IP}"
echo "  nano /opt/valheim-server/.env"
echo "  cd /opt/valheim-server && docker compose restart"

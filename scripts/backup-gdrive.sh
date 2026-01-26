#!/bin/bash
# Script de backup do servidor Valheim para Google Drive
# Requer rclone configurado com remote "gdrive"

set -e

BACKUP_DIR="/opt/valheim-server/backups"
GDRIVE_REMOTE="gdrive"
GDRIVE_FOLDER="valheim-backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="valheim_backup_${DATE}.tar.gz"
MAX_BACKUPS=10

echo "=== Backup Valheim para Google Drive ==="
echo "Data: $(date)"
echo ""

# Criar diretório de backup local temporário
mkdir -p ${BACKUP_DIR}

# 1. Criar backup do volume Docker
echo "1. Criando backup local..."
docker run --rm \
  -v valheim-server_valheim-config:/config:ro \
  -v ${BACKUP_DIR}:/backup \
  alpine tar czf /backup/${BACKUP_NAME} -C /config .

echo "   Backup criado: ${BACKUP_NAME}"
ls -lh ${BACKUP_DIR}/${BACKUP_NAME}

# 2. Verificar se rclone está instalado
if ! command -v rclone &> /dev/null; then
    echo ""
    echo "ERRO: rclone não está instalado!"
    echo "Execute o script de setup primeiro: ./setup-gdrive.sh"
    exit 1
fi

# 3. Verificar se o remote está configurado
if ! rclone listremotes | grep -q "^${GDRIVE_REMOTE}:"; then
    echo ""
    echo "ERRO: Remote '${GDRIVE_REMOTE}' não configurado no rclone!"
    echo "Execute o script de setup primeiro: ./setup-gdrive.sh"
    exit 1
fi

# 4. Criar pasta no Google Drive se não existir
echo ""
echo "2. Enviando para Google Drive..."
rclone mkdir ${GDRIVE_REMOTE}:${GDRIVE_FOLDER} 2>/dev/null || true

# 5. Fazer upload
rclone copy ${BACKUP_DIR}/${BACKUP_NAME} ${GDRIVE_REMOTE}:${GDRIVE_FOLDER}/ --progress

echo "   Upload concluído!"

# 6. Limpar backups antigos no Google Drive (manter últimos MAX_BACKUPS)
echo ""
echo "3. Limpando backups antigos no Google Drive..."
REMOTE_BACKUPS=$(rclone lsf ${GDRIVE_REMOTE}:${GDRIVE_FOLDER}/ --files-only | grep "valheim_backup_" | sort -r)
COUNT=0
while IFS= read -r file; do
    COUNT=$((COUNT + 1))
    if [ $COUNT -gt $MAX_BACKUPS ]; then
        echo "   Removendo: $file"
        rclone delete ${GDRIVE_REMOTE}:${GDRIVE_FOLDER}/${file}
    fi
done <<< "$REMOTE_BACKUPS"

# 7. Limpar backup local (opcional - descomente para manter só na nuvem)
echo ""
echo "4. Limpando backup local..."
rm -f ${BACKUP_DIR}/${BACKUP_NAME}
echo "   Backup local removido (mantido apenas no Google Drive)"

# 8. Listar backups no Google Drive
echo ""
echo "=== Backups no Google Drive ==="
rclone lsl ${GDRIVE_REMOTE}:${GDRIVE_FOLDER}/ | head -20

echo ""
echo "=== Backup concluído com sucesso! ==="

#!/bin/bash
# Script de backup manual do servidor Valheim

BACKUP_DIR="/opt/valheim-server/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="valheim_backup_${DATE}.tar.gz"

echo "Iniciando backup do servidor Valheim..."

# Criar diretório de backup se não existir
mkdir -p ${BACKUP_DIR}

# Copiar volumes do Docker para backup
docker run --rm \
  -v valheim-server_valheim-config:/config:ro \
  -v ${BACKUP_DIR}:/backup \
  alpine tar czf /backup/${BACKUP_NAME} -C /config .

# Manter apenas os últimos 7 backups
cd ${BACKUP_DIR}
ls -t valheim_backup_*.tar.gz | tail -n +8 | xargs -r rm

echo "Backup concluído: ${BACKUP_DIR}/${BACKUP_NAME}"

# Listar backups existentes
echo ""
echo "Backups disponíveis:"
ls -lh ${BACKUP_DIR}/valheim_backup_*.tar.gz 2>/dev/null || echo "Nenhum backup encontrado"

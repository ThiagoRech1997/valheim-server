#!/bin/bash
# Script para restaurar backup do Google Drive
# Uso: ./restore-gdrive.sh [nome_do_backup]

set -e

GDRIVE_REMOTE="gdrive"
GDRIVE_FOLDER="valheim-backups"
BACKUP_DIR="/opt/valheim-server/backups"
BACKUP_NAME=${1:-""}

echo "=== Restaurar Backup do Google Drive ==="
echo ""

# Verificar rclone
if ! command -v rclone &> /dev/null; then
    echo "ERRO: rclone não está instalado!"
    exit 1
fi

# Listar backups disponíveis
echo "Backups disponíveis no Google Drive:"
echo ""
rclone lsl ${GDRIVE_REMOTE}:${GDRIVE_FOLDER}/ | grep "valheim_backup_" | sort -r | head -20
echo ""

# Se não especificou backup, perguntar
if [ -z "$BACKUP_NAME" ]; then
    echo "Qual backup deseja restaurar?"
    echo "(Digite o nome completo do arquivo, ex: valheim_backup_20240115_040000.tar.gz)"
    read -p "> " BACKUP_NAME
fi

if [ -z "$BACKUP_NAME" ]; then
    echo "Nenhum backup selecionado. Cancelando."
    exit 1
fi

echo ""
echo "Backup selecionado: $BACKUP_NAME"
read -p "ATENÇÃO: Isso vai substituir o mundo atual! Continuar? (s/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Cancelado."
    exit 0
fi

# Criar diretório temporário
mkdir -p ${BACKUP_DIR}

echo ""
echo "1. Parando servidor Valheim..."
cd /opt/valheim-server && docker compose stop valheim

echo ""
echo "2. Baixando backup do Google Drive..."
rclone copy ${GDRIVE_REMOTE}:${GDRIVE_FOLDER}/${BACKUP_NAME} ${BACKUP_DIR}/ --progress

echo ""
echo "3. Fazendo backup do mundo atual (segurança)..."
docker run --rm \
  -v valheim-server_valheim-config:/config:ro \
  -v ${BACKUP_DIR}:/backup \
  alpine tar czf /backup/pre_restore_backup_$(date +%Y%m%d_%H%M%S).tar.gz -C /config .

echo ""
echo "4. Restaurando backup..."
docker run --rm \
  -v valheim-server_valheim-config:/config \
  -v ${BACKUP_DIR}:/backup:ro \
  alpine sh -c "rm -rf /config/worlds_local/* && tar xzf /backup/${BACKUP_NAME} -C /config && chown -R 1000:1000 /config"

echo ""
echo "5. Reiniciando servidor..."
cd /opt/valheim-server && docker compose start valheim

echo ""
echo "6. Limpando arquivo temporário..."
rm -f ${BACKUP_DIR}/${BACKUP_NAME}

echo ""
echo "=== Restauração concluída! ==="
echo "O servidor está iniciando. Aguarde alguns minutos."
echo ""
echo "Para ver os logs:"
echo "  cd /opt/valheim-server && docker compose logs -f"

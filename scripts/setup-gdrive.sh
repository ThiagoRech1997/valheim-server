#!/bin/bash
# Script para configurar rclone com Google Drive
# Execute este script uma vez para configurar a autenticação

set -e

echo "=== Configuração do Google Drive para Backups ==="
echo ""

# 1. Instalar rclone se não existir
if ! command -v rclone &> /dev/null; then
    echo "1. Instalando rclone..."
    curl https://rclone.org/install.sh | bash
else
    echo "1. rclone já está instalado: $(rclone version | head -1)"
fi

echo ""
echo "2. Configurando Google Drive..."
echo ""
echo "   IMPORTANTE: Como você está em um servidor sem interface gráfica,"
echo "   você precisará usar a autenticação remota."
echo ""
echo "   Opção A - Configuração interativa (recomendado para primeira vez):"
echo "   Execute: rclone config"
echo "   - Escolha 'n' para novo remote"
echo "   - Nome: gdrive"
echo "   - Tipo: drive (Google Drive)"
echo "   - Deixe client_id e client_secret em branco"
echo "   - Scope: 1 (Full access)"
echo "   - Deixe root_folder_id em branco"
echo "   - Deixe service_account_file em branco"
echo "   - Auto config: n (você está em servidor remoto)"
echo "   - Copie o link, abra no seu navegador local"
echo "   - Faça login no Google e copie o código de volta"
echo ""
echo "   Opção B - Configuração via máquina local:"
echo "   1. Instale rclone no seu PC Windows"
echo "   2. Execute: rclone authorize \"drive\""
echo "   3. Faça login no navegador"
echo "   4. Copie o token JSON gerado"
echo "   5. No servidor, execute: rclone config"
echo "   6. Quando pedir 'config_token>', cole o token"
echo ""

read -p "Deseja iniciar a configuração interativa agora? (s/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    rclone config
fi

echo ""
echo "3. Testando conexão..."
if rclone listremotes | grep -q "^gdrive:"; then
    echo "   Remote 'gdrive' configurado!"
    echo ""
    echo "   Testando acesso..."
    rclone about gdrive: 2>/dev/null && echo "   Conexão OK!" || echo "   ERRO: Não foi possível conectar"
else
    echo "   AVISO: Remote 'gdrive' ainda não configurado."
    echo "   Execute 'rclone config' manualmente."
fi

echo ""
echo "4. Configurando backup automático..."
echo ""

read -p "Deseja configurar backup automático diário às 4h? (s/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    # Remover cron antigo e adicionar novo
    (crontab -l 2>/dev/null | grep -v "backup-gdrive.sh"; echo "0 4 * * * /opt/valheim-server/backup-gdrive.sh >> /var/log/valheim-backup.log 2>&1") | crontab -
    echo "   Cron configurado! Backup diário às 4h da manhã."
    echo "   Logs em: /var/log/valheim-backup.log"
else
    echo "   Para configurar manualmente depois:"
    echo "   crontab -e"
    echo "   0 4 * * * /opt/valheim-server/backup-gdrive.sh"
fi

echo ""
echo "=== Configuração concluída! ==="
echo ""
echo "Para fazer um backup manual:"
echo "  /opt/valheim-server/backup-gdrive.sh"
echo ""
echo "Para ver backups no Google Drive:"
echo "  rclone ls gdrive:valheim-backups/"

#!/bin/bash
# =============================================================================
# Script de criacao do usuario dedicado para o servidor Valheim
# Este script deve ser executado UMA VEZ como root na VPS
# =============================================================================

set -e

VALHEIM_USER="valheim"
VALHEIM_HOME="/home/${VALHEIM_USER}"
SSH_DIR="${VALHEIM_HOME}/.ssh"

echo "=== Configurando usuario dedicado para Valheim Server ==="

# Verificar se esta rodando como root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERRO: Este script deve ser executado como root"
    exit 1
fi

# Criar usuario se nao existir
if id "${VALHEIM_USER}" &>/dev/null; then
    echo "Usuario ${VALHEIM_USER} ja existe"
else
    echo "Criando usuario ${VALHEIM_USER}..."
    useradd -m -s /bin/bash "${VALHEIM_USER}"
    echo "Usuario criado com sucesso"
fi

# Criar diretorio .ssh
echo "Configurando diretorio SSH..."
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

# Gerar par de chaves SSH se nao existir
if [ ! -f "${SSH_DIR}/id_rsa" ]; then
    echo "Gerando par de chaves SSH..."
    ssh-keygen -t rsa -b 4096 -f "${SSH_DIR}/id_rsa" -N "" -C "valheim-server-deploy"
    echo "Chaves SSH geradas"
else
    echo "Chaves SSH ja existem"
fi

# Configurar authorized_keys (copiar chave publica para acesso)
if [ ! -f "${SSH_DIR}/authorized_keys" ]; then
    cp "${SSH_DIR}/id_rsa.pub" "${SSH_DIR}/authorized_keys"
fi
chmod 600 "${SSH_DIR}/authorized_keys"
chmod 600 "${SSH_DIR}/id_rsa"
chmod 644 "${SSH_DIR}/id_rsa.pub"

# Ajustar proprietario
chown -R "${VALHEIM_USER}:${VALHEIM_USER}" "${VALHEIM_HOME}"

# Instalar Docker se nao estiver instalado
if ! command -v docker &>/dev/null; then
    echo "Instalando Docker..."
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    echo "Docker instalado com sucesso"
else
    echo "Docker ja esta instalado"
fi

# Adicionar usuario ao grupo docker
echo "Adicionando ${VALHEIM_USER} ao grupo docker..."
usermod -aG docker "${VALHEIM_USER}"

# Criar diretorio do projeto com permissoes corretas
echo "Criando diretorios do projeto..."
mkdir -p /opt/valheim-server/{config,data,backups}
chown -R "${VALHEIM_USER}:${VALHEIM_USER}" /opt/valheim-server

# Permitir usuario executar comandos especificos sem senha (opcional para backups)
echo "Configurando sudoers..."
cat > /etc/sudoers.d/valheim << 'EOF'
# Permite usuario valheim reiniciar o servico e gerenciar firewall
valheim ALL=(ALL) NOPASSWD: /usr/sbin/ufw
valheim ALL=(ALL) NOPASSWD: /bin/systemctl restart docker
valheim ALL=(ALL) NOPASSWD: /bin/systemctl status docker
EOF
chmod 440 /etc/sudoers.d/valheim

echo ""
echo "=== Configuracao concluida! ==="
echo ""
echo "IMPORTANTE: Copie a chave privada para sua maquina local:"
echo ""
echo "  scp root@SEU_IP:${SSH_DIR}/id_rsa ~/.ssh/valheim_rsa"
echo ""
echo "Ou exiba a chave para copiar manualmente:"
echo ""
cat "${SSH_DIR}/id_rsa"
echo ""
echo "=============================================="
echo ""
echo "Depois, atualize seu terraform.tfvars:"
echo "  ssh_user = \"valheim\""
echo "  ssh_private_key_path = \"~/.ssh/valheim_rsa\""
echo ""

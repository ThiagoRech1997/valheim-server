terraform {
  required_version = ">= 1.0.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Variáveis
variable "server_ip" {
  description = "IP público da VPS"
  type        = string
}

variable "ssh_user" {
  description = "Usuário SSH"
  type        = string
  default     = "root"
}

variable "ssh_private_key_path" {
  description = "Caminho para a chave SSH privada"
  type        = string
}

variable "valheim_server_name" {
  description = "Nome do servidor Valheim"
  type        = string
  default     = "My Valheim Server"
}

variable "valheim_world_name" {
  description = "Nome do mundo Valheim"
  type        = string
  default     = "MyWorld"
}

variable "valheim_password" {
  description = "Senha do servidor (mínimo 5 caracteres)"
  type        = string
  sensitive   = true
}

# Recurso para copiar arquivos e configurar o servidor
resource "null_resource" "valheim_server" {
  triggers = {
    always_run = timestamp()
  }

  # Conexão SSH
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.server_ip
  }

  # Criar diretório do projeto
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /opt/valheim-server/config",
      "mkdir -p /opt/valheim-server/data",
      "mkdir -p /opt/valheim-server/backups"
    ]
  }

  # Copiar docker-compose.yml
  provisioner "file" {
    source      = "${path.module}/../docker/docker-compose.yml"
    destination = "/opt/valheim-server/docker-compose.yml"
  }

  # Copiar script de backup
  provisioner "file" {
    source      = "${path.module}/../scripts/backup.sh"
    destination = "/opt/valheim-server/backup.sh"
  }

  # Criar arquivo .env e iniciar o servidor
  provisioner "remote-exec" {
    inline = [
      # Criar arquivo .env com as variáveis
      "cat > /opt/valheim-server/.env << 'EOF'",
      "SERVER_NAME=${var.valheim_server_name}",
      "WORLD_NAME=${var.valheim_world_name}",
      "SERVER_PASS=${var.valheim_password}",
      "EOF",

      # Configurar permissões
      "chmod +x /opt/valheim-server/backup.sh",
      "chmod 600 /opt/valheim-server/.env",

      # Configurar firewall (UFW)
      "ufw allow 2456:2458/udp || true",
      "ufw allow 2456:2458/tcp || true",

      # Iniciar o container
      "cd /opt/valheim-server && docker compose down || true",
      "cd /opt/valheim-server && docker compose pull",
      "cd /opt/valheim-server && docker compose up -d",

      # Configurar backup automático via cron (diário às 4h)
      "(crontab -l 2>/dev/null | grep -v valheim-backup; echo '0 4 * * * /opt/valheim-server/backup.sh') | crontab -"
    ]
  }
}

# Outputs
output "server_ip" {
  value       = var.server_ip
  description = "IP do servidor Valheim"
}

output "connection_info" {
  value       = "Conecte no Valheim usando: ${var.server_ip}:2456"
  description = "Informação de conexão"
}

output "server_location" {
  value       = "/opt/valheim-server"
  description = "Localização dos arquivos no servidor"
}

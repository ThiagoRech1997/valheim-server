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
  description = "Usuário SSH (recomendado: valheim)"
  type        = string
  default     = "valheim"
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

# Modificadores de Gameplay
variable "world_preset" {
  description = "Preset do mundo: normal, casual, easy, hard, hardcore, immersive, hammer"
  type        = string
  default     = "normal"
}

variable "raid_modifier" {
  description = "Modificador de raids: none, muchless, less, default, more, muchmore"
  type        = string
  default     = "default"
}

variable "portal_modifier" {
  description = "Modificador de portais: casual, default, hard"
  type        = string
  default     = "default"
}

variable "death_penalty" {
  description = "Penalidade de morte: casual, veryeasy, easy, default, hard, hardcore"
  type        = string
  default     = "default"
}

variable "resource_modifier" {
  description = "Modificador de recursos: muchless, less, default, more, muchmore, most"
  type        = string
  default     = "default"
}

variable "enemy_modifier" {
  description = "Modificador de inimigos: none, veryless, less, default, more, muchmore"
  type        = string
  default     = "default"
}

variable "combat_modifier" {
  description = "Modificador de combate: veryeasy, easy, default, hard, veryhard"
  type        = string
  default     = "default"
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

  # Copiar script de backup local
  provisioner "file" {
    source      = "${path.module}/../scripts/backup.sh"
    destination = "/opt/valheim-server/backup.sh"
  }

  # Copiar scripts do Google Drive
  provisioner "file" {
    source      = "${path.module}/../scripts/backup-gdrive.sh"
    destination = "/opt/valheim-server/backup-gdrive.sh"
  }

  provisioner "file" {
    source      = "${path.module}/../scripts/setup-gdrive.sh"
    destination = "/opt/valheim-server/setup-gdrive.sh"
  }

  provisioner "file" {
    source      = "${path.module}/../scripts/restore-gdrive.sh"
    destination = "/opt/valheim-server/restore-gdrive.sh"
  }

  # Criar arquivo .env e iniciar o servidor
  provisioner "remote-exec" {
    inline = [
      # Criar arquivo .env com as variáveis
      "cat > /opt/valheim-server/.env << 'EOF'",
      "SERVER_NAME=${var.valheim_server_name}",
      "WORLD_NAME=${var.valheim_world_name}",
      "SERVER_PASS=${var.valheim_password}",
      "WORLD_PRESET=${var.world_preset}",
      "RAID_MODIFIER=${var.raid_modifier}",
      "PORTAL_MODIFIER=${var.portal_modifier}",
      "DEATH_PENALTY=${var.death_penalty}",
      "RESOURCE_MODIFIER=${var.resource_modifier}",
      "ENEMY_MODIFIER=${var.enemy_modifier}",
      "COMBAT_MODIFIER=${var.combat_modifier}",
      "EOF",

      # Configurar permissões
      "chmod +x /opt/valheim-server/backup.sh",
      "chmod +x /opt/valheim-server/backup-gdrive.sh",
      "chmod +x /opt/valheim-server/setup-gdrive.sh",
      "chmod +x /opt/valheim-server/restore-gdrive.sh",
      "chmod 600 /opt/valheim-server/.env",

      # Configurar firewall (UFW) - usando sudo para usuario nao-root
      "sudo ufw allow 2456:2458/udp || true",
      "sudo ufw allow 2456:2458/tcp || true",

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

output "gdrive_setup" {
  value       = "Para configurar backup no Google Drive: ssh ${var.ssh_user}@${var.server_ip} '/opt/valheim-server/setup-gdrive.sh'"
  description = "Comando para configurar Google Drive"
}

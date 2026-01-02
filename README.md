# Servidor Valheim Dedicado

Infraestrutura para hospedar um servidor Valheim dedicado usando Terraform e Docker.

## Requisitos

- Terraform >= 1.0.0
- VPS com Ubuntu Server
- Acesso SSH à VPS (como root para setup inicial)

## Estrutura do Projeto

```
valheim-server/
├── .github/
│   └── workflows/
│       └── deploy.yml            # GitHub Actions para deploy automático
├── terraform/
│   ├── main.tf                   # Configuração principal do Terraform
│   └── terraform.tfvars.example  # Exemplo de variáveis
├── docker/
│   └── docker-compose.yml        # Configuração do container Valheim
├── scripts/
│   ├── setup-user.sh             # Criar usuário dedicado na VPS
│   ├── backup.sh                 # Script de backup manual (local)
│   ├── setup-gdrive.sh           # Configurar backup no Google Drive
│   ├── backup-gdrive.sh          # Backup para Google Drive
│   ├── restore-gdrive.sh         # Restaurar backup do Google Drive
│   └── upload-world.sh           # Upload de mundo local para servidor
└── README.md
```

## Configuração Inicial

### 1. Configurar usuário dedicado na VPS (recomendado)

Por segurança, criamos um usuário `valheim` ao invés de usar `root`:

```bash
# Conectar como root na VPS
ssh root@SEU_IP

# Baixar e executar o script de setup
curl -sL https://raw.githubusercontent.com/SEU_USUARIO/valheim-server/main/scripts/setup-user.sh | bash

# Ou, se já clonou o repo:
bash scripts/setup-user.sh
```

O script irá:
- Criar usuário `valheim` com acesso ao Docker
- Instalar Docker e Docker Compose (se necessário)
- Gerar par de chaves SSH para deploy
- Criar diretórios do projeto em `/opt/valheim-server`

**Importante**: Copie a chave privada gerada para sua máquina local:

```bash
scp root@SEU_IP:/home/valheim/.ssh/id_rsa ~/.ssh/valheim_rsa
chmod 600 ~/.ssh/valheim_rsa
```

### 2. Configurar variáveis do Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edite o arquivo `terraform.tfvars`:

```hcl
server_ip            = "SEU_IP_PUBLICO"
ssh_user             = "valheim"
ssh_private_key_path = "~/.ssh/valheim_rsa"
valheim_server_name  = "Meu Servidor Valheim"
valheim_world_name   = "MeuMundo"
valheim_password     = "senha_segura"  # mínimo 5 caracteres
```

### 3. Deploy do servidor

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Modificadores de Gameplay

Você pode personalizar a dificuldade e mecânicas do jogo. Adicione ao `terraform.tfvars`:

```hcl
# Preset de mundo: normal, casual, easy, hard, hardcore, immersive, hammer
world_preset = "normal"

# Raids: none, muchless, less, default, more, muchmore
raid_modifier = "default"

# Portais: casual (tudo), default (sem minério), hard (sem itens)
portal_modifier = "default"

# Penalidade de morte: casual, veryeasy, easy, default, hard, hardcore
death_penalty = "default"

# Recursos: muchless, less, default, more, muchmore, most
resource_modifier = "default"

# Inimigos: none, veryless, less, default, more, muchmore
enemy_modifier = "default"

# Combate: veryeasy, easy, default, hard, veryhard
combat_modifier = "default"
```

## Deploy Automático com GitHub Actions

O repositório inclui um workflow que faz deploy automaticamente quando você faz push para `main`.

### Configurar GitHub Actions

1. No GitHub, vá em **Settings > Secrets and variables > Actions**

2. Adicione os **Secrets**:
   - `SERVER_IP`: IP da sua VPS
   - `SSH_PRIVATE_KEY`: Conteúdo da chave `~/.ssh/valheim_rsa`
   - `VALHEIM_PASSWORD`: Senha do servidor

3. Adicione as **Variables**:
   - `VALHEIM_SERVER_NAME`: Nome do servidor
   - `VALHEIM_WORLD_NAME`: Nome do mundo

Agora, a cada push em `main` (em arquivos de terraform/, docker/ ou scripts/), o deploy será feito automaticamente.

Você também pode disparar manualmente em **Actions > Deploy Valheim Server > Run workflow**.

## Conectando ao Servidor

No jogo Valheim:
1. Clique em **Join Game**
2. Selecione **Add Server**
3. Digite: `SEU_IP:2456`
4. Clique em **Connect**
5. Digite a senha configurada

## Gerenciamento

### Comandos úteis (executar via SSH na VPS)

```bash
# Ver logs do servidor
cd /opt/valheim-server
docker compose logs -f

# Reiniciar servidor
docker compose restart

# Parar servidor
docker compose down

# Iniciar servidor
docker compose up -d

# Ver status
docker compose ps
```

### Portas utilizadas

| Porta | Protocolo | Descrição |
|-------|-----------|-----------|
| 2456  | UDP/TCP   | Game port |
| 2457  | UDP/TCP   | Query port |
| 2458  | UDP/TCP   | (reservada) |

## Subir Mundo Local (Save Existente)

Se você já tem um mundo local que joga no seu PC, pode enviá-lo para o servidor.

### Localização dos saves no Windows

```
C:\Users\SEU_USUARIO\AppData\LocalLow\IronGate\Valheim\worlds_local\
```

Dentro dessa pasta você terá arquivos como:
- `MeuMundo.fwl` - Metadados do mundo
- `MeuMundo.db` - Dados do mundo

### Usando o script de upload

```bash
# No Git Bash (Windows) ou terminal Linux/Mac
cd scripts
chmod +x upload-world.sh

./upload-world.sh SEU_IP "/c/Users/SeuUser/AppData/LocalLow/IronGate/Valheim/worlds_local/MeuMundo"
```

O script vai:
1. Parar o servidor
2. Fazer backup do mundo atual
3. Enviar seus arquivos
4. Reiniciar o servidor

### Upload manual via SCP

```bash
# Parar o servidor
ssh valheim@SEU_IP "cd /opt/valheim-server && docker compose stop"

# Enviar arquivos
scp MeuMundo.fwl MeuMundo.db valheim@SEU_IP:/tmp/

# Copiar para o volume Docker
ssh valheim@SEU_IP "docker run --rm -v valheim-server_valheim-config:/config -v /tmp:/upload alpine sh -c 'cp /upload/MeuMundo.* /config/worlds_local/ && chown -R 1000:1000 /config/worlds_local'"

# Atualizar nome do mundo no .env
ssh valheim@SEU_IP "sed -i 's/WORLD_NAME=.*/WORLD_NAME=MeuMundo/' /opt/valheim-server/.env"

# Reiniciar servidor
ssh valheim@SEU_IP "cd /opt/valheim-server && docker compose up -d"
```

**Importante**: O nome do mundo no `WORLD_NAME` do arquivo `.env` deve corresponder exatamente ao nome dos seus arquivos (sem extensão).

## Backups

### Backup Local

- **Automático**: O container faz backup a cada 2 horas
- **Manual**: Execute `/opt/valheim-server/backup.sh`

Backups locais são armazenados em:
- Container: `/config/backups`
- Host: `/opt/valheim-server/backups`

### Backup no Google Drive (recomendado)

Para backups na nuvem, configure o Google Drive:

```bash
# Na VPS, execute o script de configuração
cd /opt/valheim-server
./setup-gdrive.sh
```

O script vai:
1. Instalar `rclone` (se necessário)
2. Guiar você na autenticação com Google
3. Opcionalmente configurar backup automático diário às 4h

**Comandos de backup no Google Drive:**

```bash
# Fazer backup manual
./backup-gdrive.sh

# Listar backups disponíveis
rclone ls gdrive:valheim-backups/

# Restaurar um backup
./restore-gdrive.sh valheim_backup_20240115_040000.tar.gz

# Ou restaurar interativamente (lista backups disponíveis)
./restore-gdrive.sh
```

O backup no Google Drive:
- Mantém os últimos 10 backups automaticamente
- Remove backups locais após upload (economiza espaço)
- Cria backup de segurança antes de restaurar

## Recursos do Servidor

A configuração está otimizada para uma VPS típica:
- **CPU**: 2 cores
- **RAM**: Limite de 6GB para o container (2GB reservados para o sistema)
- **Disco**: Volumes Docker persistentes

## Troubleshooting

### Servidor não aparece na lista
- Verifique se as portas 2456-2458 estão abertas no firewall
- Confirme que `SERVER_PUBLIC=true` está configurado

### Erro de conexão
- A senha deve ter no mínimo 5 caracteres
- Aguarde alguns minutos após iniciar (o servidor demora para carregar)

### Ver logs de erro
```bash
docker compose logs --tail=100
```

### Problemas com permissão SSH
Se usando o usuário `valheim` e tiver problemas:
```bash
# Verificar se a chave está correta
ssh -i ~/.ssh/valheim_rsa valheim@SEU_IP

# Verificar permissões da chave
chmod 600 ~/.ssh/valheim_rsa
```

## Imagem Docker

Utilizamos a imagem [lloesche/valheim-server](https://github.com/lloesche/valheim-server-docker) que oferece:
- Atualizações automáticas do jogo
- Backups automáticos
- Suporte a crossplay
- Configuração via variáveis de ambiente

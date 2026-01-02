# Servidor Valheim Dedicado

Infraestrutura para hospedar um servidor Valheim dedicado usando Terraform e Docker.

## Requisitos

- Terraform >= 1.0.0
- VPS com Ubuntu Server e Docker + Docker Compose instalados
- Acesso SSH à VPS

## Estrutura do Projeto

```
valheim-server/
├── terraform/
│   ├── main.tf                    # Configuração principal do Terraform
│   └── terraform.tfvars.example   # Exemplo de variáveis
├── docker/
│   └── docker-compose.yml         # Configuração do container Valheim
├── scripts/
│   └── backup.sh                  # Script de backup manual
└── README.md
```

## Configuração

### 1. Configurar variáveis do Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edite o arquivo `terraform.tfvars` com suas configurações:

```hcl
server_ip            = "SEU_IP_PUBLICO"
ssh_user             = "root"
ssh_private_key_path = "~/.ssh/id_rsa"
valheim_server_name  = "Meu Servidor Valheim"
valheim_world_name   = "MeuMundo"
valheim_password     = "senha_segura"  # mínimo 5 caracteres
```

### 2. Deploy do servidor

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

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

# Backup manual
./backup.sh
```

### Portas utilizadas

| Porta | Protocolo | Descrição |
|-------|-----------|-----------|
| 2456  | UDP/TCP   | Game port |
| 2457  | UDP/TCP   | Query port |
| 2458  | UDP/TCP   | (reservada) |

## Backups

- **Automático**: O container faz backup a cada 2 horas
- **Cron**: Backup diário às 4h da manhã via script
- **Manual**: Execute `/opt/valheim-server/backup.sh`

Backups são armazenados em:
- Container: `/config/backups`
- Host: `/opt/valheim-server/backups`

## Recursos do Servidor

A configuração está otimizada para sua VPS:
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

## Imagem Docker

Utilizamos a imagem [lloesche/valheim-server](https://github.com/lloesche/valheim-server-docker) que oferece:
- Atualizações automáticas do jogo
- Backups automáticos
- Suporte a crossplay
- Configuração via variáveis de ambiente

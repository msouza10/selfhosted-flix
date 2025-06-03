#!/usr/bin/env bash

set -euo pipefail

# variables general
BANNER_DIR="banners/ascii_fonts"
SERVICES_HOSTS="traefik radarr sonarr jellyfin qbittorrent dnsmasq heimdall"
REQUIREMENTS="requirements-pkgs.txt"
DOCKER_ROOT_DIR="$(docker info | grep "Docker Root Dir" | awk '{print $4}')"

# variables for env
TZ_DEFAULT="$(timedatectl show --property=Timezone --value)"
DOMAIN_DEFAULT="localhost"
PORT_USED_DEFAULT=":80"
PORT_USED_DEFAULT_SSL=":443"
STORAGE_RADARR_DEFAULT="/opt/radarr-media"
STORAGE_SONARR_DEFAULT="/opt/sonarr-media"
DNSMASQ_DIR_DEFAULT="/opt/dnsmasq/dnsmasq.conf" # This is a file path.
USER_TRAEFIK_DEFAULT="admin"
PASS_TRAEFIK_RANDOM="$(openssl rand -base64 12)"

# CLI mode variables
CLI_MODE=false
SKIP_CONFIRM=false
QUIET_MODE=false

# color builder and color check
if [[ -t 1 ]]; then
  RED="\033[1;31m"; BLUE="\033[1;34m"; YELLOW="\033[1;33m"; GREEN="\033[1;32m"; WHITE="\033[1;37m"
  RESET="\033[0m" 
else
  RED=; BLUE=; YELLOW=; GREEN=; RESET=
fi

# prints models and logs
if [[ ! -d "logs" ]]; then
  mkdir -p logs
fi

logfile="logs/initial-$(date +%Y%m%d).log" && touch $logfile

log() { printf "${BLUE}[INFO] - $(date '+%H:%M:%S') - $* ${RESET} \n" | tee -a $logfile ; } 
err() { printf "${RED}[ERROR] - $(date '+%H:%M:%S') - $* ${RESET} \n" | tee -a $logfile ; } 
war() { printf "${YELLOW}[WARN] - $(date '+%H:%M:%S') - $* ${RESET} \n" | tee -a $logfile ; } 
print() { printf "${WHITE}[ECHO] - $(date '+%H:%M:%S') - $* ${RESET} \n" | tee -a $logfile ; } 
ask() { local msg; msg="${WHITE}[ASK] - $(date '+%H:%M:%S') - $*${RESET}"; printf "%b\n" "$msg"; read -rp "" input; } 
ask_secret() { local msg; msg="${WHITE}[ASK-SECRET] - $(date '+%H:%M:%S') - $*${RESET}"; printf "%b\n" "$msg"; read -rsp "" input; printf "\n";}

# root check
if [[ $EUID -ne 0 ]]; then
  err "Inicie como root (sudo)."
  exit 1
else
  log "Iniciado como root."
fi

# Rollback function for error handling
rollback() {
    if [[ -f "$backup_hosts_file" ]]; then
        err "Erro detectado, revertendo alterações..."
        cp "$backup_hosts_file" /etc/hosts
        log "Arquivo /etc/hosts restaurado"
    fi
    if command -v docker &>/dev/null; then
        docker-compose down 2>/dev/null || true
    fi
    exit 1
}

# Set trap after functions are defined
trap rollback ERR
trap 'err "Interrompido pelo usuário."; exit 0' INT

# check requirements
mapfile -t REQUIREMENTS < <(grep -vE '^\s*(#|$)' "$REQUIREMENTS")

log "Verificando requisitos..."

for cmd in "${REQUIREMENTS[@]}"; do
    if ! command -v $cmd &>/dev/null; then
        err "$cmd não encontrado, necessário para prosseguir. Abortando..."
        exit 1
    else
        log "$cmd encontrado."
    fi
done


log "Verificando conexão com a internet..."

# check connection
if ! ping -c 3 google.com &>/dev/null; then
    err "Sem conexão com a internet, necessário para prosseguir. Abortando..."
    exit 1
else
    log "Conexão com a internet estabelecida."
fi

# functions
  # validations on domain, port and config dir
validate_domain() {
    local domain="$1"
    if ! echo "$domain" | grep -qP '^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$'; then
        err "Domínio inválido: $domain."
        exit 1
    fi
}

validate_port() {
    local port="$1"
    local port_num="${port#:}"
    if ! [[ "$port_num" =~ ^[0-9]+$ ]] || (( port_num < 1 || port_num > 65535 )); then
        err "Porta inválida: $port"
        exit 1
    fi
}

validate_config_dir() {
    local dir="$1"
    if [[ ! -d "$dir" || ! -f "$dir/dnsmasq.conf" ]]; then
        err "Diretório de configuração '$dir' não encontrado ou arquivo '$dir/dnsmasq.conf' não encontrado. Abortando..."
        exit 1
    fi
}

validate_storage_dir() {
    local dir="$1"

    if [[ ! -d "$dir" ]] || ! [[ "$dir" =~ ^/[a-zA-Z0-9/_-]+$ ]]; then
        err "Diretório de configuração '$dir' não encontrado ou inválido."
        exit 1
    fi
}

get_container_info_simple() {
    local cname="$1"
    local ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$cname" 2>/dev/null)
    [ -z "$ip" ] && ip="N/A"

    local portas=$(docker port "$cname" 2>/dev/null | paste -sd "," -)
    [ -z "$portas" ] && portas="Nenhuma"

    local ouvindo=$(docker exec "$cname" sh -c 'ss -tuln 2>/dev/null || netstat -tuln 2>/dev/null' 2>/dev/null | awk 'NR>1{print $5}' | awk -F: '{print $NF}' | sort -n | uniq | paste -sd "," -)
    [ -z "$ouvindo" ] && ouvindo="Indisponível"

    printf "IP: %s - Portas mapeadas: %s - Portas ouvindo: %s\n" "$ip" "$portas" "$ouvindo"
}

# check dns and disable dns in router
mapfile -t NAMES_DNSLOCAL < <(sudo ss -tulpn | awk '/:53 / && /LISTEN/ {print $NF}' | sed -E 's/users:\(\("([^"]+)",.*/\1/' | sort | uniq)
check_local_dns() {
  if [[ "${NAMES_DNSLOCAL[0]}" == "systemd-resolve" ]]; then
    log "systemd-resolve encontrado, desabilitando..."
    sudo systemctl stop systemd-resolved
    sudo systemctl disable systemd-resolved
    sudo systemctl unmask systemd-resolved
    log "systemd-resolved desabilitado."
  fi

  if [[ ${#NAMES_DNSLOCAL[@]} -gt 1 ]]; then
    war "Mais de um Serviço de DNS local encontrado, rodando na porta 53."
    ask "Qual serviço de DNS local você deseja desabilitar (ex: dnsmasq)?"
    for name in "${NAMES_DNSLOCAL[@]}"; do
        print "-[$name]"
            if [[ "$name" == "$input" ]]; then
                log "Desabilitando DNS local..."
                sudo systemctl stop $name
                sudo systemctl disable $name
                sudo systemctl unmask $name
                log "DNS local desabilitado."
            fi
    done
  else
    log "Apenas um Serviço de DNS local encontrado, rodando na porta 53."
    ask "Deseja realmente desabilitar o DNS local [s/N]?"
    if [[ "$input" =~ ^[sS]$ ]]; then
      log "Desabilitando DNS local..."
      sudo systemctl stop $NAMES_DNSLOCAL
      sudo systemctl disable $NAMES_DNSLOCAL
      sudo systemctl unmask $NAMES_DNSLOCAL
      log "DNS local desabilitado."
    fi
  fi
}

# CLI argument parsing
show_help() {
    cat << EOF
Selfhosted-Flix - Configure sua Netflix pessoal automaticamente

USO:
    $0 [OPÇÕES]

OPÇÕES:
    -h, --help                  Mostra esta ajuda
    -y, --yes                   Pula todas as confirmações
    -q, --quiet                 Modo silencioso (menos output)
    --cli                       Modo CLI (não interativo)
    
    --tz TIMEZONE               Define timezone (ex: America/Sao_Paulo)
    --domain DOMAIN             Define domínio (ex: flix.local)
    --port PORT                 Define porta (ex: :80, :443, :8080)
    --dns-mode MODE             DNS mode: hosts, dnsmasq, none
    --storage-radarr PATH       Caminho para armazenamento Radarr
    --storage-sonarr PATH       Caminho para armazenamento Sonarr
    --traefik-user USER         Usuário do Traefik
    --traefik-pass PASS         Senha do Traefik
    
    --preset PRESET             Usar preset de configuração:
                                - minimal: Configuração mínima local
                                - production: Configuração para produção
                                - development: Configuração para desenvolvimento

EXEMPLOS:
    # Instalação interativa padrão
    $0
    
    # Instalação automática com configurações personalizadas
    $0 --cli --domain flix.home --port :443 --dns-mode dnsmasq -y
    
    # Usar preset de desenvolvimento
    $0 --preset development -y
    
    # Instalação silenciosa com todas as opções
    $0 --cli --tz America/Sao_Paulo --domain media.local --port :80 \\
       --dns-mode hosts --storage-radarr /media/movies --storage-sonarr /media/series \\
       --traefik-user admin --traefik-pass MySecurePass123 -q -y

EOF
    exit 0
}

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -y|--yes)
            SKIP_CONFIRM=true
            shift
            ;;
        -q|--quiet)
            QUIET_MODE=true
            shift
            ;;
        --cli)
            CLI_MODE=true
            shift
            ;;
        --tz)
            TZ="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --port)
            PORT_USED="$2"
            shift 2
            ;;
        --dns-mode)
            case "$2" in
                hosts) DNSMASQ="0" ;;
                dnsmasq) DNSMASQ="1" ;;
                none) DNSMASQ="0" ;;
                *) err "Modo DNS inválido: $2"; exit 1 ;;
            esac
            shift 2
            ;;
        --storage-radarr)
            STORAGE_RADARR="$2"
            shift 2
            ;;
        --storage-sonarr)
            STORAGE_SONARR="$2"
            shift 2
            ;;
        --traefik-user)
            USER_TRAEFIK="$2"
            shift 2
            ;;
        --traefik-pass)
            PASS_TRAEFIK_RANDOM="$2"
            shift 2
            ;;
        --preset)
            case "$2" in
                minimal)
                    DOMAIN="localhost"
                    PORT_USED=":80"
                    DNSMASQ="0"
                    STORAGE_RADARR="/opt/radarr-media"
                    STORAGE_SONARR="/opt/sonarr-media"
                    USER_TRAEFIK="admin"
                    log "Usando preset: minimal (configuração local mínima)"
                    ;;
                production)
                    PORT_USED=":443"
                    DNSMASQ="1"
                    STORAGE_RADARR="/mnt/media/movies"
                    STORAGE_SONARR="/mnt/media/series"
                    log "Usando preset: production (requer domínio válido)"
                    ;;
                development)
                    DOMAIN="dev.local"
                    PORT_USED=":8080"
                    DNSMASQ="0"
                    STORAGE_RADARR="/tmp/radarr-dev"
                    STORAGE_SONARR="/tmp/sonarr-dev"
                    USER_TRAEFIK="dev"
                    log "Usando preset: development"
                    ;;
                *)
                    err "Preset inválido: $2"
                    exit 1
                    ;;
            esac
            shift 2
            ;;
        *)
            err "Opção desconhecida: $1"
            show_help
            ;;
    esac
done

# Modify print functions for quiet mode
if [[ "$QUIET_MODE" == true ]]; then
    print() { :; }  # No-op function
    war() { printf "${YELLOW}[WARN] $*${RESET}\n" >&2; }  # Still show warnings
fi

# inicialization
print "Iniciando script..."
sleep 1
print "1..."
sleep 1
print "2..."
sleep 1
print "3..."
sleep 1

# check if there are banners in the banners directory
if [[ -d $BANNER_DIR ]] && find "$BANNER_DIR" -type f | grep -q .; then
  banner=$(find "$BANNER_DIR" -type f | shuf -n1)
  printf "${RED}"
  cat "$banner"
  printf "${RESET}"
else
  war "Sem banners encontrados em $BANNER_DIR."
fi

printf "\n${RED}🎬  Powered by:\n"
printf "    ├── Jellyfin\n"
printf "    ├── Radarr\n"
printf "    ├── Sonarr\n"
printf "    ├── Heimdall\n" # Corrected spelling
printf "    ├── qBittorrent\n"
printf "    └── Traefik\n${RESET}\n"

printf "${GREEN}🐧 Coded by:msouza10 ${RESET}\n" 

echo

print "Iniciando configuração do ambiente...\n"

# Skip interactive mode if CLI mode is enabled
if [[ "$CLI_MODE" == true ]]; then
    log "Modo CLI ativado - pulando configuração interativa"
    
    # Validate required parameters
    : ${TZ:=$TZ_DEFAULT}
    : ${DOMAIN:=$DOMAIN_DEFAULT}
    : ${PORT_USED:=$PORT_USED_DEFAULT}
    : ${STORAGE_RADARR:=$STORAGE_RADARR_DEFAULT}
    : ${STORAGE_SONARR:=$STORAGE_SONARR_DEFAULT}
    : ${USER_TRAEFIK:=$USER_TRAEFIK_DEFAULT}
    : ${DNSMASQ:="0"}
    : ${DNSMASQ_DIR:=$DNSMASQ_DIR_DEFAULT}
    
    # Validate parameters
    if [[ "$DOMAIN" != "localhost" ]]; then
        validate_domain "$DOMAIN" || exit 1
    fi
    validate_port "$PORT_USED" || exit 1
    
    # Create directories if needed
    mkdir -p "$STORAGE_RADARR" "$STORAGE_SONARR"
    
    # Generate password if not provided
    if [[ -z "${PASS_TRAEFIK_RANDOM:-}" ]]; then
        PASS_TRAEFIK_RANDOM="$(openssl rand -base64 12)"
        log "Senha Traefik gerada automaticamente"
    fi
    
    PASS_TRAEFIK=$(htpasswd -nbB "$USER_TRAEFIK" "$PASS_TRAEFIK_RANDOM" | cut -d ':' -f2 | sed -e 's/\$/\$\$/g')
    
    # Skip to configuration generation
    goto_config_generation=true
else
    goto_config_generation=false
fi

if [[ "$goto_config_generation" == false ]]; then
    print "Configuração interativa ativada..."
fi

sleep 3
clear

print "Fuso horário a ser utilizado:\n"

print "1 - Padrão da sua máquina ($TZ_DEFAULT)"
print "2 - Escolher outro\n"

ask "Selecione [1/2]: "

case "$input" in
  1)
    TZ="$TZ_DEFAULT"
    log "Fuso horário selecionado: $TZ."
    ;;
  2)
    mapfile -t zones < <(timedatectl list-timezones)
    PS3=$'Escolha um fuso horário (número) ou 0 para sair: '
    select zone in "${zones[@]}"; do
      if [[ "$REPLY" == "0" ]]; then
        war "Seleção de fuso horário cancelada. Usando padrão: $TZ_DEFAULT."
        TZ="$TZ_DEFAULT" # Ensure TZ is set to default if cancelled
        log "Fuso horário selecionado: $TZ."
        break
      elif (( REPLY >= 1 && REPLY <= ${#zones[@]} )); then
        TZ="$zone"
        log "Fuso horário selecionado: $TZ."
        break
      else
        err "Opção inválida. Tente novamente."
      fi
    done
    ;;
  *)
    war "Opção inválida. Saindo." >&2
    exit 1
    ;;
esac

print "Qual domínio deve ser utilizado?\n"

print "1 - Domínio sugerido ($DOMAIN_DEFAULT)"
print "2 - Escolher outro\n"

ask "Selecione [1/2]: "

case "$input" in
    1)
    DOMAIN="$DOMAIN_DEFAULT"
    log "Domínio selecionado: $DOMAIN."
    ;;
    2)
    ask "Digite seu domínio (ex: exemplo.com):"
    if ! validate_domain "$input"; then
      war "O domínio '$input' é inválido. Tente novamente."
      exit 1
    fi
    DOMAIN=$input
    log "Domínio selecionado: $DOMAIN."
    ;;
    *)
    war "Opção inválida. Saindo." >&2
    exit 1
    ;;
esac

print "Para este domínio funcionar, é necessário que sua máquina o reconheça de alguma forma:\n"

print "1 - Adicionar ao arquivo /etc/hosts da sua máquina"
print "2 - Subir um contêiner dnsmasq para resolução local de DNS"
print "3 - Não adicionar (você precisará configurar a resolução DNS manualmente)\n"

war "ao selecionar a opção 1, as entradas de DNS serão adicionadas ao arquivo /etc/hosts da sua máquina, funcionando apenas na maquina atual, sera necessario adicionar as entradas DNS ao seu servidor DNS local ou ao arquivo hosts de cada máquina cliente."
war "ao selecionar a opção 2, o seu resolver interno substituirá o DNS do seu roteador ou servidor DNS local, outras maquinas precisarão configurar o DNS para o seu domínio."
war "ao selecionar a opção 3, você precisará configurar a resolução DNS manualmente."

ask "Selecione [1/3]: "

case "$input" in
    1)
    DNSMASQ="0"
    backup_hosts_file="/etc/hosts.backup-$(date +%Y%m%d%H%M%S)"
    cp /etc/hosts "$backup_hosts_file"
    log "Arquivo /etc/hosts original salvo em $backup_hosts_file."
      for service in $SERVICES_HOSTS; do
        if [[ "$service" == "dnsmasq" ]]; then continue; fi
        echo "127.0.0.1 $service.$DOMAIN" >> /etc/hosts
        log "Adicionado: 127.0.0.1 $service.$DOMAIN ao /etc/hosts."
      done
    log "Domínio adicionado ao /etc/hosts."
    war "Esta configuração funciona apenas na sua máquina local. Para acessar os serviços de outras máquinas na rede, adicione as entradas DNS correspondentes no seu roteador ou servidor DNS local."
    ;;
    2)
    DNSMASQ="1"
    log "DNSMASQ será configurado para gerenciar a resolução DNS local."
    ;;
    3)
    DNSMASQ="0"
    war "Nenhuma configuração automática de DNS será feita. Para que os serviços sejam resolvidos corretamente pelo nome de domínio, você precisará adicionar as entradas DNS ao seu servidor DNS local ou ao arquivo hosts de cada máquina cliente."
    ;;
    *)
    war "Opção inválida. Saindo." >&2
    exit 1
    ;;
esac

# DNSMASQ_DIR_DEFAULT is a file path. This section handles the dnsmasq configuration file path.
print "Arquivo de configuração do dnsmasq:\n"

print "1 - Usar caminho padrão: $DNSMASQ_DIR_DEFAULT"
print "2 - Escolher outro caminho\n"

ask "Selecione [1/2]: "

case "$input" in
    1)
    DNSMASQ_DIR="$DNSMASQ_DIR_DEFAULT"
    log "Caminho do arquivo de configuração dnsmasq selecionado: $DNSMASQ_DIR."
    ;;
    2)
    ask "Digite o caminho completo para o arquivo de configuração do dnsmasq (ex: /opt/meudns/dnsmasq.conf): "
    if validate_config_dir "$(dirname "$input")"; then # Modified to pass directory to validate_config_dir
        if [[ "$(basename "$input")" != "dnsmasq.conf" ]]; then
            err "O nome do arquivo de configuração '$input' não é 'dnsmasq.conf'. Isso pode ser inesperado."
            exit 1
        fi
        log "Caminho para dnsmasq.conf selecionado: $input."
    else
        err "O diretório para o arquivo dnsmasq.conf ('$(dirname "$input")') não é válido ou o arquivo dnsmasq.conf não foi encontrado nele (ver mensagem anterior). Abortando..."
        exit 1
    fi
    DNSMASQ_DIR=$input
    ;;
    *)
    war "Opção inválida. Saindo." >&2
    exit 1
    ;;
esac

print "Porta a ser usada para expor os serviços na web:\n"

print "1 - Porta padrão HTTP ($PORT_USED_DEFAULT)"
print "2 - Porta padrão HTTPS ($PORT_USED_DEFAULT_SSL) (requer configuração SSL)"
print "3 - Escolher outra porta\n"

ask "Selecione [1/3]: "

case "$input" in
    1)
    PORT_USED="$PORT_USED_DEFAULT"
    log "Porta selecionada: "$PORT_USED"."
    war "Utilize esta configuração (HTTP) apenas em ambiente local seguro. Para produção ou acesso externo, prefira HTTPS."
    ;;
    2)
    PORT_USED="$PORT_USED_DEFAULT_SSL"
    log "Porta selecionada: "$PORT_USED"."
    war "Ao usar HTTPS ($PORT_USED_DEFAULT_SSL), você precisará configurar certificados SSL para seu domínio. Caso contrário, os serviços poderão apresentar alertas de segurança no navegador."
    ;;
    3)
    ask "Digite a porta que deseja usar (prefixada com ':', ex: :9393): "
      if ! validate_port "$input"; then
        err "Porta inválida: $input. Tente novamente."
        exit 1
      fi
    PORT_USED="$input"
    log "Porta selecionada: "$PORT_USED"."
    ;;
    *)
    war "Opção inválida. Saindo." >&2
    exit 1
    ;;
esac

print "Caminho no sistema de arquivos para salvar os filmes (Radarr):\n"

print "1 - Caminho padrão: $STORAGE_RADARR_DEFAULT"
print "2 - Escolher outro caminho\n"

ask "Selecione [1/2]: "

case "$input" in
    1)
    STORAGE_RADARR="$STORAGE_RADARR_DEFAULT"
    mkdir -p "$STORAGE_RADARR"
    free=$(df -h "$STORAGE_RADARR" | awk 'NR==2 {print $4}') # Corrected variable
    war "Espaço em disco disponível: $free no caminho $STORAGE_RADARR."
    log "Diretório para filmes (Radarr) selecionado: "$STORAGE_RADARR"."
    ;;
    2)
    ask "Digite o caminho completo para o diretório de filmes (Ex: /mnt/midia/filmes/):"
    if validate_storage_dir "$input"; then
        log "Diretório de armazenamento '$input' encontrado."
    else
        war "Diretório de armazenamento '$input' não encontrado. Abortando..."
        mkdir -p "$input"
        if [[ ! -d $input ]]; then
          err "Não foi possível criar o diretório '$input'. Abortando..."
          exit 1
        fi
        log "Diretório '$input' criado com sucesso."
    fi
    STORAGE_RADARR=$input
    free=$(df -h "$STORAGE_RADARR" | awk 'NR==2 {print $4}')
    war "Espaço em disco disponível: $free no caminho $STORAGE_RADARR."
    log "Diretório para filmes (Radarr) selecionado: "$STORAGE_RADARR"."
    ;;
    *)
    war "Opção inválida. Saindo." >&2
    exit 1
    ;;
esac

print "Caminho no sistema de arquivos para salvar as séries (Sonarr):\n"

print "1 - Caminho padrão: $STORAGE_SONARR_DEFAULT"
print "2 - Escolher outro caminho\n"

ask "Selecione [1/2]: "

case "$input" in
    1)
    STORAGE_SONARR=$STORAGE_SONARR_DEFAULT
    mkdir -p "$STORAGE_SONARR"
    free=$(df -h "$STORAGE_SONARR" | awk 'NR==2 {print $4}') # Corrected variable
    war "Espaço em disco disponível: $free no caminho $STORAGE_SONARR."
    log "Diretório para séries (Sonarr) selecionado: "$STORAGE_SONARR"."
    ;;
    2)
    ask "Digite o caminho completo para o diretório de séries (Ex: /mnt/midia/series/):"
      if validate_storage_dir "$input"; then
          log "Diretório de armazenamento '$input' encontrado."
      else
          war "Diretório de armazenamento '$input' não encontrado. Abortando..."
          mkdir -p "$input"
          if [[ ! -d $input ]]; then
            err "Não foi possível criar o diretório '$input'. Abortando..."
            exit 1
          fi
          log "Diretório '$input' criado com sucesso."
      fi
    STORAGE_SONARR=$input
    free=$(df -h "$STORAGE_SONARR" | awk 'NR==2 {print $4}')
    war "Espaço em disco disponível: $free no caminho $STORAGE_SONARR." # Corrected variable
    log "Diretório para séries (Sonarr) selecionado: "$STORAGE_SONARR"."
    ;;
    *)
    war "Opção inválida. Saindo." >&2
    exit 1
    ;;
esac

print "Usuário para o dashboard do Traefik:\n"

print "1 - Usuário padrão: $USER_TRAEFIK_DEFAULT"
print "2 - Escolher outro nome de usuário\n"

ask "Selecione [1/2]: "

case "$input" in
    1)
    USER_TRAEFIK=$USER_TRAEFIK_DEFAULT
    log "Usuário Traefik selecionado: "$USER_TRAEFIK"."
    ;;
    2)
    ask "Digite o nome de usuário para o Traefik (Ex: admin):"
    USER_TRAEFIK=$input
    log "Usuário Traefik selecionado: "$USER_TRAEFIK"."
    ;;
    *)
    war "Opção inválida. Saindo." >&2
    exit 1
    ;;
esac

print "Senha para o dashboard do Traefik:\n"

print "1 - Gerar senha randômica"
print "2 - Escolher minha própria senha"

ask "Selecione [1/2]: "

case "$input" in
    1)
    log "Senha em texto pleno gerada aleatoriamente: "$PASS_TRAEFIK_RANDOM"."
    PASS_TRAEFIK=$(htpasswd -nbB "$USER_TRAEFIK" "$PASS_TRAEFIK_RANDOM"| cut -d ':' -f2 | sed -e 's/\$/\$\$/g')
    log "Senha Traefik criptografada (formato htpasswd): "$PASS_TRAEFIK"."
    ;;
    2)
    ask_secret "Digite a senha desejada para o Traefik (Ex: S3nh@F0rt3!):"
    PASS_TRAEFIK_RANDOM=$input # Storing user's plain text password here
    log "Senha em texto pleno fornecida pelo usuário." # Avoid logging the actual password
    PASS_TRAEFIK=$(htpasswd -nbB "$USER_TRAEFIK" "$PASS_TRAEFIK_RANDOM" | cut -d ':' -f2 | sed -e 's/\$/\$\$/g' )
    log "Senha Traefik criptografada (formato htpasswd): "$PASS_TRAEFIK"."
    ;;
    *)
    war "Opção inválida. Saindo." >&2
    exit 1
    ;;
esac

print "Gerando configuração..."

sleep 3

printf "\n"

printf "${WHITE}Resumo das Configurações:
  Fuso Horário        : "$TZ"
  Domínio             : "$DOMAIN"
  Porta Web           : "$PORT_USED"
  Diretório Radarr    : "$STORAGE_RADARR"
  Diretório Sonarr    : "$STORAGE_SONARR"
  Usuário Traefik     : "$USER_TRAEFIK"
  Senha Traefik (cript): "$PASS_TRAEFIK"
  Ativar DNSMASQ      : "$DNSMASQ" (1=sim, 0=não)
  Arquivo DNSMASQ Conf: "$DNSMASQ_DIR"
  ${RESET}
"

# Handle confirmation based on mode
if [[ "$SKIP_CONFIRM" == false ]]; then
    ask "Confirmar estas configurações e prosseguir com a instalação? [s/N]: "
    [[ "$input" =~ ^[sS]$ ]] || { log "Instalação cancelada pelo usuário."; exit 1; }
else
    log "Confirmação automática ativada (-y)"
fi

cat > .env <<EOF
TZ="$TZ"
DOMAIN="$DOMAIN"
PORT="$PORT_USED" 
RADARR_PATH="$STORAGE_RADARR"
SONARR_PATH="$STORAGE_SONARR"
TRAEFIK_USER="$USER_TRAEFIK"
TRAEFIK_PASS="$PASS_TRAEFIK"
DNSMASQ="$DNSMASQ"
DNSMASQ_DIR="$DNSMASQ_DIR"
EOF

print "Arquivo .env gerado com sucesso."

DOCKER_SERVICES_TO_CHECK="traefik radarr sonarr jellyfin qbittorrent heimdall"

if [[ $DNSMASQ == "1" ]]; then
  log "DNSMASQ ativado. Configurando..."
  dns_ip=$(hostname -I | awk '{ print $1} ') # Gets primary IP, might need adjustment for multi-homed hosts
  mkdir -p "$(dirname "$DNSMASQ_DIR")" # Ensure parent directory for the conf file exists
  cat > "$DNSMASQ_DIR" <<EOF
# Configuração DNSMASQ gerada por script
# Servidores DNS upstream
server=8.8.8.8
server=1.1.1.1

# Resoluções locais
address=/jellyfin.$DOMAIN/$dns_ip
address=/sonarr.$DOMAIN/$dns_ip
address=/radarr.$DOMAIN/$dns_ip
address=/qbittorrent.$DOMAIN/$dns_ip
address=/heimdall.$DOMAIN/$dns_ip
address=/traefik.$DOMAIN/$dns_ip

# Configurações adicionais
listen-address=0.0.0.0
# no-daemon # Comentado se executado via Docker, pois o Docker gerencia o daemon. Descomente se executar dnsmasq diretamente.
# Se o Dockerfile do dnsmasq já executa em foreground, no-daemon pode ser redundante ou causar problemas.
# Verifique a configuração do contêiner dnsmasq.
EOF
  print "Arquivo de configuração do dnsmasq '$DNSMASQ_DIR' gerado."
  print "Iniciando os contêineres (perfil 'dns' ativo)..."

  docker-compose pull $DOCKER_SERVICES_TO_CHECK

  check_local_dns

  if docker-compose --profile dns up -d; then
    log "Contêineres iniciados com sucesso."
  else
    err "Erro ao iniciar os contêineres."
    docker-compose down -v --remove-orphans
    exit 1
  fi

  print "Aguardando alguns segundos para que os contêineres iniciem..."
  sleep 10
  log "Verificando status do contêiner dnsmasq..."
  if docker ps --filter "status=running" --format "{{.Names}}" | grep -q "dnsmasq"; then # Adjust grep if name is different
      print "Contêiner dnsmasq está em execução."
  else
      war "Contêiner dnsmasq não está em execução."
  fi

  for service in $DOCKER_SERVICES_TO_CHECK; do
    print "Verificando resolução DNS para "$service.$DOMAIN" via "$dns_ip"..."
    if dig +short "$service.$DOMAIN" "@$dns_ip" | grep -q "$dns_ip"; then
      print "Serviço $service.$DOMAIN resolvido com sucesso para $dns_ip."
    else
      war "Serviço $service.$DOMAIN não foi resolvido corretamente via $dns_ip (esperado: $dns_ip)."
      systemctl restart $service
    fi
  done
else
  log "DNSMASQ desativado. Iniciando os contêineres (sem perfil 'dns')..."
  docker-compose up -d

  print "Aguardando alguns segundos para que os contêineres iniciem..."
  sleep 5 # Shorter wait if no DNS setup involved

  for docker_service in $DOCKER_SERVICES_TO_CHECK; do
    print "Verificando status do contêiner "$docker_service"..."
    # More robust check for container name (exact match, assuming service name is container name)
    if docker ps --filter "status=running" --format "{{.Names}}" | grep -Eq "^${docker_service}(_[0-9]+)?$"; then
      print "Contêiner "$docker_service" está em execução."
    else
      err "Contêiner "$docker_service" não está em execução ou não foi encontrado."
    fi
  done
fi

print "\nInicialização concluída!"
print "Para acessar os serviços, utilize os seguintes endereços (substitua "$DOMAIN" e "$PORT_USED" se necessário):"
print "Exemplos (protocolo http:// assumido, ajuste para https:// se "$PORT_USED" for :443 e SSL estiver configurado):"
print "  Jellyfin   : http://jellyfin.$DOMAIN$PORT_USED -$(get_container_info_simple "jellyfin")"
print "  Sonarr     : http://sonarr.$DOMAIN$PORT_USED - $(get_container_info_simple "sonarr")"
print "  Radarr     : http://radarr.$DOMAIN$PORT_USED - $(get_container_info_simple "radarr")"
print "  qBittorrent: http://qbittorrent.$DOMAIN$PORT_USED - $(get_container_info_simple "qbittorrent")"
print "  Heimdall   : http://heimdall.$DOMAIN$PORT_USED - $(get_container_info_simple "heimdall")"
print "  Traefik    : http://traefik.$DOMAIN$PORT_USED (dashboard) - $(get_container_info_simple "traefik")"
print "\nLembre-se de que a resolução de DNS pode levar alguns instantes para propagar ou pode requerer limpeza de cache DNS no seu sistema."
print "Log do script: "$logfile" \n"

# Handle post-installation configuration
if [[ "$CLI_MODE" == true ]]; then
    # In CLI mode, skip interactive configuration
    log "Modo CLI - configuração dos ambientes não será executada automaticamente"
    log "Para configurar os ambientes, execute: $0 --configure-environments"
    
    # Show credentials summary
    print "\n${GREEN}=== RESUMO DAS CREDENCIAIS ===${RESET}"
    print "Traefik Dashboard:"
    print "  URL: http://traefik.$DOMAIN$PORT_USED"
    print "  Usuário: $USER_TRAEFIK"
    print "  Senha: $PASS_TRAEFIK_RANDOM"
    print "\nqBittorrent:"
    print "  URL: http://qbittorrent.$DOMAIN$PORT_USED"
    print "  Senha inicial: Verifique com 'docker logs qbittorrent | grep password'"
    print "\nAcesse os serviços e complete a configuração manualmente."
else
    ask "Deseja configurar os ambientes? [s/N]: "
    
    if [[ "$input" =~ ^[sS]$ ]]; then
        war "Vamos realizar a configuração dos ambientes, pensando em deixar um ambiente pre-pronto para o uso."
        war "Porem pode ser necessario realizar algumas configurações manuais."
        war "criando pasta com todos os backup dentro /opt/backup/"
        backup_dir="/opt/backup"
        export backup_dir
        for backup_path in $SERVICES_HOSTS; do
            if [[ ! -d $backup_dir/$backup_path ]]; then
                if mkdir -p $backup_dir/$backup_path; then
                    log "Pasta de backup criada: $backup_dir/$backup_path"
                else
                    err "Erro ao criar a pasta de backup: $backup_dir/$backup_path"
                    exit 1
                fi
            else
                log "Pasta de backup já existe: $backup_dir/$backup_path"
            fi
        done
        source setups/args.sh
        source setups/heimdall.sh
        source setups/qbittorrent.sh
        source setups/radarr.sh
        source setups/sonarr.sh
        source setups/prowlarr.sh
    else
        log "os serviços foram iniciados com sucesso e estão em execução."
        war "o qbittorrent criara uma senha randomica, para ter acesso a ela veja nos logs com co comando 'docker logs qbittorrent' ou anota a senha abaixo"
        docker logs qbittorrent | grep -r "The WebUI administrator password"
    fi
fi

save_credentials() {
    local cred_file="/opt/selfhosted-flix/.credentials"
    mkdir -p "$(dirname "$cred_file")"
    touch "$cred_file"
    chmod 600 "$cred_file"
    cat > "$cred_file" << EOF
# Credenciais Selfhosted-Flix - Geradas em $(date)
# MANTENHA ESTE ARQUIVO SEGURO!

TRAEFIK_USER=$USER_TRAEFIK
TRAEFIK_PASS=$PASS_TRAEFIK_RANDOM

# URLs de acesso:
JELLYFIN_URL=http://jellyfin.$DOMAIN$PORT_USED
SONARR_URL=http://sonarr.$DOMAIN$PORT_USED
RADARR_URL=http://radarr.$DOMAIN$PORT_USED
QBITTORRENT_URL=http://qbittorrent.$DOMAIN$PORT_USED
HEIMDALL_URL=http://heimdall.$DOMAIN$PORT_USED
TRAEFIK_URL=http://traefik.$DOMAIN$PORT_USED
EOF
    log "Credenciais salvas em: $cred_file"
}

save_credentials

print "\n${GREEN}Instalação concluída com sucesso!${RESET}"

exit 0
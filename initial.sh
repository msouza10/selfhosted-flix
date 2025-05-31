#!/usr/bin/env bash

set -euo pipefail

# variables general
BANNER_DIR="banners/ascii_fonts"
SERVICES_HOSTS="traefik radarr sonarr jellyfin qbittorrent dnsmasq heimdall"
REQUIREMENTS="docker htpasswd ping mkdir cp awk sed shuf grep timedatectl python3 sqlite3"
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

# color builder and color check
if [[ -t 1 ]]; then
  RED="\033[1;31m"; BLUE="\033[1;34m"; YELLOW="\033[1;33m"; GREEN="\033[1;32m"; WHITE="\033[1;37m"
  RESET="\033[0m" 
else
  RED=; BLUE=; YELLOW=; GREEN=; RESET=
fi

# prints models
logfile="logs/initial-$(date +%Y%m%d).log"  # logfile path
log() { printf "${BLUE}[INFO] - $(date '+%H:%M:%S:') - $* ${RESET} \n" | tee -a $logfile ; } 
err() { printf "${RED}[ERROR] - $(date '+%H:%M:%S:') - $* ${RESET} \n" | tee -a $logfile ; } 
war() { printf "${YELLOW}[WARN] - $(date '+%H:%M:%S:') - $* ${RESET} \n" | tee -a $logfile ; } 
print() { printf "${WHITE}[ECHO] - $(date '+%H:%M:%S:') - $* ${RESET} \n" | tee -a $logfile ; } 
ask() { local msg; msg="${WHITE}[ASK] - $(date '+%H:%M:%S') - $*${RESET}"; printf "%b\n" "$msg"; read -rp "" input; } 
ask_secret() { local msg; msg="${WHITE}[ASK-SECRET] - $(date '+%H:%M:%S') - $*${RESET}"; printf "%b\n" "$msg"; read -rsp "" input; printf "\n"; }

# trap check
trap 'err "Interrompido pelo usuário."; exit 0' INT

# root check
if [[ $EUID -ne 0 ]]; then
  err "Inicie como root (sudo)."
  exit 1
else
  log "Iniciado como root."
fi

# check requirements
for cmd in $REQUIREMENTS; do
    if ! command -v $cmd &>/dev/null; then
        err "$cmd não encontrado, necessário para prosseguir. Abortando..."
        exit 1
    else
        log "$cmd encontrado."
    fi
done

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
    if ! echo "$port" | grep -qP '^:[0-9]+$' || ! echo "$port" || (( port < 1 || port > 65535 )); then # check ":" because it's a port prefix
        err "Porta inválida: $port."
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
        err "Diretório de armazenamento '$dir' não encontrado ou inválido. Abortando..."
        exit 1
    fi
}

get_container_info_simple() {
    local cname="$1"
    # IP do container (pode ser vazio se não estiver em bridge)
    local ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$cname" 2>/dev/null)
    [ -z "$ip" ] && ip="N/A"

    # Portas mapeadas
    local portas=$(docker port "$cname" 2>/dev/null | paste -sd "," -)
    [ -z "$portas" ] && portas="Nenhuma"

    # Portas ouvindo dentro do container (não é EXPOSE, mas é útil)
    local ouvindo=$(docker exec "$cname" sh -c 'ss -tuln 2>/dev/null || netstat -tuln 2>/dev/null' 2>/dev/null | awk 'NR>1{print $5}' | awk -F: '{print $NF}' | sort -n | uniq | paste -sd "," -)
    [ -z "$ouvindo" ] && ouvindo="Indisponível"

    printf "IP: %s - Portas mapeadas: %s - Portas ouvindo: %s\n" "$ip" "$portas" "$ouvindo"
}

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

sleep 3
clear

print "Fuso horário a ser utilizado:"
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

print "Para este domínio funcionar, é necessário que sua máquina o reconheça de alguma forma:"

print "1 - Adicionar ao arquivo /etc/hosts da sua máquina"
print "2 - Subir um contêiner dnsmasq para resolução local de DNS"
print "3 - Não adicionar (você precisará configurar a resolução DNS manualmente)"

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
ask "Confirmar estas configurações e prosseguir com a instalação? [s/N]: "
[[ "$input" =~ ^[sS]$ ]] || { log "Instalação cancelada pelo usuário."; exit 1; }

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
  docker-compose --profile dns up -d

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

ask "Deseja configurar os ambientes? [s/N]: "

if [[ "$input" =~ ^[sS]$ ]]; then
    war "Vamos realizar a configuração dos ambientes, pensando em deixar um ambiente pre-pronto para o uso."
    war "Porem pode ser necessario realizar algumas configurações manuais."
    war "criando pasta com todos os backup dentro /opt/backup/"
    $backup_dir="/opt/backup"
    mkdir -p $backup_dir/$SERVICES_HOSTS
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
    exit 1
fi




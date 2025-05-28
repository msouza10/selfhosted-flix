#!/usr/bin/env bash

set -eo pipefail

printf "Iniciando script..."
sleep 1
printf "1..."
sleep 1
printf "2..."
sleep 1
printf "3...\n"
sleep 1

# color builder and color check
if [[ -t 1 ]]; then
  RED="\033[1;31m"; BLUE="\033[1;34m"; YELLOW="\033[1;33m"; GREEN="\033[1;32m"; WHITE="\033[1;37m"
  RESET="\033[0m" 
else
  RED=; BLUE=; YELLOW=; GREEN=; RESET=
fi

# prints models
log() { printf "${BLUE}[INFO] - $(date '+%H:%M:%S') - $* ${RESET} \n"; } >> /var/log/initial-$(date +%Y%m%d%H%M%S).log    
err() { printf "${RED}[ERROR] - $(date '+%H:%M:%S') - $* ${RESET} \n" >&2; } >> /var/log/initial-$(date +%Y%m%d%H%M%S).log
war() { printf "${YELLOW}[WARN] - $(date '+%H:%M:%S') - $* ${RESET} \n"; } >> /var/log/initial-$(date +%Y%m%d%H%M%S).log
print() { printf "${WHITE}[ECHO] - $(date '+%H:%M:%S') - $* ${RESET} \n"; } >> /var/log/initial-$(date +%Y%m%d%H%M%S).log
ask() { local msg; msg="${WHITE}[ASK] - $(date '+%H:%M:%S') - $*${RESET}"; printf "%b\n" "$msg"; read -rp "" input; } >> /var/log/initial-$(date +%Y%m%d%H%M%S).log
ask_secret() { local msg; msg="${WHITE}[ASK-SECRET] - $(date '+%H:%M:%S') - $*${RESET}"; printf "%b\n" "$msg"; read -rsp "" input; printf "\n"; } >> /var/log/initial-$(date +%Y%m%d%H%M%S).log

# trap check
trap 'log "Interrompido pelo usuário."; exit 1' INT

# root check
if [[ $EUID -ne 0 ]]; then
    err "Inicie como root (sudo)."
    exit 1
fi

# check connection
if ! ping -c 5 google.com &>/dev/null; then
    err "Sem conexao com a internet, necessario para proseguir, abortando..."
    exit 1
else
    log "Conexao com a internet estabelecida"
fi

# docker check
if ! command -v docker &>/dev/null; then
    err "Docker nao encontrado, necessario para proseguir, abortando..."
    exit 1
else
    log "Docker encontrado"
fi

# htpasswd check                         
if ! command -v htpasswd &>/dev/null; then
    err "htpasswd nao encontrado, necessario para proseguir, abortando..."
    exit 1
else
    log "htpasswd encontrado"
fi

# validations on domain, port and config dir
validate_domain() {
    local domain="$1"
    if ! echo "$domain" | grep -qP '(?=^.{4,253}$)(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$)'; then
        err "Domínio inválido: $domain"
    fi
}

validate_port() {
    local port="$1"
    if ! echo "$port" | grep -qP '^:[0-9]+$'; then
        err "Porta inválida: $port"
    fi
}

validate_config_dir() {
    local dir="$1"
    
    if [[ ! -d $dir || ! -f $dir/dnsmasq.conf ]]; then
        err "Diretorio nao encontrado ou arquivo dnsmasq.conf nao encontrado, abortando..."
    fi
}
# variables general
BANNER_DIR="banners/ascii_fonts"
SERVICES_HOSTS="traefik radarr sonarr jellyfin qbittorrent dnsmasq"

# variables for env
TZ_DEFAULT="$(timedatectl show --property=Timezone --value)"
DOMAIN_DEFAULT="localhost"
PORT_USED_DEFAULT=":80"
PORT_USED_DEFAULT_SSL=":443"
STORAGE_RADARR_DEFAULT="/opt/radarr-media"
STORAGE_SONARR_DEFAULT="/opt/sonarr-media"
DNSMASQ_DIR_DEFAULT="/opt/dnsmasq/dnsmasq.conf"
USER_TRAEFIK_DEFAULT="admin"
PASS_TRAEFIK_RANDOM="$(openssl rand -base64 12)"

# check if there are banners in the banners directory
if [[ -d $BANNER_DIR ]] && find "$BANNER_DIR" -type f | grep -q .; then
  banner=$(find "$BANNER_DIR" -type f | shuf -n1)
  printf "${RED}"
  cat "$banner"
  printf "${RESET}"
else
  war "sem banners em $BANNER_DIR"
fi

printf "${RED}🎬  Powered by:\n"
printf "    ├── Jellyfin\n"
printf "    ├── Radarr\n"
printf "    ├── Sonarr\n"
printf "    ├── Helmindall\n"
printf "    ├── qBittorrent\n"
printf "    └── Traefik\n${RESET}\n"


printf "${GREEN}🐧 Coded by:msouza10 ${RESET}\n"

# executions
print "Iniciando config do ambiente\n"

print "Fuso horario utilizado"
print "1 - Padrao da sua maquina - $TZ_DEFAULT"
print "2 - Escolher outro\n"

ask "Selecione [1/2]: "

case "$input" in
  1)
    TZ="$TZ_DEFAULT"
    log "Timezone selecionado $TZ"
    ;;
  2)
    # carrega todos os fusos numa array
    mapfile -t zones < <(timedatectl list-timezones)
    PS3=$'Escolha um fuso horário (número) ou 0 para sair: '
    select zone in "${zones[@]}"; do
      if [[ "$REPLY" == "0" ]]; then
        err "Cancelado."
        TZ="$TZ_DEFAULT"
        log "Timezone selecionado $TZ"
        break
      elif (( REPLY >= 1 && REPLY <= ${#zones[@]} )); then
        TZ="$zone"
        log "Timezone selecionado - $TZ"
        break
      else
        err "Opção inválida, tente novamente."
      fi
    done
    ;;
  *)
    err "Opção inválida." >&2
    exit 1
    ;;
esac

print "Qual dominio deve ser utilizado\n"

print "1 - Dominio sugerido - $DOMAIN_DEFAULT"
print "2 - Escolher outro\n"

ask "Selecione [1/2]: "

case "$input" in
    1)
    DOMAIN="$DOMAIN_DEFAULT"
    log "Dominio selecionado $DOMAIN"
    ;;
    2)
    ask "digite seu dominio (ex: foo.com):"
    if ! validate_domain "$input"; then
      err "Domínio inválido: $input, tente novamente."
      exit 1
    fi
    DOMAIN=$input
    log "Dominio selecionado $DOMAIN"
    ;;
    *)
    err "Opção inválida." >&2
    exit 1
    ;;
esac

print "Para esse dominio funcionar e necessario que sua maquina conheca ele de alguma forma."

print "1 - Adicionar ao seu /etc/hosts"
print "2 - subir um container dnsmasq"
print "3 - Nao adicionar"

ask "Selecione [1/3]: "

case "$input" in
    1)
    DNSMASQ="0"
    cp /etc/hosts /etc/hosts.backup-$(date +%Y%m%d%H%M%S)
      for service in $SERVICES_HOSTS; do
        echo 127.0.0.1 $service.$DOMAIN >> /etc/hosts
      done
    log "Dominio adicionado ao /etc/hosts, arquivo de backup criado em /etc/hosts.backup"
    war "essa configuracao funciona apenas na sua maquina local, para acessar os servicos de outras maquinas, voce precisa adicionar o dominio ao seu dns local"
    ;;
    2)
    DNSMASQ="1"
    log "DNSMASQ sera criado para gerenciar o dns"
    ;;
    3)
    DNSMASQ="0"
    war "para ser resolvido corretamente, voce precisa adicionar o dominio ao seu dns local"
    ;;
    *)
    err "Opção inválida." >&2
    exit 1
    ;;
esac

print "Diretorio usado para salvar a configuracao do dnsmasq\n"

print "1 - Diretorio padrao para salvar a configuracao do dnsmasq - $DNSMASQ_DIR_DEFAULT"
print "2 - Escolher outro\n"

ask "Selecione [1/2]: "

case "$input" in
    1)
    DNSMASQ_DIR="$DNSMASQ_DIR_DEFAULT"
    log "Diretorio selecionado $DNSMASQ_DIR"
    ;;
    2)
    ask "Digite o diretorio completo para salvar a configuracao do dnsmasq (ex: /opt/dnsmasq/dnsmasq.conf): "  
      if validate_config_dir "$input"; then
        log "Diretorio selecionado $input"
      else
        err "Diretorio nao encontrado ou arquivo dnsmasq.conf nao aplicado no caminho, abortando..."
        exit 1
      fi
    DNSMASQ_DIR=$input
    ;;
    *)
    err "Opção inválida." >&2
    exit 1
    ;;
esac

print "Porta usada para expor os servicos\n"

print "1 - Porta padrao sem ssl - $PORT_USED_DEFAULT "
print "2 - Porta padrao para usar ssl - $PORT_USED_DEFAULT_SSL"
print "3 - Escolher outra\n"

ask "Selecione [1/3]: "

case "$input" in
    1)
    PORT_USED=$PORT_USED_DEFAULT
    log "Porta selecionada $PORT_USED"
    war "utilize essa configuracao apenas em ambiente local, para ambientes de producao, utilize a porta padrao com ssl"
    ;;
    2)
    PORT_USED=$PORT_USED_DEFAULT_SSL
    log "Porta selecionada $PORT_USED"
    war "ao selecionar essa opcao, voce precisa configurar o ssl no seu dominio, caso contrario, todos os servicos ficaram como inseguros no navegador"
    ;;
    3)
    ask "digite a porta que deseja usar (ex: :9393): "
      if ! validate_port "$input"; then
        err "Porta inválida: "$input", tente novamente."
        exit 1
      fi
    PORT_USED=$input 
    log "Porta selecionada $PORT_USED"
    ;;
    *)
    err "Opção inválida." >&2
    exit 1
    ;;
esac

print "Caminho usado para salvar os filmes\n"

print "1 - Caminhos padrao - $STORAGE_RADARR_DEFAULT"
print "2 - Escolher outra\n"

ask "Selecione [1/2]: "

case "$input" in
    1)
    STORAGE_RADARR="$STORAGE_RADARR_DEFAULT"
    mkdir -p $STORAGE_RADARR
    free=$(df -h $STORAGE_RADARR | awk 'NR==2 {print $4}')
    war "Espaco em disco disponivel: $free GB no caminho $STORAGE_RADARR"
    log "Diretorio selecionado $STORAGE_RADARR"
    ;;
    2)
    ask "Coloque o caminho completo(Ex:/home/root/Videos/):" 
      if [[ ! -d $input ]]; then
        war "Caminho nao encontrado, abortando..."
        mkdir -p $input
        if [[ ! -d $input ]]; then
          err "nao foi possivel criar o diretorio, abortando..."
          exit 1
        fi
      else
        log "Caminho encontrado - $input"
      fi
    STORAGE_RADARR=$input
    free=$(df -h $STORAGE_RADARR | awk 'NR==2 {print $4}')
    war "Espaco em disco disponivel: $free GB no caminho $STORAGE_RADARR"
    log "Diretorio selecionado $STORAGE_RADARR"
    ;;
    *)
    err "Opção inválida." >&2
    exit 1
    ;;
esac

print "Caminho usado para salvar as series\n"

print "1 - Caminhos padrao - $STORAGE_SONARR_DEFAULT"
print "2 - Escolher outra\n"

ask "Selecione [1/2]: "

case "$input" in
    1)
    STORAGE_SONARR=$STORAGE_SONARR_DEFAULT
    mkdir -p $STORAGE_SONARR
    free=$(df -h $STORAGE_RADARR | awk 'NR==2 {print $4}')
    war "Espaco em disco disponivel: $free GB no caminho $STORAGE_RADARR"
    log "Diretorio selecionado $STORAGE_SONARR"
    ;;
    2)
    ask "Coloque o caminho completo(Ex:/home/root/Videos/):"
      if [[ ! -d $input ]]; then
        war "Caminho nao encontrado, abortando..."
        mkdir -p $input
        if [[ ! -d $input ]]; then
          err "nao foi possivel criar o diretorio, abortando..."
          exit 1
        fi
      else
        log "Caminho encontrado - $input"
      fi
    STORAGE_SONARR=$input
    free=$(df -h $STORAGE_SONARR | awk 'NR==2 {print $4}')
    war "Espaco em disco disponivel: $free GB no caminho $STORAGE_RADARR"
    log "Diretorio selecionado $STORAGE_SONARR"
    ;;
    *)
    err "Opção inválida." >&2
    exit 1
    ;;
esac

print "Selecionar usuario do Traefik\n"

print "1 - Usuario padrao - $USER_TRAEFIK_DEFAULT"
print "2 - Escolher outro\n"

ask "Selecione [1/2]: "

case "$input" in
    1)
    USER_TRAEFIK=$USER_TRAEFIK_DEFAULT
    log "Usuario selecionada $USER_TRAEFIK"
    ;;
    2)
    ask "Nome de usuario (Ex:msouza):"
    USER_TRAEFIK=$input
    log "Usuario selecionada $USER_TRAEFIK"
    ;;
    *)
    err "Opção inválida." >&2
    exit 1
    ;;
esac

print "Selecionar senha do Traefik\n"

print "1 - Senha randomica"
print "2 - Escolher sua senha"

ask "Selecione [1/2]: "

case "$input" in
    1)
    log "senha em texto pleno - $PASS_TRAEFIK_RANDOM"
    PASS_TRAEFIK=$(htpasswd -nbB $USER_TRAEFIK "$PASS_TRAEFIK_RANDOM"| cut -d ':' -f2 | sed -e 's/\$/\$\$/g')
    log "Senha criptografada selecionada $PASS_TRAEFIK"
    ;;
    2)
    ask_secret "escolher outra senha (Ex:!P@ssw04d):"
    PASS_TRAEFIK_RANDOM=$input
    log "senha em texto pleno - $PASS_TRAEFIK_RANDOM"
    PASS_TRAEFIK=$(htpasswd -nbB $USER_TRAEFIK "$PASS_TRAEFIK_RANDOM" | cut -d ':' -f2 | sed -e 's/\$/\$\$/g' )
    log "Senha criptografada selecionada $PASS_TRAEFIK"
    ;;
    *)
    err "Opção inválida." >&2
    exit 1
    ;;
esac

print "Gerando configuracao..."

sleep 3

printf "\n"

printf "${WHITE}Resumo:
  Timezone: $TZ
  Domínio : $DOMAIN
  Porta   : $PORT_USED
  Radarr  : $STORAGE_RADARR
  Sonarr  : $STORAGE_SONARR
  Traefik user : $USER_TRAEFIK
  Traefik pass crypt: $PASS_TRAEFIK
  DNSMASQ : $DNSMASQ
  DNSMASQ_DIR : $DNSMASQ_DIR
  ${RESET}
"
ask "Confirmar estas configurações? [y/N]: "
[[ "$input" =~ ^[yY]$ ]] || { log "Cancelado."; exit 1; }

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

if [[ $DNSMASQ == "1" ]]; then
  log "DNSMASQ ativado, configurando..."
  dns_ip=$(hostname -I | awk '{ print $1} ')
  cat > $DNSMASQ_DIR <<EOF
  server=8.8.8.8
  server=1.1.1.1
  address=/jellyfin.$DOMAIN/$dns_ip
  address=/sonarr.$DOMAIN/$dns_ip
  address=/radarr.$DOMAIN/$dns_ip
  address=/qbittorrent.$DOMAIN/$dns_ip
  address=/heimdall.$DOMAIN/$dns_ip
  address=/traefik.$DOMAIN/$dns_ip
  listen-address=0.0.0.0
  no-daemon
  EOF
  print "Iniciando os containers..."
  docker-compose --profile dns up -d

  print "Aguarde alguns segundos para que os containers iniciem..."
  sleep 10
  for service in $SERVICES_HOSTS; do
    print "Acessando o $service..."
    if dig $service.$DOMAIN @$dns_ip | grep -q "ANSWER SECTION"; then
      print "Servico $service.$DOMAIN acessado com sucesso"
    else
      err "Servico $service.$DOMAIN nao acessado"
    fi
  done
else
  log "DNSMASQ desativado, iniciando os containers..."
  print "Iniciando os containers..."
  docker-compose up -d

  for docker_service in $SERVICES_HOSTS; do
    print "Acessando o $docker_service..."
    if docker ps | grep -q $docker_service; then
      print "Servico $docker_service acessado com sucesso"
    else
      err "Servico $docker_service nao acessado"
    fi
  done
fi

print "para acessar os servicos, voce pode usar o dominio $DOMAIN"
print "exemplo: jellyfin.$DOMAIN$PORT_USED"
print "exemplo: sonarr.$DOMAIN$PORT_USED"
print "exemplo: radarr.$DOMAIN$PORT_USED"
print "exemplo: qbittorrent.$DOMAIN$PORT_USED"
print "exemplo: heimdall.$DOMAIN$PORT_USED"
print "exemplo: traefik.$DOMAIN$PORT_USED"
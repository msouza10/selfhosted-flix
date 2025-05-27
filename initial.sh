
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
log() { printf "${BLUE}[INFO] - $(date '+%H:%M:%S') - $* ${RESET} \n"; }
err() { printf "${RED}[ERROR] - $(date '+%H:%M:%S') - $* ${RESET} \n" >&2; }
war() { printf "${YELLOW}[WARN] - $(date '+%H:%M:%S') - $* ${RESET} \n"; }
print() { printf "${WHITE}[ECHO] - $(date '+%H:%M:%S') - $* ${RESET} \n"; }
ask() { local msg; msg="${WHITE}[ASK] - $(date '+%H:%M:%S') - $*${RESET}"; printf "%b\n" "$msg"; read -rp "" input; }
ask_secret() { local msg; msg="${WHITE}[ASK-SECRET] - $(date '+%H:%M:%S') - $*${RESET}"; printf "%b\n" "$msg"; read -rsp "" input; printf "\n"; }

# trap check
trap 'log "Interrompido pelo usuário."; exit 1' INT

# root check
if [[ $EUID -ne 0 ]]; then
    err "Inicie como root (sudo)."
    exit 1
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

# variables general
BANNER_DIR="banners/ascii_fonts"

# variables for env
TZ_DEFAULT="$(timedatectl show --property=Timezone --value)"
DOMAIN_DEFAULT="localhost"
PORT_USED_DEFAULT=":80"
PORT_USED_DEFAULT_SSL=":443"
STORAGE_RADARR_DEFAULT="/opt/radarr-media"
STORAGE_SONARR_DEFAULT="/opt/sonarr-media"
USER_TRAEFIK_DEFAULT="admin"
PASS_TRAEFIK_RANDOM="$(openssl rand -base64 12)"

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
        err "Cancelado."; exit 1
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
    DOMAIN=$input
    log "Dominio selecionado $DOMAIN"
    ;;
    *)
    err "Opção inválida." >&2
    exit 1
    ;;
esac

print "Porta usada para expor\n"

print "1 - Porta padrao sem ssl - $PORT_USED_DEFAULT "
print "2 - Porta padrao para usar ssl - $PORT_USED_DEFAULT_SSL"
print "3 - Escolher outra\n"

ask "Selecione [1/3]: "

case "$input" in
    1)
    PORT_USED=$PORT_USED_DEFAULT
    log "Porta selecionada $PORT_USED"
    ;;
    2)
    PORT_USED=$PORT_USED_DEFAULT_SSL
    log "Porta selecionada $PORT_USED"
    ;;
    3)
    ask "digite a porta que deseja usar (ex: :9393):"
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
    log "Porta selecionada $STORAGE_RADARR"
    ;;
    2)
    ask "Coloque o caminho completo(Ex:/home/root/Videos/):" 
    STORAGE_RADARR=$input
    log "Porta selecionada $STORAGE_RADARR"
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
    log "Porta selecionada $STORAGE_SONARR"
    ;;
    2)
    ask "Coloque o caminho completo(Ex:/home/root/Videos/):" 
    STORAGE_SONARR=$input
    log "Porta selecionada $STORAGE_SONARR"
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
    PASS_TRAEFIK=$((htpasswd -nbB foo "$PASS_TRAEFIK_RANDOM") | cut -d ':' -f2 | sed -e 's/\$/\$\$/g')
    log "Senha criptografada selecionada $PASS_TRAEFIK"
    ;;
    2)
    ask "escolher outra senha (Ex:!P@ssw04d):"
    PASS_TRAEFIK_RANDOM=$input
    log "senha em texto pleno - $PASS_TRAEFIK_RANDOM"
    PASS_TRAEFIK=$((htpasswd -nbB foo "$PASS_TRAEFIK_RANDOM") | cut -d ':' -f2 | sed -e 's/\$/\$\$/g')
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
EOF

print "Arquivo .env gerado com sucesso."
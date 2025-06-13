#!/usr/bin/env bash

data_path="_data"
sonarr_path=$(find $DOCKER_ROOT_DIR/volumes -maxdepth 1 -type d -name "*sonarr*")
qbittorrent_path=$(find $DOCKER_ROOT_DIR/volumes -maxdepth 1 -type d -name "*qbittorrent*")
radarr_path=$(find $DOCKER_ROOT_DIR/volumes -maxdepth 1 -type d -name "*radarr*")
prowlarr_path=$(find $DOCKER_ROOT_DIR/volumes -maxdepth 1 -type d -name "*prowlarr*")
heimdall_path=$(find $DOCKER_ROOT_DIR/volumes -maxdepth 1 -type d -name "*heimdall*")

# apis of services
sonarr_api="$(awk -F'[<>]' '/<ApiKey>/ { print $3 }' "$sonarr_path/$data_path/config.xml")"
radarr_api="$(awk -F'[<>]' '/<ApiKey>/ { print $3 }' "$radarr_path/$data_path/config.xml")"
prowlarr_api="$(awk -F'[<>]' '/<ApiKey>/ { print $3 }' "$prowlarr_path/$data_path/config.xml")"

# ips of services
qbittorrent_ip="$(docker ps -q | xargs -r docker inspect -f '{{.Name}} - IP: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | grep traefik | head -n 1 | cut -d : -f2 | tr -d '[:space:]')"
sonarr_ip="$(docker ps -q | xargs -r docker inspect -f '{{.Name}} - IP: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | grep sonarr | head -n 1 | cut -d : -f2 | tr -d '[:space:]')"
prowlarr_ip="$(docker ps -q | xargs -r docker inspect -f '{{.Name}} - IP: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | grep prowlarr | head -n 1 | cut -d : -f2 | tr -d '[:space:]')"
radarr_ip="$(docker ps -q | xargs -r docker inspect -f '{{.Name}} - IP: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | grep radarr | head -n 1 | cut -d : -f2 | tr -d '[:space:]')"
heimdall_ip="$(docker ps -q | xargs -r docker inspect -f '{{.Name}} - IP: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | grep heimdall | head -n 1 | cut -d : -f2 | tr -d '[:space:]')"
traefik_ip="$(docker ps -q | xargs -r docker inspect -f '{{.Name}} - IP: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | grep traefik | head -n 1 | cut -d : -f2 | tr -d '[:space:]')"

log "Iniciando configuração dos ambientes..."

print "Precisamos configurar as credenciais dos ambientes, pensando em deixar um ambiente pre-pronto para o uso."

for i in {3..1}; do
    print "$i"
    sleep 1
done

clear

# configuration of qbittorrent

print "Usuario do qbittorrent"

print "1 - Criar usuario default"
print "2 - Usar usuario personalizado"

ask "Selecione uma opção [1/2]: "

if [[ "$input" =~ ^[1]$ ]]; then
    qbittorrent_user="admin"
    log "Usuario default: $qbittorrent_user"
else
    ask "Digite o usuario para o qbittorrent: "
    qbittorrent_user="$input"
    log "Usuario selecionado: $qbittorrent_user"
fi

print "Senha do qbittorrent"

print "1 - Criar senha randomica auto-renovavel"
print "2 - Usar senha fixa (recomendado)"

war "Se selecionar a opção 1, a senha não será fixa, você deve verificar a senha no log do container qbittorrent toda a vez que reinicializar."
war "Tambem sera necessario configurar manualmente a senha no sonarr e radarr"

ask "Selecione uma opção [1/2]: "

if [[ "$input" =~ ^[1]$ ]]; then
    war "A senha não será fixa, você deve verificar a senha no log do container qbittorrent toda a vez que reinicializar"
    log "Senha gerada: $(docker logs qbittorrent | grep "The WebUI administrator password" | tail -n 1 | awk '{print $16}')"
else
    ask_secret "Digite a senha para o qbittorrent: "
    log "Senha gerada: $input"
    qbittorrent_pass_fixed="$input"
    hash_qbittorrent="$(python3 based/salt_gen.py --hash "$input")"
    qbittorrent_pass="$hash_qbittorrent"
    log "Senha em hash+salt: $qbittorrent_pass"
    log "Senha configurada com sucesso!"
fi

# configuration of sonarr

print "Usuario do Sonarr"
print "1 - Criar usuario default"
print "2 - Usar usuario personalizado"

ask "Selecione uma opção [1/2]: "

if [[ "$input" =~ ^[1]$ ]]; then
    sonarr_user="admin"
    log "Usuario default: $sonarr_user"
else
    ask "Digite o usuario para o Sonarr: "
    sonarr_user="$input"
    log "Usuario selecionado: $sonarr_user"
fi

print "Senha do Sonarr"

print "1 - Criar senha randomica"
print "2 - Usar senha personalizada"

ask "Selecione uma opção [1/2]: "

if [[ "$input" =~ ^[1]$ ]]; then
    sonarr_pass="$(openssl rand -base64 12)"
    log "Senha gerada: $sonarr_pass"
else
    ask_secret "Digite a senha para o Sonarr: "
    sonarr_pass="$input"
    log "Senha configurada com sucesso!"
fi

# configuration of radarr

print "Usuario do Radarr"

print "1 - Criar usuario default"
print "2 - Usar usuario personalizado"

ask "Selecione uma opção [1/2]: "

if [[ "$input" =~ ^[1]$ ]]; then
    radarr_user="admin"
    log "Usuario default: $radarr_user"
else
    ask "Digite o usuario para o Radarr: "
    radarr_user="$input"
    log "Usuario selecionado: $radarr_user"
fi

print "Senha do Radarr"

print "1 - Criar senha randomica"
print "2 - Usar senha personalizada"

ask "Selecione uma opção [1/2]: "

if [[ "$input" =~ ^[1]$ ]]; then
    radarr_pass="$(openssl rand -base64 12)"
    log "Senha gerada: $radarr_pass"
else
    ask_secret "Digite a senha para o Radarr: "
    radarr_pass="$input"
    log "Senha configurada com sucesso!"
fi

# configuration of prowlarr

print "Usuario do Prowlarr"

print "1 - Criar usuario default"
print "2- Usar usuario personalizado"

ask "Selecione uma opção [1/2]: "

if [[ "$input" =~ ^[1]$ ]]; then
    prowlarr_user="admin"
    log "Usuario default: $prowlarr_user"
else
    ask "Digite o usuario para o Prowlarr: "
    prowlarr_user="$input"
    log "Usuario selecionado: $prowlarr_user"
fi

print "Senha do Prowlarr"

print "1 - Criar senha randomica"
print "2 - Usar senha personalizada"

ask "Selecione uma opção [1/2]: "

if [[ "$input" =~ ^[1]$ ]]; then
    prowlarr_pass="$(openssl rand -base64 12)"
    log "Senha gerada: $prowlarr_pass"
else
    ask_secret "Digite a senha para o Prowlarr: "
    prowlarr_pass="$input"
    log "Senha configurada com sucesso!"
fi


# check qbitorrent variable

if [[ -z "$qbittorrent_pass" ]]; then
    war "Configurando senha randomica e auto-renovavel para o qbittorrent."
    all_vars=("$qbittorrent_user" "$qbittorrent_ip" "$sonarr_user" "$sonarr_pass" "$sonarr_ip" "$radarr_user" "$radarr_pass" "$radarr_api" "$radarr_ip" "$prowlarr_user" "$prowlarr_pass" "$prowlarr_api" "$prowlarr_ip" "$heimdall_ip" "$traefik_ip")
else
    war "Configurando senha fixa para o qbittorrent."
    all_vars=("$qbittorrent_user" "$qbittorrent_pass_fixed" "$qbittorrent_pass" "$qbittorrent_ip" "$sonarr_user" "$sonarr_pass" "$sonarr_ip" "$radarr_user" "$radarr_pass" "$radarr_api" "$radarr_ip" "$prowlarr_user" "$prowlarr_pass" "$prowlarr_api" "$prowlarr_ip" "$heimdall_ip" "$traefik_ip")
fi

# check if all variables are set
for var in "${all_vars[@]}"; do
    log "Verificando variável: $var"
    if [ -z "$var" ]; then
        err "Variável não encontrada: $var"
        ask "Deseja continuar? [s/n]: "
         if [[ "$input" =~ ^[sS]$ ]]; then
            continue
        else
            exit 1
        fi
    fi
done


# exporting variables for use in other scripts
export qbittorrent_user qbittorrent_pass qbittorrent_ip
export sonarr_user sonarr_pass sonarr_ip
export radarr_user radarr_pass radarr_api radarr_ip
export prowlarr_user prowlarr_pass prowlarr_api prowlarr_ip
export heimdall_ip traefik_ip
export heimdall_path qbittorrent_path sonarr_path radarr_path prowlarr_path

log "Configuração das credenciais concluída com sucesso!"

save_credentials_services() {
    local cred_services_file="./.credentials_services"
    mkdir -p "$(dirname "$cred_services_file")"
    touch "$cred_services_file"
    chmod 600 "$cred_services_file"
    cat > "$cred_services_file" << EOF
# Configurações dos Serviços - Gerado em $(date)

# qBittorrent
QBITTORRENT_USER="$qbittorrent_user"
QBITTORRENT_PASS="$qbittorrent_pass_fixed"
QBITTORRENT_IP="$qbittorrent_ip"

# Sonarr
SONARR_USER="$sonarr_user"
SONARR_PASS="$sonarr_pass"
SONARR_API="$sonarr_api"
SONARR_IP="$sonarr_ip"

# Radarr
RADARR_USER="$radarr_user"
RADARR_PASS="$radarr_pass"
RADARR_API="$radarr_api"
RADARR_IP="$radarr_ip"

# Prowlarr
PROWLARR_USER="$prowlarr_user"
PROWLARR_PASS="$prowlarr_pass"
PROWLARR_API="$prowlarr_api"
PROWLARR_IP="$prowlarr_ip"

# Outros serviços
HEIMDALL_IP="$heimdall_ip"
TRAEFIK_IP="$traefik_ip"
EOF

log "Configurações salvas em: $cred_services_file"
}

save_credentials_services
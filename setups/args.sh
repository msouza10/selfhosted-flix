#!/usr/bin/env bash

data_path="_data"
sonarr_path=$(find $DOCKER_ROOT_DIR/volumes -maxdepth 1 -type d -name "*sonarr*")
qbittorrent_path=$(find $DOCKER_ROOT_DIR/volumes -maxdepth 1 -type d -name "*qbittorrent*")
radarr_path=$(find $DOCKER_ROOT_DIR/volumes -maxdepth 1 -type d -name "*radarr*")
prowlarr_path=$(find $DOCKER_ROOT_DIR/volumes -maxdepth 1 -type d -name "*prowlarr*")
heimdall_path=$(find $DOCKER_ROOT_DIR/volumes -maxdepth 1 -type d -name "*heimdall*")

# apis of services
sonarr_api="$(sed -n 's#<apikey>\(.*\)</apikey>#\1#p' "$sonarr_path/$data_path/config.xml")"
radarr_api="$(sed -n 's#<apikey>\(.*\)</apikey>#\1#p' "$radarr_path/$data_path/config.xml")"
prowlarr_api="$(sed -n 's#<apikey>\(.*\)</apikey>#\1#p' "$prowlarr_path/$data_path/config.xml")"

# ips of services
qbittorrent_ip="$(docker ps -q | xargs -r docker inspect -f '{{.Name}} - IP: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | grep traefik | head -n 1 | cut -d : -f2 | tr -d '[:space:]')"
sonarr_ip="$(docker ps -q | xargs -r docker inspect -f '{{.Name}} - IP: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | grep sonarr | head -n 1 | cut -d : -f2 | tr -d '[:space:]')"
prowlarr_ip="$(docker ps -q | xargs -r docker inspect -f '{{.Name}} - IP: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | grep prowlarr | head -n 1 | cut -d : -f2 | tr -d '[:space:]')"
radarr_ip="$(docker ps -q | xargs -r docker inspect -f '{{.Name}} - IP: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | grep radarr | head -n 1 | cut -d : -f2 | tr -d '[:space:]')"
heimdall_ip="$(docker ps -q | xargs -r docker inspect -f '{{.Name}} - IP: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | grep heimdall | head -n 1 | cut -d : -f2 | tr -d '[:space:]')"
traefik_ip="$(docker ps -q | xargs -r docker inspect -f '{{.Name}} - IP: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | grep traefik | head -n 1 | cut -d : -f2 | tr -d '[:space:]')"

log "Iniciando configuração dos ambientes..."

print "Precisamos configurar as credenciais dos ambientes, pensando em deixar um ambiente pre-pronto para o uso."

sleep 2
clear


# configuration of qbittorrent
print "\n=== Configuração do qbittorrent ==="

print "Usuario do qbittorrent"

print "1- Criar usuario default"
print "2- Usar usuario personalizado"

ask "Selecione uma opção [1/2]: "

if [[ "$input" =~ ^[1]$ ]]; then
    qbittorrent_user="admin"
    print "Usuario default: $qbittorrent_user"
else
    ask "Digite o usuario para o qbittorrent: "
    qbittorrent_user="$input"
    print "Usuario selecionado: $qbittorrent_user"
fi

print "Senha do qbittorrent"

print "1- Criar senha randomica auto-renovavel"
print "2- Usar senha fixa (recomendado)"

war "A senha não será fixa, você deve verificar a senha no log do container qbittorrent toda a vez que reinicializar."
war "Tambem sera necessario configurar manualmente a senha no sonarr e radarr"

ask "Selecione uma opção [1/2]: "

if [[ "$input" =~ ^[1]$ ]]; then
    print "A senha não será fixa, você deve verificar a senha no log do container qbittorrent toda a vez que reinicializar"
    print "Senha gerada: $(docker logs qbittorrent | grep "The WebUI administrator password" | tail -n 1 | awk '{print $16}')"
else
    ask_pass "Digite a senha para o qbittorrent: "
    print "Senha gerada: $input"
    qbittorrent_pass_fixed="$input"
    salt_qbittorrent="$(python3 based/salt_gen.py --gensalt)"
    hash_qbittorrent="$(python3 based/salt_gen.py --hash "$input")"
    qbittorrent_user="$input:$hash_qbittorrent"
    print "Senha configurada com sucesso!"
fi

# configuration of sonarr
print "\n=== Configuração do Sonarr ==="

print "Usuario do Sonarr"

print "1- Criar usuario default"
print "2- Usar usuario personalizado"

ask "Selecione uma opção [1/2]: "

if [[ "$input" =~ ^[1]$ ]]; then
    sonarr_user="admin"
    print "Usuario default: $sonarr_user"
else
    ask "Digite o usuario para o Sonarr: "
    sonarr_user="$input"
    print "Usuario selecionado: $sonarr_user"
fi

print "Senha do Sonarr"

print "1- Criar senha randomica"
print "2- Usar senha personalizada"

ask "Selecione uma opção [1/2]: "

if [[ "$input" =~ ^[1]$ ]]; then
    sonarr_pass="$(openssl rand -base64 12)"
    print "Senha gerada: $sonarr_pass"
else
    ask_secret "Digite a senha para o Sonarr: "
    sonarr_pass="$input"
    print "Senha configurada com sucesso!"
fi

# configuration of radarr
print "\n=== Configuração do Radarr ==="

print "Usuario do Radarr"

print "1- Criar usuario default"
print "2- Usar usuario personalizado"

ask "Selecione uma opção [1/2]: "

if [[ "$input" =~ ^[1]$ ]]; then
    radarr_user="admin"
    print "Usuario default: $radarr_user"
else
    ask "Digite o usuario para o Radarr: "
    radarr_user="$input"
    print "Usuario selecionado: $radarr_user"
fi

print "Senha do Radarr"

print "1- Criar senha randomica"
print "2- Usar senha personalizada"

ask "Selecione uma opção [1/2]: "

if [[ "$input" =~ ^[1]$ ]]; then
    radarr_pass="$(openssl rand -base64 12)"
    print "Senha gerada: $radarr_pass"
else
    ask_secret "Digite a senha para o Radarr: "
    radarr_pass="$input"
    print "Senha configurada com sucesso!"
fi

# configuration of prowlarr
print "\n=== Configuração do Prowlarr ==="

print "Usuario do Prowlarr"

print "1- Criar usuario default"
print "2- Usar usuario personalizado"

ask "Selecione uma opção [1/2]: "

if [[ "$input" =~ ^[1]$ ]]; then
    prowlarr_user="admin"
    print "Usuario default: $prowlarr_user"
else
    ask "Digite o usuario para o Prowlarr: "
    prowlarr_user="$input"
    print "Usuario selecionado: $prowlarr_user"
fi

print "Senha do Prowlarr"

print "1- Criar senha randomica"
print "2- Usar senha personalizada"

ask "Selecione uma opção [1/2]: "

if [[ "$input" =~ ^[1]$ ]]; then
    prowlarr_pass="$(openssl rand -base64 12)"
    print "Senha gerada: $prowlarr_pass"
else
    ask_secret "Digite a senha para o Prowlarr: "
    prowlarr_pass="$input"
    print "Senha configurada com sucesso!"
fi


# summary of configurations
print "\n=== Resumo das Configurações ==="
print "qBittorrent:"
print "  Usuario: $qbittorrent_user"
print "  Senha: $qbittorrent_pass"
print "  IP: $qbittorrent_ip"

print "\nSonarr:"
print "  Usuario: $sonarr_user"
print "  Senha: $sonarr_pass"
print "  IP: $sonarr_ip"

print "\nRadarr:"
print "  Usuario: $radarr_user"
print "  Senha: $radarr_pass"
print "  API Key: $radarr_api"
print "  IP: $radarr_ip"

print "\nProwlarr:"
print "  Usuario: $prowlarr_user"
print "  Senha: $prowlarr_pass"
print "  API Key: $prowlarr_api"
print "  IP: $prowlarr_ip"

print "\nHeimdall IP: $heimdall_ip"
print "Traefik IP: $traefik_ip"

# exporting variables for use in other scripts
export qbittorrent_user qbittorrent_pass qbittorrent_ip
export sonarr_user sonarr_pass sonarr_ip
export radarr_user radarr_pass radarr_api radarr_ip
export prowlarr_user prowlarr_pass prowlarr_api prowlarr_ip
export heimdall_ip traefik_ip

log "Configuração das credenciais concluída com sucesso!"

# saving config file for future reference
config_file="services_config.env"
mkdir -p configs

cat > "$config_file" << EOF
# Configurações dos Serviços - Gerado em $(date)

# qBittorrent
QBITTORRENT_USER="$qbittorrent_user"
QBITTORRENT_PASS="$qbittorrent_pass"
QBITTORRENT_IP="$qbittorrent_ip"

# Sonarr
SONARR_USER="$sonarr_user"
SONARR_PASS="$sonarr_pass"
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

all_args=("$qbittorrent_user" "$qbittorrent_pass" "$qbittorrent_ip" "$sonarr_user" "$sonarr_pass" "$sonarr_ip" "$radarr_user" "$radarr_pass" "$radarr_api" "$radarr_ip" "$prowlarr_user" "$prowlarr_pass" "$prowlarr_api" "$prowlarr_ip" "$heimdall_ip" "$traefik_ip")

print "Configurações salvas em: $config_file"
print "Você pode consultar este arquivo para verificar as credenciais configuradas."


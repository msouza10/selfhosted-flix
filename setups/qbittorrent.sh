#!/bin/bash

log "Iniciando setup do qbittorrent..."

for i in {3..1}; do
    print "$i"
    sleep 1
done

war "Criando backup do arquivo de configuracao do qbittorrent..."

checking_qbittorrent_credentials() {
    status=$(curl --header "Referer: http://$qbittorrent_ip:8080" \
  --data "username=$qbittorrent_user&password=$qbittorrent_pass_fixed" \
  http://$qbittorrent_ip:8080/api/v2/auth/login 2>/dev/null)

    if [ "$status" == "Ok." ]; then
        log "Credenciais do qbittorrent configuradas com sucesso!"
    else
        err "Erro ao verificar as credenciais do qbittorrent!"
        err "Mensagem: $status"
        err "IP: $qbittorrent_ip"
        err "User: $qbittorrent_user"
        err "Pass: $qbittorrent_pass_fixed"
        err "Para testar manualmente: curl --header "Referer: http://$qbittorrent_ip:8080" --data "username=$qbittorrent_user&password=$qbittorrent_pass_fixed" http://$qbittorrent_ip:8080/api/v2/auth/login"
        exit 1
    fi
}

if cp $PWD/configs/qbittorrent/qBittorrent.conf $PWD/configs/qbittorrent/qBittorrent.conf.backup; then
    log "Backup do arquivo de configuracao do qbittorrent criado com sucesso!"
else
    err "Erro ao criar backup do arquivo de configuracao do qbittorrent!"
    err "Verifique se o arquivo de configuracao existe e se tem permissao de escrita"
    exit 1
fi

# creating backup of qbittorrent.conf
if [[ -f "/opt/backup/qbittorrent/qBittorrent.conf.backup" ]]; then
    print "Backup do arquivo de configuracao do qbittorrent encontrado: /opt/backup/qbittorrent/qBittorrent.conf.backup"
else
    if cp $qbittorrent_path/$data_path/qBittorrent/qBittorrent.conf /opt/backup/qbittorrent/qBittorrent.conf; then
        log "Backup do arquivo de configuracao do qbittorrent criado com sucesso!"
    else
        err "Erro ao criar backup do arquivo de configuracao do qbittorrent!"
        err "Verifique se o arquivo de configuracao existe e se tem permissao de escrita"
        exit 1
    fi
fi

log "Configurando o qbittorrent..."

if [[ "$qbittorrent_user" == "admin" ]]; then
    print "Usuario default: $qbittorrent_user"
    log "Utilize ele para logar no qbittorrent"
else
    log "Usuario personalizado: $qbittorrent_user"
    echo "WebUI\Username=$qbittorrent_user" >> $PWD/configs/qbittorrent/qBittorrent.conf.backup
fi

if [[ -z "$qbittorrent_pass" ]]; then
    log "Senha default: $(docker logs qbittorrent | grep "The WebUI administrator password" | tail -n 1 | awk '{print $16}')"
    war "Utilize ele para logar no qbittorrent, lembrando que a senha não será fixa, você deve verificar a senha no log do container qbittorrent toda a vez que reinicializar."
    war "Tambem sera necessario configurar manualmente a senha no sonarr e radarr"
    exit 1  
else
    log "Senha personalizada em texto pleno: $qbittorrent_pass_fixed"
    log "Senha personalizada em hash+salt: $qbittorrent_pass"
    echo "WebUI\Password_PBKDF2=@ByteArray($qbittorrent_pass)" >> $PWD/configs/qbittorrent/qBittorrent.conf.backup
    docker restart qbittorrent 
fi


log "Configurado com sucesso!"

log "Checando se o arquivo de configuracao do qbittorrent foi criado com sucesso..."

if mv $PWD/configs/qbittorrent/qBittorrent.conf.backup $qbittorrent_path/$data_path/qBittorrent/qBittorrent.conf; then
    log "Arquivo de configuracao do qbittorrent movido com sucesso!"
    docker restart qbittorrent
    sleep 4
    log "Reiniciando o container qbittorrent..."
    if checking_qbittorrent_credentials; then
        log "Credenciais do qbittorrent configuradas com sucesso!"
    else
        err "Falha durante o checking."
        exit 1
    fi
else
    err "Erro ao mover o arquivo de configuracao do qbittorrent!"
    err "Verifique se o arquivo de configuracao existe e se tem permissao de escrita"
    exit 1
fi

log "Setup do qbittorrent finalizado com sucesso!"
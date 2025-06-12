#!/bin/bash

print "Iniciando setup do qbittorrent..."

for i in {3..1}; do
    print "$i"
    sleep 1
done

war "Criando backup do arquivo de configuracao do qbittorrent..."

checking_qbittorrent_credentials() {
    status_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://$qbittorrent_ip:8080/api/v2/auth/login" \
    --data "username=$qbittorrent_user&password=$qbittorrent_pass_fixed" 2>/dev/null)

    if [ "$status_code" == "200" ]; then
        print "Credenciais do qbittorrent configuradas com sucesso!"
    else
        err "Credenciais do qbittorrent não configuradas!"
        err "Verifique se o qbittorrent está rodando e se as credenciais estão corretas"
        err "Se o problema persistir, reinicie o container qbittorrent e verifique os logs"
        exit 1
    fi
}

if cp $PWD/configs/qbittorrent/qBittorrent.conf $PWD/configs/qbittorrent/qBittorrent.conf.backup; then
    print "Backup do arquivo de configuracao do qbittorrent criado com sucesso!"
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
        print "Backup do arquivo de configuracao do qbittorrent criado com sucesso!"
    else
        err "Erro ao criar backup do arquivo de configuracao do qbittorrent!"
        err "Verifique se o arquivo de configuracao existe e se tem permissao de escrita"
        exit 1
    fi
fi

print "Configurando o qbittorrent..."

if [[ "$qbittorrent_user" == "admin" ]]; then
    print "Usuario default: $qbittorrent_user"
    print "Utilize ele para logar no qbittorrent"
else
    print "Usuario personalizado: $qbittorrent_user"
    echo "WebUI\Username=$qbittorrent_user" >> $PWD/configs/qbittorrent/qBittorrent.conf.backup
fi

if [[ -z "$qbittorrent_pass" ]]; then
    print "Senha default: $(docker logs qbittorrent | grep "The WebUI administrator password" | tail -n 1 | awk '{print $16}')"
    war "Utilize ele para logar no qbittorrent, lembrando que a senha não será fixa, você deve verificar a senha no log do container qbittorrent toda a vez que reinicializar."
    war "Tambem sera necessario configurar manualmente a senha no sonarr e radarr"
    exit 1  
else
    print "Senha personalizada em texto pleno: $qbittorrent_pass_fixed"
    print "Senha personalizada em hash+salt: $qbittorrent_pass"
    echo "WebUI\Password_PBKDF2=@ByteArray($qbittorrent_pass)" >> $PWD/configs/qbittorrent/qBittorrent.conf.backup
    docker restart qbittorrent 
fi

print "Configurado com sucesso!"

if mv $PWD/configs/qbittorrent/qBittorrent.conf.backup $qbittorrent_path/$data_path/qBittorrent/qBittorrent.conf; then
    print "Arquivo de configuracao do qbittorrent movido com sucesso!"
    docker restart qbittorrent 
    log "Reiniciando o container qbittorrent..."
    if checking_qbittorrent_credentials; then
        print "Credenciais do qbittorrent configuradas com sucesso!"
    else
        err "Credenciais do qbittorrent não configuradas!"
        err "Verifique se o qbittorrent está rodando e se as credenciais estão corretas"
        err "Se o problema persistir, reinicie o container qbittorrent e verifique os logs"
        exit 1
    fi
else
    err "Erro ao mover o arquivo de configuracao do qbittorrent!"
    err "Verifique se o arquivo de configuracao existe e se tem permissao de escrita"
    exit 1
fi
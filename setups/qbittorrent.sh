#!/bin/bash

checking_qbittorrent_credentials() {
    status_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://$qbittorrent_ip:8080/api/v2/auth/login" \
    --data "username=$qbittorrent_user&password=$qbittorrent_pass" 2>/dev/null)

    if [ "$status_code" == "200" ]; then
        print "Credenciais do qbittorrent configuradas com sucesso!"
    else
        err "Credenciais do qbittorrent não configuradas!"
        err "Verifique se o qbittorrent está rodando e se as credenciais estão corretas"
        err "Se o problema persistir, reinicie o container qbittorrent e verifique os logs"
        exit 1
    fi
}

print "Configurando o qbittorrent..."

if [ "$qbittorrent_user" == "admin" ]; then
    print "Usuario default: $qbittorrent_user"
    print "Utilize ele para logar no qbittorrent"
else
    print "Usuario personalizado: $qbittorrent_user"
    echo "WebUI\Username=$qbittorrent_user" >> $qbittorrent_path/$data_path/qBittorrent.conf
fi

if [ -z "$qbittorrent_pass" ]; then
    print "Senha default: $(docker logs qbittorrent | grep "The WebUI administrator password" | tail -n 1 | awk '{print $16}')"
    war "Utilize ele para logar no qbittorrent, lembrando que a senha não será fixa, você deve verificar a senha no log do container qbittorrent toda a vez que reinicializar."
    war "Tambem sera necessario configurar manualmente a senha no sonarr e radarr"
else
    print "Senha personalizada em texto pleno: $qbittorrent_pass_fixed"
    print "Senha personalizada em hash+salt: $qbittorrent_pass"
    echo "WebUI\Password_PBKDF2="@ByteArray($qbittorrent_pass)"" >> $qbittorrent_path/$data_path/qBittorrent.conf
    docker restart qbittorrent
    checking_qbittorrent_credentials
fi

print "Configurado com sucesso!"
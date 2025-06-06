#!/usr/bin/env bash

print "Iniciando setup do prowlarr..."

sleep 1
print "3..."
sleep 1
print "2..."
sleep 1
print "1..."
sleep 1

war "Criando backup do arquivo de configuracao do prowlarr..."

if [[ -f "$prowlarr_path/$data_path/config.xml" ]]; then
    print "Backup do arquivo de configuracao do prowlarr encontrado: $prowlarr_path/$data_path/config.xml"
    ask "Deseja sobrescrever o backup? [s/N]: "
    sed -i 's/prowlarr_user/'$prowlarr_user'/g' configs/config.xml
    if [[ "$input" =~ ^[sS]$ ]]; then
        print "Sobrescrevendo backup do arquivo de configuracao do prowlarr..."
        cp "$prowlarr_path/$data_path/config.xml" "$backup_dir/prowlarr/config.xml"
        sed -i 's/prowlarr_user/'$prowlarr_user'/g' configs/config.xml
    else
        print "Backup do arquivo de configuracao do prowlarr não sobrescrito!"
    fi
else
    war "Backup do arquivo de configuracao do prowlarr não encontrado: $prowlarr_path/$data_path/config.xml"
    print "Criando backup do arquivo de configuracao do prowlarr..."
    cp "$prowlarr_path/$data_path/config.xml" "$backup_dir/prowlarr/config.xml"
fi

if [[ -f configs/config.xml.backup ]]; then
    print "Arquivo de configuracao template backup encontrado: configs/config.xml.backup"
else
    war "Arquivo de configuracao não encontrado: configs/config.xml.backup" 
    cp configs/config.xml configs/config.xml.backup
fi

print "buildando arquivo de configuracao do prowlarr..."

if sed -i 's/prowlarr_user/'$prowlarr_user'/g' configs/config.xml; then
    print "Arquivo de configuracao do prowlarr atualizado com sucesso!"
else
    err "Erro ao atualizar o arquivo de configuracao do prowlarr!"
    war "verifique se o arquivo de configuracao existe e se tem permissão de escrita"
    exit 1
fi


war "Criando backup do banco atual do prowlarr..."

if [[ -f "$backup_dir/prowlarr/prowlarr.db" ]]; then
    print "Backup do banco de dados do prowlarr encontrado: $backup_dir/prowlarr/prowlarr.db"
    ask "Deseja sobrescrever o backup? [s/N]: "
    if [[ "$input" =~ ^[sS]$ ]]; then
        print "Sobrescrevendo backup do banco de dados do prowlarr..."
        cp "$prowlarr_path/$data_path/prowlarr.db" "$backup_dir/prowlarr/prowlarr.db"
    else
        print "Backup do banco de dados do prowlarr não sobrescrito!"
    fi
else
    war "Backup do banco de dados do prowlarr não encontrado: $backup_dir/prowlarr/prowlarr.db"
    print "Criando backup do banco de dados do prowlarr..."
    cp "$prowlarr_path/$data_path/prowlarr.db" "$backup_dir/prowlarr/prowlarr.db"
fi

print "Configurando o prowlarr..."

if [[ -f "configs/prowlarr.db.backup" ]]; then
    print "Arquivo de banco de dados template backup encontrado: configs/prowlarr.db.backup"
else
    err "Arquivo de banco de dados não encontrado: configs/prowlarr.db.backup"
    cp configs/prowlarr.db configs/prowlarr.db.backup
fi

print "Adicionando dados do qbittorrent ao banco de dados do prowlarr..."

if [[ $qbittorrent_user == "admin" ]]; then
    print "usuario default: $qbittorrent_user, para uso no banco de dados do prowlarr"
    sqlite3 configs/prowlarr.db "UPDATE DownloadClient SET DownloadClients = replace(DownloadClients, 'qbittorrent_user', '$qbittorrent_user') where DownloadClients like '%qbittorrent_user%'"
else
    print "usuario personalizado: $qbittorrent_user, para uso no banco de dados do prowlarr"
    sqlite3 configs/prowlarr.db "UPDATE DownloadClient SET DownloadClients = replace(DownloadClients, 'qbittorrent_user', '$qbittorrent_user') where DownloadClients like '%qbittorrent_user%'"
fi

if [[ -z $qbittorrent_pass_fixed ]]; then
    print "senha default: $qbittorrent_pass_fixed, para uso no banco de dados do prowlarr"
    sqlite3 configs/prowlarr.db "UPDATE DownloadClient SET DownloadClients = replace(DownloadClients, 'qbittorrent_pass', '$qbittorrent_pass') where DownloadClients like '%qbittorrent_pass%'"
else
    war "A senha nao esta fixa por isso sera necessario configurar manualmente a senha no prowlarr"
fi


if sqlite3 configs/prowlarr.db "UPDATE DownloadClient SET DownloadClients = replace(DownloadClients, 'qbittorrent_ip', '$qbittorrent_ip') where DownloadClients like '%qbittorrent_ip%'" ; then
    print "IP do qbittorrent adicionado com sucesso! $qbittorrent_ip"
else
    err "Erro ao adicionar o IP do qbittorrent!"
    war "Caso nao queira adicionar o IP do qbittorrent, pode continuar o script e adicionar manualmente no prowlarr"
    ask "Deseja continuar? [s/N]: "
    if [[ "$input" =~ ^[sS]$ ]]; then
        war "adicione o IP manualmente no banco de dados do prowlarr"
    else
        err "script encerrado."
        exit 1
    fi
fi

print "dados do qbittorrent adicionados com sucesso!"

if [[ -z "$prowlarr_user" ]]; then
    print "usuario default: $prowlarr_user, para uso no banco de dados do prowlarr"
    sqlite3 configs/prowlarr.db "UPDATE Users SET Username = '$prowlarr_user' WHERE Id = 1"
else
    print "usuario personalizado: $prowlarr_user, para uso no banco de dados do prowlarr"
    sqlite3 configs/prowlarr.db "UPDATE Users SET Username = '$prowlarr_user' WHERE Id = 1"
fi

if [[ -z "$prowlarr_pass" ]]; then
    print "senha default: $prowlarr_pass"
    sqlite3 configs/prowlarr.db "UPDATE Users SET Password = '$prowlarr_pass' WHERE Id = 1"
else
    print "senha personalizada: $prowlarr_pass"
    sqlite3 configs/prowlarr.db "UPDATE Users SET Password = '$prowlarr_pass' WHERE Id = 1"
fi  

if [[ -z "$prowlarr_ip" ]]; then
    print "ip: $prowlarr_ip, para uso no banco de dados do prowlarr"
    sqlite3 configs/prowlarr.db "UPDATE DownloadClient SET Applications = replace(Applications, 'prowlarr_ip', '$prowlarr_ip') where Applications like '%prowlarr_ip%'"
else
    war "ip nao identificado, por isso nao sera adicionado ao banco de dados do prowlarr"
    ask "Deseja continuar? [s/N]: "
    if [[ "$input" =~ ^[sS]$ ]]; then
        print "Continuando..."
    else
        err "script encerrado."
        exit 1
    fi
fi

print "dados do prowlarr adicionados com sucesso!"

print "Adicionando dados do radarr ao banco de dados do prowlarr..."

if [[ -z "$radarr_api" ]]; then
    print "api: $radarr_api, para uso no banco de dados do prowlarr"
    sqlite3 configs/prowlarr.db "UPDATE DownloadClient SET Applications = replace(Applications, 'radarr_api', '$radarr_api') where Applications like '%radarr_api%'"
else
    war "api nao setada, por isso nao sera adicionada ao banco de dados do prowlarr"
    war "Caso nao queira adicionar a api do radarr, pode continuar o script e adicionar manualmente no prowlarr"
    ask "Deseja continuar? [s/N]: "
    if [[ "$input" =~ ^[sS]$ ]]; then
        print "Continuando..."
    else
        err "script encerrado."
        exit 1
    fi
fi

if [[ -z "$radarr_ip" ]]; then
    print "ip default: $radarr_ip, para uso no banco de dados do prowlarr"
    sqlite3 configs/prowlarr.db "UPDATE DownloadClient SET Applications = replace(Applications, 'radarr_ip', '$radarr_ip') where Applications like '%radarr_ip%'"
else
    war "ip nao identificado, por isso nao sera adicionado ao banco de dados do prowlarr"
    war "Caso nao queira adicionar o IP do radarr, pode continuar o script e adicionar manualmente no prowlarr"
    ask "Deseja continuar? [s/N]: "
    if [[ "$input" =~ ^[sS]$ ]]; then
        print "Continuando..."
    else
        err "script encerrado."
        exit 1
    fi
fi

print "dados do radarr adicionados com sucesso!"

print "Adicionando dados do sonarr ao banco de dados do prowlarr..."

if [[ -z "$sonarr_api" ]]; then
    print "api: $sonarr_api, para uso no banco de dados do prowlarr"
    sqlite3 configs/prowlarr.db "UPDATE DownloadClient SET Applications = replace(Applications, 'sonarr_api', '$sonarr_api') where Applications like '%sonarr_api%'"
else
    war "api nao setada, por isso nao sera adicionada ao banco de dados do prowlarr"
    war "Caso nao queira adicionar a api do sonarr, pode continuar o script e adicionar manualmente no prowlarr"
    ask "Deseja continuar? [s/N]: "
    if [[ "$input" =~ ^[sS]$ ]]; then
        print "Continuando..."
    else
        err "script encerrado."
        exit 1
    fi
fi

if [[ -z "$sonarr_ip" ]]; then
    print "ip: $sonarr_ip, para uso no banco de dados do prowlarr"
    sqlite3 configs/prowlarr.db "UPDATE DownloadClient SET Applications = replace(Applications, 'sonarr_ip', '$sonarr_ip') where Applications like '%sonarr_ip%'"
else
    war "ip nao identificado, por isso nao sera adicionado ao banco de dados do prowlarr"
    war "Caso nao queira adicionar o IP do sonarr, pode continuar o script e adicionar manualmente no prowlarr"
    ask "Deseja continuar? [s/N]: "
    if [[ "$input" =~ ^[sS]$ ]]; then
        print "Continuando..."
    else
        err "script encerrado."
        exit 1
    fi
fi

print "dados do sonarr adicionados com sucesso!"



if sqlite3 configs/prowlarr.db "PRAGMA integrity_check"; then
    print "integridade do banco de dados template do prowlarr ok!"
    if mv "configs/prowlarr.db" "$prowlarr_path/$data_path/prowlarr.db"; then
        print "banco de dados template do prowlarr movido com sucesso!"
        if mv "configs/config.xml" "$prowlarr_path/$data_path/config.xml"; then
            print "arquivo de configuracao template do prowlarr movido com sucesso!"
        else
            err "Erro ao mover o arquivo de configuracao template do prowlarr!"
            err "Verifique se o arquivo de configuracao existe e se tem permissão de escrita"
            exit 1
        fi
    else
        err "Erro ao mover o banco de dados template do prowlarr!"
        err "Verifique se o arquivo de banco de dados existe e se tem permissão de escrita"
        exit 1
    fi
else
    war "integridade do banco de dados template do prowlarr nao ok!"
    mv configs/prowlarr.db configs/prowlarr.db-corrupted
    exit 1
fi

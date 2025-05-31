#!/usr/bin/env bash

print "Iniciando setup do sonarr..."

sleep 1
print "3..."
sleep 1
print "2..."
sleep 1
print "1..."
sleep 1

war "Criando backup do arquivo de configuracao do sonarr..."

if [[ -f "$sonarr_path/$data_path/config.xml" ]]; then
    print "Backup do arquivo de configuracao do sonarr encontrado: $sonarr_path/$data_path/config.xml"
    ask "Deseja sobrescrever o backup? [s/N]: "
    if [[ "$input" =~ ^[sS]$ ]]; then
        print "Sobrescrevendo backup do arquivo de configuracao do sonarr..."
        cp "$sonarr_path/$data_path/config.xml" "$backup_dir/sonarr/config.xml"
    else
        print "Backup do arquivo de configuracao do sonarr não sobrescrito!"
    fi
else
    war "Backup do arquivo de configuracao do sonarr não encontrado: $sonarr_path/$data_path/config.xml"
    print "Criando backup do arquivo de configuracao do sonarr..."
    cp "$sonarr_path/$data_path/config.xml" "$backup_dir/sonarr/config.xml"
fi

if [[ -f configs/config.xml.backup ]]; then
    print "Arquivo de configuracao template backup encontrado: configs/config.xml.backup"
else
    war "Arquivo de configuracao não encontrado: configs/config.xml.backup" 
    cp configs/config.xml configs/config.xml.backup
fi

print "buildando arquivo de configuracao do sonarr..."

if sed -i 's/sonarr_user/'$sonarr_user'/g' configs/config.xml; then
    print "Arquivo de configuracao do sonarr atualizado com sucesso!"
else
    err "Erro ao atualizar o arquivo de configuracao do sonarr!"
    war "verifique se o arquivo de configuracao existe e se tem permissão de escrita"
    exit 1
fi


war "Criando backup do banco atual do sonarr..."

if [[ -f "$backup_dir/sonarr/sonarr.db" ]]; then
    print "Backup do banco de dados do sonarr encontrado: $backup_dir/sonarr/sonarr.db"
    ask "Deseja sobrescrever o backup? [s/N]: "
    if [[ "$input" =~ ^[sS]$ ]]; then
        print "Sobrescrevendo backup do banco de dados do sonarr..."
        cp "$sonarr_path/$data_path/sonarr.db" "$backup_dir/sonarr/sonarr.db"
    else
        print "Backup do banco de dados do sonarr não sobrescrito!"
    fi
else
    war "Backup do banco de dados do sonarr não encontrado: $backup_dir/sonarr/sonarr.db"
    print "Criando backup do banco de dados do sonarr..."
    cp "$sonarr_path/$data_path/sonarr.db" "$backup_dir/sonarr/sonarr.db"
fi

print "Configurando o sonarr..."

if [[ -f "configs/sonarr.db.backup" ]]; then
    print "Arquivo de banco de dados template backup encontrado: configs/sonarr.db.backup"
else
    err "Arquivo de banco de dados não encontrado: configs/sonarr.db.backup"
    cp configs/sonarr.db configs/sonarr.db.backup
fi

print "Adicionando dados do qbittorrent ao banco de dados do sonarr..."

if [[ $qbittorrent_user == "admin" ]]; then
    print "usuario default: $qbittorrent_user, para uso no banco de dados do sonarr"
    sqlite3 configs/sonarr.db "UPDATE DownloadClient SET DownloadClients = replace(DownloadClients, 'qbittorrent_user', '$qbittorrent_user') where DownloadClients like '%qbittorrent_user%'"
else
    print "usuario personalizado: $qbittorrent_user, para uso no banco de dados do sonarr"
    sqlite3 configs/sonarr.db "UPDATE DownloadClient SET DownloadClients = replace(DownloadClients, 'qbittorrent_user', '$qbittorrent_user') where DownloadClients like '%qbittorrent_user%'"
fi

if [[ -z $qbittorrent_pass_fixed ]]; then
    print "senha default: $qbittorrent_pass_fixed, para uso no banco de dados do sonarr"
    sqlite3 configs/sonarr.db "UPDATE DownloadClient SET DownloadClients = replace(DownloadClients, 'qbittorrent_pass', '$qbittorrent_pass') where DownloadClients like '%qbittorrent_pass%'"
else
    war "A senha nao esta fixa por isso sera necessario configurar manualmente a senha no sonarr"
fi


if sqlite3 configs/sonarr.db "UPDATE DownloadClient SET DownloadClients = replace(DownloadClients, 'qbittorrent_ip', '$qbittorrent_ip') where DownloadClients like '%qbittorrent_ip%'" ; then
    print "IP do qbittorrent adicionado com sucesso! $qbittorrent_ip"
else
    err "Erro ao adicionar o IP do qbittorrent!"
    war "adicione o IP manualmente no banco de dados do sonarr"
fi

print "dados do qbittorrent adicionados com sucesso!"

if [[ -z "$sonarr_user" ]]; then
    print "usuario default: $sonarr_user, para uso no banco de dados do sonarr"
    sqlite3 configs/sonarr.db "UPDATE Users SET Username = '$sonarr_user' WHERE Id = 1"
else
    print "usuario personalizado: $sonarr_user, para uso no banco de dados do sonarr"
    sqlite3 configs/sonarr.db "UPDATE Users SET Username = '$sonarr_user' WHERE Id = 1"
fi

if [[ -z "$sonarr_pass" ]]; then
    print "senha default: $sonarr_pass"
    sqlite3 configs/sonarr.db "UPDATE Users SET Password = '$sonarr_pass' WHERE Id = 1"
else
    print "senha personalizada: $sonarr_pass"
    sqlite3 configs/sonarr.db "UPDATE Users SET Password = '$sonarr_pass' WHERE Id = 1"
fi

print "dados do sonarr adicionados com sucesso!"

print "verificando integridade do banco de dados template do sonarr antes de mover para o sonarr..."

if sqlite3 configs/sonarr.db "PRAGMA integrity_check"; then
    print "integridade do banco de dados template do sonarr ok!"
    if mv "configs/sonarr.db" "$sonarr_path/$data_path/sonarr.db"; then
        print "banco de dados template do sonarr movido com sucesso!"
        if mv "configs/config.xml" "$sonarr_path/$data_path/config.xml"; then
            print "arquivo de configuracao template do sonarr movido com sucesso!"
        else
            err "Erro ao mover o arquivo de configuracao template do sonarr!"
            err "Verifique se o arquivo de configuracao existe e se tem permissão de escrita"
            exit 1
        fi
    else
        err "Erro ao mover o banco de dados template do sonarr!"
        err "Verifique se o arquivo de banco de dados existe e se tem permissão de escrita"
        exit 1
    fi
else
    war "integridade do banco de dados template do sonarr nao ok!"
    mv configs/sonarr.db configs/sonarr.db-corrupted
    exit 1
fi

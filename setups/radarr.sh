#!/usr/bin/env bash

print "Iniciando setup do radarr..."

sleep 1
print "3..."
sleep 1
print "2..."
sleep 1
print "1..."
sleep 1

war "Criando backup do arquivo de configuracao do radarr..."

if [[ -f "$radarr_path/$data_path/config.xml" ]]; then
    print "Backup do arquivo de configuracao do radarr encontrado: $radarr_path/$data_path/config.xml"
    ask "Deseja sobrescrever o backup? [s/N]: "
    if [[ "$input" =~ ^[sS]$ ]]; then
        print "Sobrescrevendo backup do arquivo de configuracao do radarr..."
        cp "$radarr_path/$data_path/config.xml" "$backup_dir/radarr/config.xml"
    else
        print "Backup do arquivo de configuracao do radarr não sobrescrito!"
    fi
else
    war "Backup do arquivo de configuracao do radarr não encontrado: $radarr_path/$data_path/config.xml"
    print "Criando backup do arquivo de configuracao do radarr..."
    cp "$radarr_path/$data_path/config.xml" "$backup_dir/radarr/config.xml"
fi

if [[ -f configs/config.xml.backup ]]; then
    print "Arquivo de configuracao template backup encontrado: configs/config.xml.backup"
else
    war "Arquivo de configuracao não encontrado: configs/config.xml.backup" 
    cp configs/config.xml configs/config.xml.backup
fi

print "buildando arquivo de configuracao do radarr..."

if sed -i 's/radarr_user/'$radarr_user'/g' configs/config.xml; then
    print "Arquivo de configuracao do radarr atualizado com sucesso!"
else
    err "Erro ao atualizar o arquivo de configuracao do radarr!"
    war "verifique se o arquivo de configuracao existe e se tem permissão de escrita"
    exit 1
fi


war "Criando backup do banco atual do radarr..."

if [[ -f "$backup_dir/radarr/radarr.db" ]]; then
    print "Backup do banco de dados do radarr encontrado: $backup_dir/radarr/radarr.db"
    ask "Deseja sobrescrever o backup? [s/N]: "
    if [[ "$input" =~ ^[sS]$ ]]; then
        print "Sobrescrevendo backup do banco de dados do radarr..."
        cp "$radarr_path/$data_path/radarr.db" "$backup_dir/radarr/radarr.db"
    else
        print "Backup do banco de dados do radarr não sobrescrito!"
    fi
else
    war "Backup do banco de dados do radarr não encontrado: $backup_dir/radarr/radarr.db"
    print "Criando backup do banco de dados do radarr..."
    cp "$radarr_path/$data_path/radarr.db" "$backup_dir/radarr/radarr.db"
fi

print "Configurando o radarr..."

if [[ -f "configs/radarr.db.backup" ]]; then
    print "Arquivo de banco de dados template backup encontrado: configs/radarr.db.backup"
else
    err "Arquivo de banco de dados não encontrado: configs/radarr.db.backup"
    cp configs/radarr.db configs/radarr.db.backup
fi

print "Adicionando dados do qbittorrent ao banco de dados do radarr..."

if [[ $qbittorrent_user == "admin" ]]; then
    print "usuario default: $qbittorrent_user, para uso no banco de dados do radarr"
    sqlite3 configs/radarr.db "UPDATE DownloadClient SET DownloadClients = replace(DownloadClients, 'qbittorrent_user', '$qbittorrent_user') where DownloadClients like '%qbittorrent_user%'"
else
    print "usuario personalizado: $qbittorrent_user, para uso no banco de dados do radarr"
    sqlite3 configs/radarr.db "UPDATE DownloadClient SET DownloadClients = replace(DownloadClients, 'qbittorrent_user', '$qbittorrent_user') where DownloadClients like '%qbittorrent_user%'"
fi

if [[ -z $qbittorrent_pass_fixed ]]; then
    print "senha default: $qbittorrent_pass_fixed, para uso no banco de dados do radarr"
    sqlite3 configs/radarr.db "UPDATE DownloadClient SET DownloadClients = replace(DownloadClients, 'qbittorrent_pass', '$qbittorrent_pass') where DownloadClients like '%qbittorrent_pass%'"
else
    war "A senha nao esta fixa por isso sera necessario configurar manualmente a senha no radarr"
fi


if sqlite3 configs/radarr.db "UPDATE DownloadClient SET DownloadClients = replace(DownloadClients, 'qbittorrent_ip', '$qbittorrent_ip') where DownloadClients like '%qbittorrent_ip%'" ; then
    print "IP do qbittorrent adicionado com sucesso! $qbittorrent_ip"
else
    err "Erro ao adicionar o IP do qbittorrent!"
    war "adicione o IP manualmente no banco de dados do radarr"
fi

print "dados do qbittorrent adicionados com sucesso!"

if [[ -z "$radarr_user" ]]; then
    print "usuario default: $radarr_user, para uso no banco de dados do radarr"
    sqlite3 configs/radarr.db "UPDATE Users SET Username = '$radarr_user' WHERE Id = 1"
else
    print "usuario personalizado: $radarr_user, para uso no banco de dados do radarr"
    sqlite3 configs/radarr.db "UPDATE Users SET Username = '$radarr_user' WHERE Id = 1"
fi

if [[ -z "$radarr_pass" ]]; then
    print "senha default: $radarr_pass"
    sqlite3 configs/radarr.db "UPDATE Users SET Password = '$radarr_pass' WHERE Id = 1"
else
    print "senha personalizada: $radarr_pass"
    sqlite3 configs/radarr.db "UPDATE Users SET Password = '$radarr_pass' WHERE Id = 1"
fi

print "dados do radarr adicionados com sucesso!"

print "verificando integridade do banco de dados template do radarr antes de mover para o radarr..."

if sqlite3 configs/radarr.db "PRAGMA integrity_check"; then
    print "integridade do banco de dados template do radarr ok!"
    if mv "configs/radarr.db" "$radarr_path/$data_path/radarr.db"; then
        print "banco de dados template do radarr movido com sucesso!"
        if mv "configs/config.xml" "$radarr_path/$data_path/config.xml"; then
            print "arquivo de configuracao template do radarr movido com sucesso!"
        else
            err "Erro ao mover o arquivo de configuracao template do radarr!"
            err "Verifique se o arquivo de configuracao existe e se tem permissão de escrita"
            exit 1
        fi
    else
        err "Erro ao mover o banco de dados template do radarr!"
        err "Verifique se o arquivo de banco de dados existe e se tem permissão de escrita"
        exit 1
    fi
else
    war "integridade do banco de dados template do radarr nao ok!"
    mv configs/radarr.db configs/radarr.db-corrupted
    exit 1
fi
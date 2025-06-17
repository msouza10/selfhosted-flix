#!/usr/bin/env bash

print "Iniciando setup do sonarr..."

for i in {3..1}; do
    print "$i"
    sleep 1
done

log "Backup do banco de dados do sonarr..."

if [[ -f "$backup_dir/sonarr/sonarr.db" ]]; then
    war "Backup do banco de dados do sonarr encontrado: $backup_dir/sonarr/sonarr.db"
    ask "Deseja sobrescrever o backup? [s/N]: "
    if [[ "$input" =~ ^[sS]$ ]]; then
        log "Sobrescrevendo backup do banco de dados do sonarr..."
        cp "$sonarr_path/$data_path/sonarr.db" "$backup_dir/sonarr/sonarr.db"
    else
        log "Backup do banco de dados do sonarr não sobrescrito!"
    fi
else
    war "Backup do banco de dados do sonarr não encontrado: $backup_dir/sonarr/sonarr.db"
    log "Criando backup do banco de dados do sonarr..."
    cp "$sonarr_path/$data_path/sonarr.db" "$backup_dir/sonarr/sonarr.db"
fi

log "Backup do banco de dados template do radarr..."

if [[ -f "$PWD/configs/sonarr/sonarr.db.backup" ]]; then
    war "Backup do banco de dados template do sonarr encontrado: $PWD/configs/sonarr/sonarr.db.backup"
    ask "Deseja sobrescrever o backup? [s/N]: "
    if [[ "$input" =~ ^[sS]$ ]]; then
        log "Sobrescrevendo backup do banco de dados template do sonarr..."
        cp "$PWD/configs/sonarr/sonarr.db" "$PWD/configs/sonarr/sonarr.db.backup"
    else
        log "Backup do banco de dados template do sonarr não sobrescrito!"
    fi
else
    war "Backup do banco de dados template do sonarr não encontrado: $PWD/configs/sonarr/sonarr.db.backup"
    log "Criando backup do banco de dados template do sonarr..."
    cp "$PWD/configs/sonarr/sonarr.db" "$PWD/configs/sonarr/sonarr.db.backup"
fi

log "Configurando o sonarr..."

log "Adicionando dados do qbittorrent ao banco de dados do sonarr..."

if [[ $qbittorrent_user == "admin" ]]; then
    log "usuario default: $qbittorrent_user, para uso no banco de dados do sonarr"
    sqlite3 $PWD/configs/sonarr/sonarr.db "UPDATE DownloadClients SET Settings = replace(Settings, 'qbittorrent_user', '$qbittorrent_user') where Settings like '%qbittorrent_user%'"
else
    log "usuario personalizado: $qbittorrent_user, para uso no banco de dados do sonarr"
    sqlite3 $PWD/configs/sonarr/sonarr.db "UPDATE DownloadClients SET Settings = replace(Settings, 'qbittorrent_user', '$qbittorrent_user') where Settings like '%qbittorrent_user%'"
fi

if [[ -z $qbittorrent_pass_fixed ]]; then
    log "senha default: $qbittorrent_pass_fixed, para uso no banco de dados do sonarr"
    sqlite3 $PWD/configs/sonarr/sonarr.db "UPDATE DownloadClients SET Settings = replace(Settings, 'qbittorrent_pass', '$qbittorrent_pass') where Settings like '%qbittorrent_pass%'"
else
    war "A senha nao esta fixa por isso sera necessario configurar manualmente a senha no sonarr"
fi

if sqlite3 $PWD/configs/sonarr/sonarr.db "UPDATE DownloadClients SET Settings = replace(Settings, 'qbittorrent_ip', '$qbittorrent_ip') where Settings like '%qbittorrent_ip%'" ; then
    log "IP do qbittorrent adicionado com sucesso! $qbittorrent_ip"
else
    err "Erro ao adicionar o IP do qbittorrent!"
    war "adicione o IP manualmente no banco de dados do sonarr"
fi

log "dados do qbittorrent adicionados com sucesso!"

if [[ -z "$sonarr_user" ]]; then
    log "usuario: $sonarr_user, para uso no banco de dados do sonarr"
    sqlite3 $PWD/configs/sonarr/sonarr.db "UPDATE Users SET Username = '$sonarr_user' WHERE Id = 1"
fi

if [[ -z "$sonarr_pass" ]]; then
    log "senha default: $sonarr_pass"
    sqlite3 $PWD/configs/sonarr/sonarr.db "UPDATE Users SET Password = '$sonarr_pass' WHERE Id = 1"
else
    log "senha personalizada: $sonarr_pass"
    sqlite3 $PWD/configs/sonarr/sonarr.db "UPDATE Users SET Password = '$sonarr_pass' WHERE Id = 1"
fi

log "dados do sonarr adicionados com sucesso!"

log "verificando integridade do banco de dados template do sonarr antes de mover para o sonarr..."

if sqlite3 $PWD/configs/sonarr/sonarr.db "PRAGMA integrity_check"; then
    log "integridade do banco de dados template do sonarr ok!"
    if mv "$PWD/configs/sonarr/sonarr.db" "$sonarr_path/$data_path/sonarr.db"; then
        log "banco de dados template do sonarr movido com sucesso!"
        docker restart sonarr
        if mv "$PWD/configs/sonarr/config.xml" "$sonarr_path/$data_path/config.xml"; then
            log "arquivo de configuracao template do sonarr movido com sucesso!"
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
    mv $PWD/configs/sonarr/sonarr.db $PWD/configs/sonarr/sonarr.db-corrupted
    exit 1
fi

if mv $PWD/configs/sonarr/sonarr.db.backup $PWD/configs/sonarr/sonarr.db; then
    log "banco de dados template do sonarr restaurado com sucesso!"
else
    err "Erro ao restaurar o banco de dados template do sonarr!"
    err "Verifique se o arquivo de banco de dados backup existe e se tem permissão de escrita"
    exit 1
fi
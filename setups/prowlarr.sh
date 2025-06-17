#!/usr/bin/env bash

log "Iniciando setup do prowlarr..."

for i in {3..1}; do
    print "$i"
    sleep 1
done

log "Criando backup do banco atual do prowlarr..."

if [[ -f "$backup_dir/prowlarr/prowlarr.db" ]]; then
    war "Backup do banco de dados do prowlarr encontrado: $backup_dir/prowlarr/prowlarr.db"
    ask "Deseja sobrescrever o backup? [s/N]: "
    if [[ "$input" =~ ^[sS]$ ]]; then
        log "Sobrescrevendo backup do banco de dados do prowlarr..."
        cp "$prowlarr_path/$data_path/prowlarr.db" "$backup_dir/prowlarr/prowlarr.db"
    else
        war "Backup do banco de dados do prowlarr não sobrescrito!"
    fi
else
    war "Backup do banco de dados do prowlarr não encontrado: $backup_dir/prowlarr/prowlarr.db"
    log "Criando backup do banco de dados do prowlarr..."
    cp "$prowlarr_path/$data_path/prowlarr.db" "$backup_dir/prowlarr/prowlarr.db"
fi

log "Criando backup do banco de dados template do prowlarr..."

if [[ -f "$PWD/configs/prowlarr/prowlarr.db.backup" ]]; then
    war "Backup do banco de dados template do prowlarr encontrado: $PWD/configs/prowlarr/prowlarr.db.backup"
    ask "Deseja sobrescrever o backup? [s/N]: "
    if [[ "$input" =~ ^[sS]$ ]]; then
        log "Sobrescrevendo backup do banco de dados template do prowlarr..."
        cp "$PWD/configs/prowlarr/prowlarr.db" "$PWD/configs/prowlarr/prowlarr.db.backup"
    else
        war "Backup do banco de dados template do prowlarr não sobrescrito!"
    fi
else
    war "Backup do banco de dados template do prowlarr não encontrado: $PWD/configs/prowlarr/prowlarr.db.backup"
    log "Criando backup do banco de dados template do prowlarr..."
    cp "$PWD/configs/prowlarr/prowlarr.db" "$PWD/configs/prowlarr/prowlarr.db.backup"
fi

log "Adicionando dados do qbittorrent ao banco de dados do prowlarr..."

if [[ "$qbittorrent_user" == "admin" ]]; then
    log "usuario default: $qbittorrent_user, para uso no banco de dados do prowlarr"
    sqlite3 $PWD/configs/prowlarr/prowlarr.db "UPDATE DownloadClients SET Settings = replace(Settings, 'qbittorrent_user', '$qbittorrent_user') where Settings like '%qbittorrent_user%'"
else
    log "usuario personalizado: $qbittorrent_user, para uso no banco de dados do prowlarr"
    sqlite3 $PWD/configs/prowlarr/prowlarr.db "UPDATE DownloadClients SET Settings = replace(Settings, 'qbittorrent_user', '$qbittorrent_user') where Settings like '%qbittorrent_user%'"
fi

if [[ -n "$qbittorrent_pass_fixed" ]]; then
    log "senha default: $qbittorrent_pass_fixed, para uso no banco de dados do prowlarr"
    sqlite3 $PWD/configs/prowlarr/prowlarr.db "UPDATE DownloadClients SET Settings = replace(Settings, 'qbittorrent_pass', '$qbittorrent_pass') where Settings like '%qbittorrent_pass%'"
else
    war "A senha nao esta fixa por isso sera necessario configurar manualmente a senha no prowlarr"
fi

if [[ -n "$qbittorrent_ip" ]]; then
    log "ip default: $qbittorrent_ip, para uso no banco de dados do prowlarr"
    sqlite3 $PWD/configs/prowlarr/prowlarr.db "UPDATE DownloadClients SET Settings = replace(Settings, 'qbittorrent_ip', '$qbittorrent_ip') where Settings like '%qbittorrent_ip%'"
else
    war "ip nao identificado, por isso nao sera adicionado ao banco de dados do prowlarr"
    war "adicione o IP manualmente no banco de dados do prowlarr"
fi

log "dados do qbittorrent adicionados com sucesso!"

if [[ -n "$prowlarr_user" ]]; then
    log "usuario default: $prowlarr_user, para uso no banco de dados do prowlarr"
    sqlite3 $PWD/configs/prowlarr/prowlarr.db "UPDATE Users SET Username = '$prowlarr_user' WHERE Id = 1"
else
    log "usuario personalizado: $prowlarr_user, para uso no banco de dados do prowlarr"
    sqlite3 $PWD/configs/prowlarr/prowlarr.db "UPDATE Users SET Username = '$prowlarr_user' WHERE Id = 1"
fi

if [[ -n "$prowlarr_pass" ]]; then
    log "senha default: $prowlarr_pass"
    sqlite3 $PWD/configs/prowlarr/prowlarr.db "UPDATE Users SET Password = '$prowlarr_pass' WHERE Id = 1"
else
    log "senha personalizada: $prowlarr_pass"
    sqlite3 $PWD/configs/prowlarr/prowlarr.db "UPDATE Users SET Password = '$prowlarr_pass' WHERE Id = 1"
fi  

if [[ -n "$prowlarr_ip" ]]; then
    log "ip default: $prowlarr_ip, para uso no banco de dados do prowlarr"
    sqlite3 $PWD/configs/prowlarr/prowlarr.db "UPDATE DownloadClients SET Settings = replace(Settings, 'prowlarr_ip', '$prowlarr_ip') where Settings like '%prowlarr_ip%'"
else
    war "ip nao identificado, por isso nao sera adicionado ao banco de dados do prowlarr"
    war "adicione o IP manualmente no banco de dados do prowlarr"
fi

log "dados do prowlarr adicionados com sucesso!"

log "Adicionando dados do radarr ao banco de dados do prowlarr..."

if [[ -n "$radarr_api" ]]; then
    log "api: $radarr_api, para uso no banco de dados do prowlarr"
    sqlite3 $PWD/configs/prowlarr/prowlarr.db "UPDATE DownloadClients SET Settings = replace(Settings, 'radarr_api', '$radarr_api') where Settings like '%radarr_api%'"
else
    war "api nao setada, por isso nao sera adicionada ao banco de dados do prowlarr"
    war "adicione a api manualmente no banco de dados do prowlarr"
fi

if [[ -n "$radarr_ip" ]]; then
    log "ip default: $radarr_ip, para uso no banco de dados do prowlarr"
    sqlite3 $PWD/configs/prowlarr/prowlarr.db "UPDATE DownloadClients SET Settings = replace(Settings, 'radarr_ip', '$radarr_ip') where Settings like '%radarr_ip%'"
else
    war "ip nao identificado, por isso nao sera adicionado ao banco de dados do prowlarr"
    war "adicione o IP manualmente no banco de dados do prowlarr"
fi

log "dados do radarr adicionados com sucesso!"

log "Adicionando dados do sonarr ao banco de dados do prowlarr..."

if [[ -n "$sonarr_api" ]]; then
    log "api: $sonarr_api, para uso no banco de dados do prowlarr"
    sqlite3 $PWD/configs/prowlarr/prowlarr.db "UPDATE DownloadClients SET Settings = replace(Settings, 'sonarr_api', '$sonarr_api') where Settings like '%sonarr_api%'"
else
    war "api nao setada, por isso nao sera adicionada ao banco de dados do prowlarr"
    war "adicione a api manualmente no banco de dados do prowlarr"
fi

if [[ -n "$sonarr_ip" ]]; then
    log "ip: $sonarr_ip, para uso no banco de dados do prowlarr"
    sqlite3 $PWD/configs/prowlarr/prowlarr.db "UPDATE DownloadClients SET Settings = replace(Settings, 'sonarr_ip', '$sonarr_ip') where Settings like '%sonarr_ip%'"
else
    war "ip nao identificado, por isso nao sera adicionado ao banco de dados do prowlarr"
    war "adicione o IP manualmente no banco de dados do prowlarr"
fi

log "dados do sonarr adicionados com sucesso!"

if sqlite3 $PWD/configs/prowlarr/prowlarr.db "PRAGMA integrity_check"; then
    log "integridade do banco de dados template do prowlarr ok!"
    if mv "$PWD/configs/prowlarr/prowlarr.db" "$prowlarr_path/$data_path/prowlarr.db"; then
        log "banco de dados template do prowlarr movido com sucesso!"
        docker restart prowlarr
    else
        err "Erro ao mover o banco de dados template do prowlarr!"
        err "Verifique se o arquivo de banco de dados existe e se tem permissão de escrita"
        exit 1
    fi
else
    war "integridade do banco de dados template do prowlarr nao ok!"
    mv $PWD/configs/prowlarr/prowlarr.db $PWD/configs/prowlarr/prowlarr.db-corrupted
    exit 1
fi

if mv $PWD/configs/prowlarr/prowlarr.db.backup $PWD/configs/prowlarr/prowlarr.db; then
    log "banco de dados template do prowlarr restaurado com sucesso!"
else
    err "Erro ao restaurar o banco de dados template do prowlarr!"
    err "Verifique se o arquivo de banco de dados backup existe e se tem permissão de escrita"
    exit 1
fi

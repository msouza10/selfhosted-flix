#!/usr/bin/env bash

print "Iniciando setup do radarr..."

for i in {3..1}; do
    print "$i"
    sleep 1
done

log "Backup do banco de dados do radarr..."

if [[ -f "$backup_dir/radarr/radarr.db" ]]; then
    war "Backup do banco de dados do radarr encontrado: $backup_dir/radarr/radarr.db"
    ask "Deseja sobrescrever o backup? [s/N]: "
    if [[ "$input" =~ ^[sS]$ ]]; then
        log "Sobrescrevendo backup do banco de dados do radarr..."
        cp "$radarr_path/$data_path/radarr.db" "$backup_dir/radarr/radarr.db"
    else
        log "Backup do banco de dados do radarr não sobrescrito!"
    fi
else
    war "Backup do banco de dados do radarr não encontrado: $backup_dir/radarr/radarr.db"
    log "Criando backup do banco de dados do radarr..."
    cp "$radarr_path/$data_path/radarr.db" "$backup_dir/radarr/radarr.db"
fi

log "Backup do banco de dados template do radarr..."

if [[ -f "$PWD/configs/radarr/radarr.db.backup" ]]; then
    war "Backup do banco de dados template do radarr encontrado: $PWD/configs/radarr/radarr.db.backup"
    ask "Deseja sobrescrever o backup? [s/N]: "
    if [[ "$input" =~ ^[sS]$ ]]; then
        log "Sobrescrevendo backup do banco de dados template do radarr..."
        cp "$PWD/configs/radarr/radarr.db" "$PWD/configs/radarr/radarr.db.backup"
    else
        log "Backup do banco de dados template do radarr não sobrescrito!"
    fi
else
    war "Backup do banco de dados template do radarr não encontrado: $PWD/configs/radarr.db.backup"
  log "Criando backup do banco de dados template do radarr..."
    cp "$PWD/configs/radarr/radarr.db" "$PWD/configs/radarr/radarr.db.backup"
fi

log "Configurando o radarr..."

log "Adicionando dados do qbittorrent ao banco de dados do radarr..."

if [[ $qbittorrent_user == "admin" ]]; then
    log "usuario default: $qbittorrent_user, para uso no banco de dados do radarr"
    sqlite3 $PWD/configs/radarr/radarr.db "UPDATE DownloadClients SET Settings = replace(Settings, 'qbittorrent_user', '$qbittorrent_user') where Settings like '%qbittorrent_user%'"
else
    log "usuario personalizado: $qbittorrent_user, para uso no banco de dados do radarr"
    sqlite3 $PWD/configs/radarr/radarr.db "UPDATE DownloadClients SET Settings = replace(Settings, 'qbittorrent_user', '$qbittorrent_user') where Settings like '%qbittorrent_user%'"
fi

if [[ -z $qbittorrent_pass_fixed ]]; then
    log "senha default: $qbittorrent_pass_fixed, para uso no banco de dados do radarr"
    sqlite3 $PWD/configs/radarr/radarr.db "UPDATE DownloadClients SET Settings = replace(Settings, 'qbittorrent_pass', '$qbittorrent_pass') where Settings like '%qbittorrent_pass%'"
else
    war "A senha nao esta fixa por isso sera necessario configurar manualmente a senha no radarr"
fi

if sqlite3 $PWD/configs/radarr/radarr.db "UPDATE DownloadClients SET Settings = replace(Settings, 'qbittorrent_ip', '$qbittorrent_ip') where Settings like '%qbittorrent_ip%'" ; then
    log "IP do qbittorrent adicionado com sucesso! $qbittorrent_ip"
else
    err "Erro ao adicionar o IP do qbittorrent!"
    war "adicione o IP manualmente no banco de dados do radarr"
fi

log "dados do qbittorrent adicionados com sucesso!"

if [[ -z "$radarr_user" ]]; then
    log "usuario: $radarr_user, para uso no banco de dados do radarr"
    sqlite3 $PWD/configs/radarr/radarr.db "UPDATE Users SET Username = '$radarr_user' WHERE Id = 1"
fi

if [[ -z "$radarr_pass" ]]; then
    log "senha default: $radarr_pass"
    sqlite3 $PWD/configs/radarr/radarr.db "UPDATE Users SET Password = '$radarr_pass' WHERE Id = 1"
else
    log "senha personalizada: $radarr_pass"
    sqlite3 $PWD/configs/radarr/radarr.db "UPDATE Users SET Password = '$radarr_pass' WHERE Id = 1"
fi

log "dados do radarr adicionados com sucesso!"

log "verificando integridade do banco de dados template do radarr antes de mover para o radarr..."

if sqlite3 $PWD/configs/radarr/radarr.db "PRAGMA integrity_check"; then
    log "integridade do banco de dados template do radarr ok!"
    if mv "$PWD/configs/radarr/radarr.db" "$radarr_path/$data_path/radarr.db"; then
        log "banco de dados template do radarr movido com sucesso!"
        docker restart radarr
        if mv "$PWD/configs/radarr/config.xml" "$radarr_path/$data_path/config.xml"; then
            log "arquivo de configuracao template do radarr movido com sucesso!"
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
    mv $PWD/configs/radarr/radarr.db $PWD/configs/radarr/radarr.db-corrupted
    exit 1
fi

if mv $PWD/configs/radarr/radarr.db.backup $PWD/configs/radarr/radarr.db; then
    log "banco de dados template do radarr restaurado com sucesso!"
else
    err "Erro ao restaurar o banco de dados template do radarr!"
    err "Verifique se o arquivo de banco de dados backup existe e se tem permissão de escrita"
    exit 1
fi
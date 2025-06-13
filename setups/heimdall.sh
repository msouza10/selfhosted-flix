#!/usr/bin/env bash

log "Iniciando setup do heimdall..."

date_backup=$(date +%Y%m%d%H%M%S)

for i in {3..1}; do
    print "$i"
    sleep 1
done

log "backup do banco de dados do heimdall template..."


if [ -f "$PWD/configs/heimdall/app.sql" ]; then
    log "Arquivo de configuracao do heimdall encontrado: $PWD/configs/heimdall/app.sql"
    if cp $PWD/configs/heimdall/app.sql $PWD/configs/heimdall/app.sql.bak; then
        log "Arquivo de configuracao do heimdall copiado com sucesso para $PWD/configs/heimdall/app.sql.bak"
    else
        err "Erro ao copiar o arquivo de configuracao do heimdall."
        exit 1
    fi
else
    war "Arquivo de configuracao do heimdall não encontrado: $PWD/configs/heimdall/app.sql"
    exit 1
fi

war "Realizando backup do banco de dados do heimdall..."

if sqlite3 $heimdall_path/$data_path/app.sqlite ".dump" > /opt/backup/heimdall/app.sqlite-$date_backup.sql; then
    log "Backup realizado com sucesso em /opt/backup/heimdall/app.sqlite-$date_backup.sql"
else
    err "Erro ao realizar o backup."
    exit 1
fi

log "Instalando novas configuracoes do heimdall..."

if grep -q "replace_domain" "$PWD/configs/heimdall/app.sql"; then
    sed -i "s|replace_domain|$DOMAIN|g" "$PWD/configs/heimdall/app.sql"
    log "Placeholder 'replace_domain' substituído por '$DOMAIN' em $PWD/configs/heimdall/app.sql."
else
    war "Placeholder 'replace_domain' não encontrado em $PWD/configs/heimdall/app.sql. Nenhuma substituição de domínio realizada."
fi

if sqlite3 $PWD/configs/heimdall/app.sqlite ".read $PWD/configs/heimdall/app.sql"; then
    log "banco de dados do heimdall atualizado com sucesso!"
    if sqlite3 $PWD/configs/heimdall/app.sqlite "PRAGMA integrity_check"; then
        log "integridade do banco de dados do heimdall ok!"
    else
        err "Erro ao verificar a integridade do banco de dados do heimdall!"
        exit 1
    fi
else
    err "Erro ao atualizar o banco de dados do heimdall!"
    err "Verifique se o arquivo de banco de dados existe e se tem permissão de escrita"
    exit 1
fi

if mv $PWD/configs/heimdall/app.sqlite $heimdall_path/$data_path/app.sqlite; then
    log "arquivo de configuracao do heimdall movido com sucesso!"
else
    err "Erro ao mover o arquivo de configuracao do heimdall!"
    err "Verifique se o arquivo de configuracao existe e se tem permissão de escrita"
    exit 1
fi

log "Reiniciando o heimdall..."

if docker restart heimdall; then
    log "Heimdall reiniciado com sucesso."
else
    err "Erro ao reiniciar o heimdall."
    exit 1
fi

if docker ps --filter "name=heimdall" --filter status="running" --format "{{.Names}}"; then
    log "Heimdall rodando com sucesso."
    mv $PWD/configs/heimdall/app.sql.bak $PWD/configs/heimdall/app.sql
    log "Arquivo de configuracao template do heimdall restaurado com sucesso para futura utilizacao."
else
    err "Heimdall não está rodando."
    exit 1
fi
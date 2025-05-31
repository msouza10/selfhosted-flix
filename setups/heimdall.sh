#!/usr/bin/env bash

print "Iniciando setup do heimdall..."

sleep 1
print "3..."
sleep 1
print "2..."
sleep 1
print "1..."
sleep 1

info "buildando imagem do heimdall..."

if grep -q ".lan/" configs/heimdall/config_heimdall.sql; then
    sed -i "s/.replace_domain/.$DOMAIN/\g" configs/heimdall/config_heimdall.sql
fi

print "verificando diretorio de backup..."

if [ -d "/opt/backup/heimdall" ]; then
    print "Diretorio de backup encontrado."
    backup="1"
else
    war "Diretorio de backup não encontrado, criando..."
    if mkdir -p /opt/backup/heimdall; then
        print "Diretorio de backup criado com sucesso."
        backup="1"
    else
        war "Erro ao criar diretorio de backup."
        if ask "Deseja continuar? [s/N]: "; then
            print "Continuando..."
            backup="0"
        else
            err "Backup cancelado e script encerrado."
            exit 1
        fi
    fi
fi

war "Realizando backup dos aplicativos suportados pelo heimdall..."

if [[ "$backup" == "1" ]]; then
    if sqlite3 $path/$struture/app.sqlite ".dump" > /opt/backup/heimdall/app.sqlite-$(date +%Y%m%d%H%M%S).sql; then
        log "Backup realizado com sucesso em /opt/backup/heimdall/app.sqlite-$(date +%Y%m%d%H%M%S).sql"
    else
        err "Erro ao realizar o backup."
        exit 1
    fi
fi

log "Instalando novas configuracoes do heimdall..."

if sqlite3 $path/$struture/app.sqlite ".dump" < configs/heimdall/app.sqlite; then
    log "Configuracoes instaladas com sucesso."
else
    war "Erro ao instalar configuracoes."
    if [[ "$backup" == "1" ]]; then
        if ask "Deseja restaurar o backup? [s/N]: "; then
            if sqlite3 $path/$struture/app.sqlite ".dump" > /opt/backup/heimdall/app.sqlite-$(date +%Y%m%d%H%M%S).sql; then
                log "Backup restaurado com sucesso."
            else
                war "Erro ao restaurar o backup."
                exit 1
            fi
        else
            err "Backup cancelado e script encerrado."
            exit 1
        fi
    else
        err "Backup cancelado e script encerrado."
        exit 1
    fi
fi

log "Reiniciando o heimdall..."

if docker restart heimdall; then
    log "Heimdall reiniciado com sucesso."
else
    err "Erro ao reiniciar o heimdall."
    exit 1
fi

log "Configuracoes do heimdall instaladas com sucesso."
# Selfhosted-Flix

Automação para criar um servidor multimídia utilizando Docker Compose. Este projeto instala e configura serviços como Jellyfin, Radarr, Sonarr, qBittorrent, Prowlarr e outros, permitindo uma "Netflix" pessoal em poucos passos.

## Pré-requisitos

- Docker e Docker Compose instalados
- Utilitários listados em [`requirements-pkgs.txt`](requirements-pkgs.txt)
- A execução dos scripts requer permissões de superusuário (root)

## Instalação rápida

1. Clone o repositório e acesse a pasta
   ```bash
   git clone <repo-url>
   cd selfhosted-flix
   ```
2. Ajuste as variáveis de ambiente copiando o arquivo de exemplo:
   ```bash
   cp based/env-based .env
   # edite .env e preencha os valores desejados
   ```
3. Execute o script principal:
   ```bash
   sudo ./initial.sh
   ```
   O script solicitará algumas informações (timezone, domínio, porta etc.) e iniciará os containers.

## Serviços incluídos

- **Jellyfin** – Servidor de streaming de mídia
- **qBittorrent** – Cliente torrent com interface web
- **Radarr** – Gerenciador de filmes
- **Sonarr** – Gerenciador de séries
- **Prowlarr** – Indexador de torrents/Usenet
- **Heimdall** – Página de dashboard
- **Traefik** – Proxy reverso
- **dnsmasq** (opcional) – DNS local para resolver os domínios

Todos os containers são definidos em [`docker-compose.yaml`](docker-compose.yaml).

## Variáveis de ambiente

Algumas das principais variáveis configuráveis no `.env`:

| Variável        | Descrição                                       |
|-----------------|-------------------------------------------------|
| `TZ`            | Timezone (ex.: `America/Sao_Paulo`)             |
| `DOMAIN`        | Domínio base para acessar os serviços           |
| `PORT`          | Porta em que o Traefik irá escutar              |
| `RADARR_PATH`   | Diretório para mídia do Radarr                  |
| `SONARR_PATH`   | Diretório para mídia do Sonarr                  |
| `TRAEFIK_USER`  | Usuário para acessar o painel do Traefik        |
| `TRAEFIK_PASS`  | Senha do painel do Traefik                      |
| `DNSMASQ`       | `0` ou `1` para habilitar o dnsmasq             |
| `DNSMASQ_DIR`   | Caminho para o arquivo `dnsmasq.conf`           |

## Uso

Após a instalação, os serviços poderão ser acessados em `http://<servico>.<DOMÍNIO>`. Por exemplo, se o domínio for `flix.local` e a porta `8080`, o Jellyfin estará em `http://jellyfin.flix.local:8080`.

As credenciais geradas pelo script são salvas em `/opt/selfhosted-flix/.credentials` para consulta futura.

## Dicas

- Verifique os logs gerados em `logs/` para acompanhar a instalação.
- Execute `./initial.sh --help` para ver todas as opções disponíveis (modo não interativo, presets de configuração, etc.).
- Teste tudo em uma máquina ou VM antes de usar em produção.

## Licença

Distribuído sob a licença [MIT](LICENSE).


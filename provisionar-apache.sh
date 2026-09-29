#!/usr/bin/env bash
# ==============================================================================
#  provisionar-apache.sh - Infraestrutura como Código: servidor web Apache
#  Autor : José Wagner Blanco Júnior  |  github.com/Josewagnerbljr-sys
#  Versão: 1.1.0
# ------------------------------------------------------------------------------
#  Fluxo do desafio: atualizar pacotes -> instalar Apache e unzip -> baixar a
#  aplicação do GitHub -> copiar para /var/www/html.
#  Extras: multi-distro (apt/dnf/yum), idempotente, backup do site atual,
#          hardening, firewall, fallback offline, healthcheck e logs.
# ==============================================================================
set -Eeuo pipefail

readonly VERSAO="1.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SITE_URL_PADRAO="https://github.com/denilsonbonatti/linux-site-dio/archive/refs/heads/main.zip"
SITE_URL="$SITE_URL_PADRAO"
DOCROOT="/var/www/html"
BACKUP_DIR="/var/backups/iac-apache"
LOG_FILE="${LOG_FILE:-/var/log/iac-apache.log}"
DRY_RUN=0; SKIP_UPGRADE=0; NO_FIREWALL=0; USE_LOCAL=0
TMP_DIR=""

# ---------- Log --------------------------------------------------------------
if [[ -t 1 ]]; then R=$'\033[0;31m'; G=$'\033[0;32m'; Y=$'\033[0;33m'; B=$'\033[0;34m'; N=$'\033[0m'
else R=""; G=""; Y=""; B=""; N=""; fi
_log() { local n="$1" c="$2"; shift 2
  printf '%s[%s]%s %s\n' "$c" "$n" "$N" "$*"
  { printf '%s [%s] %s\n' "$(date '+%F %T')" "$n" "$*" >> "$LOG_FILE"; } 2>/dev/null || true; }
info() { _log INFO "$B" "$@"; }
ok()   { _log " OK " "$G" "$@"; }
warn() { _log WARN "$Y" "$@"; }
err()  { _log ERRO "$R" "$@" >&2; }
die()  { err "$@"; exit 1; }

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then rm -rf "$TMP_DIR"; fi
  return 0
}
trap cleanup EXIT
trap 'err "Falha na linha $LINENO (comando: $BASH_COMMAND)"' ERR

run() { if (( DRY_RUN )); then info "[dry-run] $*"; else "$@"; fi; }

uso() {
  cat <<USO
Uso: sudo $0 [opções]

  -u, --site-url URL   URL de um .zip com o site (padrão: repositório do desafio)
  -l, --local          Publica o site da pasta ./site em vez de baixar
  -s, --skip-upgrade   Não executa o upgrade de pacotes (mais rápido)
  -f, --no-firewall    Não altera regras de firewall
  -n, --dry-run        Simula sem alterar o sistema
  -v, --version        Exibe a versão
  -h, --help           Ajuda
USO
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--site-url)     SITE_URL="${2:?Informe a URL}"; shift 2 ;;
    -l|--local)        USE_LOCAL=1; shift ;;
    -s|--skip-upgrade) SKIP_UPGRADE=1; shift ;;
    -f|--no-firewall)  NO_FIREWALL=1; shift ;;
    -n|--dry-run)      DRY_RUN=1; shift ;;
    -v|--version)      echo "provisionar-apache.sh $VERSAO"; exit 0 ;;
    -h|--help)         uso; exit 0 ;;
    *) err "Opção desconhecida: $1"; uso; exit 1 ;;
  esac
done

# ---------- Detecção de distribuição -----------------------------------------
PKG=""; APACHE_PKG=""; APACHE_SVC=""; CONF_DIR=""
detectar_distro() {
  if command -v apt-get >/dev/null 2>&1; then
    PKG="apt"; APACHE_PKG="apache2"; APACHE_SVC="apache2"; CONF_DIR="/etc/apache2/conf-available"
  elif command -v dnf >/dev/null 2>&1; then
    PKG="dnf"; APACHE_PKG="httpd"; APACHE_SVC="httpd"; CONF_DIR="/etc/httpd/conf.d"
  elif command -v yum >/dev/null 2>&1; then
    PKG="yum"; APACHE_PKG="httpd"; APACHE_SVC="httpd"; CONF_DIR="/etc/httpd/conf.d"
  else
    die "Gerenciador de pacotes não suportado (requer apt, dnf ou yum)."
  fi
  info "Gerenciador detectado: $PKG (pacote: $APACHE_PKG)"
}

# ---------- Etapas -----------------------------------------------------------
atualizar_sistema() {
  info "Etapa 1/6 - Atualizando pacotes"
  case "$PKG" in
    apt) run apt-get update -y
         (( SKIP_UPGRADE )) || run env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y ;;
    dnf|yum) (( SKIP_UPGRADE )) || run "$PKG" -y update ;;
  esac
  ok "Pacotes atualizados"
}

instalar_pacotes() {
  info "Etapa 2/6 - Instalando Apache e unzip"
  local pkgs=("$APACHE_PKG" unzip)
  command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || pkgs+=(curl)
  if [[ "$PKG" == "apt" ]]; then
    run env DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
  else
    run "$PKG" -y install "${pkgs[@]}"
  fi
  ok "Pacotes instalados: ${pkgs[*]}"
}

baixar() {  # baixar URL DESTINO
  if command -v curl >/dev/null 2>&1; then curl -fsSL --retry 3 -o "$2" "$1"
  else wget -q -t 3 -O "$2" "$1"; fi
}

backup_site_atual() {
  info "Etapa 3/6 - Backup do conteúdo atual"
  if [[ -d "$DOCROOT" && -n "$(ls -A "$DOCROOT" 2>/dev/null)" ]]; then
    local arq
    arq="$BACKUP_DIR/html-$(date +%Y%m%d-%H%M%S).tar.gz"
    run mkdir -p "$BACKUP_DIR"
    run tar -czf "$arq" -C "$DOCROOT" .
    ok "Backup criado: $arq"
  else
    warn "Nada a salvar em $DOCROOT"
  fi
}

publicar_site() {
  info "Etapa 4/6 - Publicando o site"
  local origem=""
  if (( DRY_RUN )); then
    local alvo="$SITE_URL"
    (( USE_LOCAL )) && alvo="$SCRIPT_DIR/site"
    info "[dry-run] publicaria o site de: $alvo"
    return
  fi
  if (( ! USE_LOCAL )); then
    TMP_DIR="$(mktemp -d)"
    info "Baixando: $SITE_URL"
    if baixar "$SITE_URL" "$TMP_DIR/site.zip" && unzip -q "$TMP_DIR/site.zip" -d "$TMP_DIR/extraido"; then
      origem="$(find "$TMP_DIR/extraido" -mindepth 1 -maxdepth 1 -type d | head -n1)"
      [[ -n "$origem" ]] || origem="$TMP_DIR/extraido"
    else
      warn "Download indisponível. Usando o site local (fallback offline)."
    fi
  fi
  [[ -n "$origem" ]] || origem="$SCRIPT_DIR/site"
  [[ -f "$origem/index.html" ]] || die "index.html não encontrado em $origem"
  cp -a "$origem"/. "$DOCROOT"/
  chown -R root:root "$DOCROOT"
  find "$DOCROOT" -type d -exec chmod 755 {} +
  find "$DOCROOT" -type f -exec chmod 644 {} +
  ok "Site publicado em $DOCROOT (origem: $origem)"
}

aplicar_hardening() {
  info "Etapa 5/6 - Hardening e serviço"
  if (( DRY_RUN )); then info "[dry-run] gravaria iac-hardening.conf em $CONF_DIR"; return; fi
  cat > "$CONF_DIR/iac-hardening.conf" <<'CONF'
# Gerado por provisionar-apache.sh - reduz exposição de informações
ServerTokens Prod
ServerSignature Off
TraceEnable Off
<IfModule mod_headers.c>
  Header always set X-Content-Type-Options "nosniff"
  Header always set X-Frame-Options "SAMEORIGIN"
  Header always set Referrer-Policy "strict-origin-when-cross-origin"
</IfModule>
CONF
  if [[ "$PKG" == "apt" ]]; then a2enmod headers >/dev/null 2>&1 || true; a2enconf -q iac-hardening; fi
  local ctl="apachectl"; command -v apachectl >/dev/null 2>&1 || ctl="apache2ctl"
  "$ctl" configtest 2>&1 | tail -1
  systemctl enable "$APACHE_SVC" >/dev/null 2>&1 || true
  systemctl restart "$APACHE_SVC"
  ok "Serviço $APACHE_SVC habilitado no boot e reiniciado"
  configurar_firewall
}

configurar_firewall() {
  (( NO_FIREWALL )) && { warn "Firewall ignorado (--no-firewall)"; return; }
  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow 80/tcp >/dev/null && ok "UFW: porta 80/tcp liberada"
  elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
    firewall-cmd --permanent --add-service=http >/dev/null && firewall-cmd --reload >/dev/null \
      && ok "firewalld: serviço http liberado"
  else
    info "Nenhum firewall ativo detectado"
  fi
}

verificar_saude() {
  info "Etapa 6/6 - Healthcheck"
  (( DRY_RUN )) && { info "[dry-run] testaria http://localhost/"; return; }
  local code=""
  for _ in 1 2 3 4 5; do
    code="$(curl -s -o /dev/null -w '%{http_code}' http://localhost/ 2>/dev/null || true)"
    [[ "$code" == "200" ]] && break; sleep 1
  done
  [[ "$code" == "200" ]] || die "Healthcheck falhou (HTTP ${code:-sem resposta})."
  ok "HTTP 200 em http://localhost/"
}

main() {
  [[ $EUID -eq 0 ]] || die "Execute como root (ex.: sudo $0)."
  local rotulo=""
  (( DRY_RUN )) && rotulo=" (SIMULAÇÃO)"
  info "Provisionamento Apache v$VERSAO$rotulo"
  detectar_distro
  atualizar_sistema
  instalar_pacotes
  backup_site_atual
  publicar_site
  aplicar_hardening
  verificar_saude
  echo
  ok "Servidor web pronto! Acesse: http://$(hostname -I 2>/dev/null | awk '{print $1}')/"
  info "Valide com: sudo ./validar-servidor.sh | Log: $LOG_FILE"
}
main

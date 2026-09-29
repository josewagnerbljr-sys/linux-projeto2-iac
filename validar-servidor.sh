#!/usr/bin/env bash
# ==============================================================================
#  validar-servidor.sh - Auditoria do servidor web provisionado
# ==============================================================================
set -uo pipefail

SVC="apache2"
command -v httpd >/dev/null 2>&1 && SVC="httpd"
FALHAS=0
TOTAL=0
HDR="$(curl -sI http://localhost/ 2>/dev/null || true)"

chk() {  # chk "descricao" comando...
  local desc="$1"
  shift
  TOTAL=$((TOTAL + 1))
  if "$@" >/dev/null 2>&1; then
    echo "[ OK ] $desc"
  else
    echo "[FAIL] $desc"
    FALHAS=$((FALHAS + 1))
  fi
}

# As funções abaixo são chamadas indiretamente por "chk" (via "$@"), então o
# ShellCheck não consegue provar que são usadas e as marca como "inacessíveis"
# (SC2317). É um falso positivo conhecido para esse padrão de despacho.
# shellcheck disable=SC2317
porta_80_em_escuta() {
  ss -ltn | grep -q ':80 '
}

# shellcheck disable=SC2317
http_responde_200() {
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' http://localhost/)"
  [[ "$code" == "200" ]]
}

# shellcheck disable=SC2317
versao_apache_oculta() {
  ! grep -Ei '^Server:.*[0-9]+\.[0-9]+' <<< "$HDR" >/dev/null
}

# shellcheck disable=SC2317
tem_header_seguranca() {
  grep -qi 'x-content-type-options' <<< "$HDR"
}

chk "serviço $SVC ativo"            systemctl is-active --quiet "$SVC"
chk "serviço habilitado no boot"    systemctl is-enabled --quiet "$SVC"
chk "porta 80 em escuta"            porta_80_em_escuta
chk "HTTP 200 em localhost"         http_responde_200
chk "index.html publicado"          test -f /var/www/html/index.html
chk "versão do Apache oculta"       versao_apache_oculta
chk "header X-Content-Type-Options" tem_header_seguranca

echo
if (( FALHAS == 0 )); then
  echo "Aprovado: $TOTAL/$TOTAL verificações."
  exit 0
else
  echo "Reprovado: $FALHAS falha(s) em $TOTAL."
  exit 1
fi

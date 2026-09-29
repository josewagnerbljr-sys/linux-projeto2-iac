#!/usr/bin/env bash
# ==============================================================================
#  validar-servidor.sh - Auditoria do servidor web provisionado
# ==============================================================================
set -uo pipefail
SVC="apache2"; command -v httpd >/dev/null 2>&1 && SVC="httpd"
FALHAS=0; TOTAL=0
chk() { local d="$1"; shift; TOTAL=$((TOTAL+1))
  if "$@" >/dev/null 2>&1; then echo "[ OK ] $d"; else echo "[FAIL] $d"; FALHAS=$((FALHAS+1)); fi; }

HDR="$(curl -sI http://localhost/ 2>/dev/null || true)"
chk "serviço $SVC ativo"            systemctl is-active --quiet "$SVC"
chk "serviço habilitado no boot"    systemctl is-enabled --quiet "$SVC"
chk "porta 80 em escuta"            bash -c "ss -ltn | grep -q ':80 '"
chk "HTTP 200 em localhost"         bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' http://localhost/)\" = 200 ]"
chk "index.html publicado"          test -f /var/www/html/index.html
chk "versão do Apache oculta"       bash -c "! grep -i '^Server:' <<<'$HDR' | grep -Eq '[0-9]+\.[0-9]+'"
chk "header X-Content-Type-Options" bash -c "grep -qi 'x-content-type-options' <<<'$HDR'"

echo; if (( FALHAS == 0 )); then echo "Aprovado: $TOTAL/$TOTAL verificações."; exit 0
else echo "Reprovado: $FALHAS falha(s) em $TOTAL."; exit 1; fi

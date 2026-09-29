#!/usr/bin/env bash
# ==============================================================================
#  remover-apache.sh - Rollback: restaura o último backup do site e/ou remove o Apache
#  Uso: sudo ./remover-apache.sh --restaurar   (restaura último backup do docroot)
#       sudo ./remover-apache.sh --purgar      (desinstala o Apache)
# ==============================================================================
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo "Execute como root."; exit 1; }

restaurar_backup() {
  local ultimo=""
  local arq
  for arq in /var/backups/iac-apache/html-*.tar.gz; do
    [[ -e "$arq" ]] || continue
    if [[ -z "$ultimo" || "$arq" -nt "$ultimo" ]]; then
      ultimo="$arq"
    fi
  done
  [[ -n "$ultimo" ]] || { echo "Nenhum backup encontrado."; exit 1; }
  tar -xzf "$ultimo" -C /var/www/html
  echo "Restaurado: $ultimo"
}

purgar_apache() {
  if command -v apt-get >/dev/null 2>&1; then
    apt-get purge -y apache2
    apt-get autoremove -y
  elif command -v dnf >/dev/null 2>&1; then
    dnf -y remove httpd
  elif command -v yum >/dev/null 2>&1; then
    yum -y remove httpd
  else
    echo "Gerenciador de pacotes não suportado."
    exit 1
  fi
  echo "Apache removido."
}

case "${1:-}" in
  --restaurar) restaurar_backup ;;
  --purgar)    purgar_apache ;;
  *) echo "Uso: $0 --restaurar | --purgar"; exit 1 ;;
esac

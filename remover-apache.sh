#!/usr/bin/env bash
# ==============================================================================
#  remover-apache.sh - Rollback: restaura o último backup do site e/ou remove o Apache
#  Uso: sudo ./remover-apache.sh --restaurar   (restaura último backup do docroot)
#       sudo ./remover-apache.sh --purgar      (desinstala o Apache)
# ==============================================================================
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo "Execute como root."; exit 1; }
case "${1:-}" in
  --restaurar)
    ultimo="$(ls -1t /var/backups/iac-apache/html-*.tar.gz 2>/dev/null | head -n1 || true)"
    [[ -n "$ultimo" ]] || { echo "Nenhum backup encontrado."; exit 1; }
    tar -xzf "$ultimo" -C /var/www/html && echo "Restaurado: $ultimo" ;;
  --purgar)
    if command -v apt-get >/dev/null 2>&1; then apt-get purge -y apache2 && apt-get autoremove -y
    else "$(command -v dnf || command -v yum)" -y remove httpd; fi
    echo "Apache removido." ;;
  *) echo "Uso: $0 --restaurar | --purgar"; exit 1 ;;
esac

# 📝 Texto de entrega — Desafio DIO: IaC — Provisionamento de Servidor Web (Apache)

**Link do repositório:** https://github.com/Josewagnerbljr-sys/linux-projeto2-iac

---

Neste desafio desenvolvi um projeto de **Infraestrutura como Código em Bash** que provisiona automaticamente um **servidor web Apache** em Linux. Com um único comando, uma máquina virtual nova é atualizada, recebe o Apache, publica a aplicação web e entra no ar já validada, e todo o código está versionado no GitHub para reutilização.

**O que foi implementado (escopo do desafio):**
- Atualização dos pacotes do servidor;
- Instalação do **Apache** e do **unzip**;
- Download da aplicação hospedada no GitHub e descompactação;
- Publicação dos arquivos em `/var/www/html`, deixando o site acessível pelo IP da máquina.

**Melhorias que agreguei ao projeto:**
1. **Multi-distro:** o script detecta `apt`, `dnf` ou `yum` e adapta pacote, serviço e diretórios (Debian, Ubuntu, RHEL, Rocky, Alma);
2. **Idempotência:** pode ser reexecutado com segurança;
3. **Backup automático** do conteúdo anterior em `/var/backups/iac-apache/` antes de publicar o novo site;
4. **Hardening do Apache:** versão do servidor oculta, `TRACE` desabilitado e headers de segurança (`X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`);
5. **Firewall inteligente:** libera a porta 80 em UFW ou firewalld apenas se estiverem ativos;
6. **Fallback offline:** se o download falhar, publica uma página local de contingência;
7. **Healthcheck:** o script só declara sucesso após receber **HTTP 200**;
8. **Modo simulação** (`--dry-run`), **logs** com data/hora e limpeza automática de arquivos temporários;
9. **Scripts auxiliares:** `validar-servidor.sh` (auditoria) e `remover-apache.sh` (rollback);
10. **CI no GitHub Actions** com ShellCheck e teste de fumaça que provisiona o Apache a cada push;
11. **README profissional** com diagrama do pipeline, tabelas de opções e boas práticas de segurança.

**Aprendizados:** pratiquei automação de provisionamento com Shell Script (`set -Eeuo pipefail`, funções, `trap`, tratamento de erros), gerenciamento de serviços com `systemctl`, hardening básico de servidor web, ajuste de firewall e integração contínua. Na prática, vi como o IaC elimina configuração manual, reduz erros e torna a infraestrutura padronizada, auditável e reproduzível.

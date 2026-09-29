# 🚀 Passo a passo para publicar no GitHub (Git Bash)

Repositório: `https://github.com/Josewagnerbljr-sys/linux-projeto2-iac`

## 1. Criar o repositório no GitHub
1. Acesse https://github.com/new
2. **Repository name:** `linux-projeto2-iac`
3. **Description:** `IaC em Bash: provisionamento automático de servidor web Apache no Linux`
4. Marque **Public**. **Não** marque README, .gitignore nem license (já existem no projeto).
5. Clique em **Create repository**.

## 2. Preparar a pasta local
Extraia o projeto e abra o **Git Bash** dentro da pasta:

```bash
cd "/d/linux-projeto2-iac"      # ajuste para o caminho onde extraiu
ls -la
```

## 3. Configurar identidade (apenas se ainda não configurada)
```bash
git config --global user.name  "José Wagner Blanco Júnior"
git config --global user.email "consultoriablanco8@gmail.com"
```

## 4. Inicializar e fazer o primeiro commit
```bash
git init
git branch -M main
git add .
git update-index --chmod=+x provisionar-apache.sh validar-servidor.sh remover-apache.sh
git commit -m "feat: IaC de provisionamento de servidor web Apache (v1.1.0)"
```
> O `update-index --chmod=+x` garante que os scripts continuem executáveis ao clonar no Linux.

## 5. Conectar ao GitHub e enviar
```bash
git remote add origin https://github.com/Josewagnerbljr-sys/linux-projeto2-iac.git
git push -u origin main
```
Se pedir credenciais, use seu usuário e um **Personal Access Token** como senha
(GitHub → Settings → Developer settings → Personal access tokens).

## 6. Deixar o repositório com cara de portfólio
1. Na página do repositório, clique na engrenagem ⚙️ ao lado de **About** e adicione:
   - **Topics:** `linux` `bash` `apache` `web-server` `iac` `infrastructure-as-code` `devops` `dio`
2. Confira se o badge do ShellCheck aparece verde na aba **Actions**.
3. Confira o job **smoke** (instala o Apache no runner e testa o HTTP).
4. (Opcional) Crie uma release: **Releases → Draft a new release → tag `v1.1.0`**.

## 7. Testar como qualquer pessoa faria (em uma VM Linux)
```bash
git clone https://github.com/Josewagnerbljr-sys/linux-projeto2-iac.git
cd linux-projeto2-iac
sudo ./provisionar-apache.sh --dry-run
sudo ./provisionar-apache.sh
sudo ./validar-servidor.sh
# Acesse no navegador: http://IP-DA-VM/
```

## 8. Atualizações futuras
```bash
git add .
git commit -m "docs: descreva a alteracao"
git push
```

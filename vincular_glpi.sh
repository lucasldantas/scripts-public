#!/bin/bash

# --- CONFIGURAÇÕES DE CONEXÃO DO BANCO DE DADOS ---
# ATUALIZE COM SUAS CREDENCIAIS REAIS!
DB_USER="glpiuser"   # Ex: glpi_user
DB_PASS="@4nWrTaz@Az"      # Senha do usuário do banco de dados
DB_NAME="glpidb"                 # Nome do seu banco de dados (confirme se é glpidb ou glpi)
CSV_FILE="/home/lucasdantas/teste.csv"     # Caminho do seu arquivo CSV
TIPO_EQUIPAMENTO="glpi_computers" # A tabela a ser atualizada é 'glpi_computers'
# --------------------------------------------------

# Verifica se o arquivo CSV existe
if [ ! -f "$CSV_FILE" ]; then
    echo "Erro: Arquivo CSV não encontrado em $CSV_FILE"
    exit 1
fi

echo "Iniciando a vinculação de $TIPO_EQUIPAMENTO no banco de dados $DB_NAME..."

# O IFS=',' garante que o script leia as colunas separadas por vírgula
cat "$CSV_FILE" | grep -v USERNAME | while IFS=',' read -r USERNAME SERIAL; do
    # Remove espaços em branco (trim)
    USERNAME=$(echo "$USERNAME" | xargs)
    SERIAL=$(echo "$SERIAL" | xargs)

    if [ -z "$USERNAME" ] || [ -z "$SERIAL" ]; then
        continue # Pula linhas vazias
    fi

    # 1. Obter o ID do Usuário (users_id)
    # A coluna de login no GLPI é 'name'.
    USER_ID=$(mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -Nse "SELECT id FROM glpi_users WHERE name = '$USERNAME' LIMIT 1;")

    if [ -z "$USER_ID" ]; then
        echo "Aviso: Usuário '$USERNAME' não encontrado. Pulando..."
        continue
    fi

    # 2. Obter o ID do Equipamento (item_id)
    # A coluna de serial na tabela glpi_computers é 'serial'.
    ITEM_ID=$(mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -Nse "SELECT id FROM $TIPO_EQUIPAMENTO WHERE serial = '$SERIAL' LIMIT 1;")

    if [ -z "$ITEM_ID" ]; then
        echo "Aviso: Serial '$SERIAL' não encontrado. Pulando..."
        continue
    fi

    # 3. Executar o UPDATE para vincular: Seta o users_id no item
    UPDATE_SQL="UPDATE $TIPO_EQUIPAMENTO SET users_id = $USER_ID WHERE id = $ITEM_ID;"
    
    mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$UPDATE_SQL"
    
    if [ $? -eq 0 ]; then
        echo "SUCESSO: Serial $SERIAL vinculado ao Usuário $USERNAME (ID $USER_ID)."
    else
        echo "ERRO: Falha ao vincular o Serial $SERIAL. Verifique as credenciais do DB."
    fi

done

echo "Processo de vinculação concluído."

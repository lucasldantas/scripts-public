#!/bin/bash

# Este script vincula usuários a equipamentos no GLPI com base em um CSV.
# Ele assume que as credenciais do MySQL estão configuradas no arquivo ~/.my.cnf

# --- CONFIGURAÇÕES ---
# O MySQL lerá as credenciais do [client] block em ~/.my.cnf
# Certifique-se de que o usuário no .my.cnf tem permissões para SELECT e UPDATE.

DB_NAME="glpidb"             # Nome do seu banco de dados GLPI (confirme se é glpidb ou glpi)
CSV_FILE="/home/lucasdantas/teste.csv" # Caminho do seu arquivo CSV
TIPO_EQUIPAMENTO="glpi_computers" # A tabela a ser atualizada (Mude para glpi_monitors, etc., se necessário)
# ---------------------

echo "Iniciando a vinculação de $TIPO_EQUIPAMENTO no banco de dados $DB_NAME..."

# Verifica se o arquivo CSV existe
if [ ! -f "$CSV_FILE" ]; then
    echo "Erro: Arquivo CSV não encontrado em $CSV_FILE"
    exit 1
fi

# Loop para ler cada linha do CSV
# O 'grep -v USERNAME' ignora uma linha de cabeçalho, se existir.
cat "$CSV_FILE" | grep -v USERNAME | while IFS=',' read -r USERNAME SERIAL; do
    
    # Limpa espaços em branco e caracteres invisíveis de nova linha (\r)
    USERNAME=$(echo "$USERNAME" | tr -d '\r' | xargs)
    SERIAL=$(echo "$SERIAL" | tr -d '\r' | xargs)

    if [ -z "$USERNAME" ] || [ -z "$SERIAL" ]; then
        continue # Pula linhas vazias
    fi

    # 1. Obter o ID do Usuário (users_id)
    # Usa o nome de login ('name') para buscar o ID.
    USER_ID=$(mysql "$DB_NAME" -Nse "SELECT id FROM glpi_users WHERE name = '$USERNAME' LIMIT 1;")

    if [ -z "$USER_ID" ]; then
        echo "Aviso: Usuário de login '$USERNAME' não encontrado. Pulando o serial $SERIAL..."
        continue
    fi

    # 2. Obter o ID do Equipamento (item_id)
    ITEM_ID=$(mysql "$DB_NAME" -Nse "SELECT id FROM $TIPO_EQUIPAMENTO WHERE serial = '$SERIAL' LIMIT 1;")

    if [ -z "$ITEM_ID" ]; then
        echo "Aviso: Serial '$SERIAL' não encontrado na tabela $TIPO_EQUIPAMENTO. Pulando..."
        continue
    fi

    # 3. Executar o UPDATE para vincular: Seta o users_id no item
    UPDATE_SQL="UPDATE $TIPO_EQUIPAMENTO SET users_id = $USER_ID WHERE id = $ITEM_ID;"
    
    # Executa a atualização no banco de dados
    mysql "$DB_NAME" -e "$UPDATE_SQL"
    
    if [ $? -eq 0 ]; then
        echo "SUCESSO: Serial $SERIAL vinculado ao Usuário $USERNAME (ID $USER_ID)."
    else
        # Se ocorrer um erro (geralmente problema de permissão ou conexão)
        echo "ERRO: Falha ao vincular o Serial $SERIAL. Verifique as permissões do DB."
    fi

done

echo "Processo de vinculação concluído."

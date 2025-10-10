#!/bin/bash

# Este script garante a existência de um computador no GLPI e o vincula a um usuário.
# Ele assume que as credenciais do MySQL estão configuradas de forma segura no arquivo ~/.my.cnf

# --- CONFIGURAÇÕES ---
DB_NAME="glpidb"             # Nome do seu banco de dados GLPI (AJUSTE SE NECESSÁRIO)
CSV_FILE="/tmp/devices_simples.csv" # Caminho do seu CSV: USERNAME,SERIAL (AJUSTE SE NECESSÁRIO)
TIPO_EQUIPAMENTO="glpi_computers"
# ---------------------

echo "Iniciando processo de CRIAÇÃO e VINCULAÇÃO em $TIPO_EQUIPAMENTO..."

if [ ! -f "$CSV_FILE" ]; then
    echo "Erro: Arquivo CSV de entrada não encontrado em $CSV_FILE"
    exit 1
fi

# Loop para ler cada linha do CSV
cat "$CSV_FILE" | grep -v USERNAME | while IFS=',' read -r USERNAME SERIAL; do
    
    # Limpa espaços em branco e caracteres invisíveis
    USERNAME=$(echo "$USERNAME" | tr -d '\r' | xargs)
    SERIAL=$(echo "$SERIAL" | tr -d '\r' | xargs)

    if [ -z "$USERNAME" ] || [ -z "$SERIAL" ]; then
        continue # Pula linhas vazias
    fi
    
    # 1. Obter o ID do Usuário (users_id)
    USER_ID=$(mysql "$DB_NAME" -Nse "SELECT id FROM glpi_users WHERE name = '$USERNAME' LIMIT 1;")

    if [ -z "$USER_ID" ]; then
        echo "Aviso: Usuário de login '$USERNAME' não encontrado no GLPI. Pulando o serial $SERIAL..."
        continue
    fi
    
    # 2. Verificar se o Serial existe e obter o ITEM_ID
    ITEM_ID=$(mysql "$DB_NAME" -Nse "SELECT id FROM $TIPO_EQUIPAMENTO WHERE serial = '$SERIAL' LIMIT 1;")
    
    
    if [ -z "$ITEM_ID" ]; then
        # --- AÇÃO: CRIAR NOVO DEVICE ---
        INVENTORY_NAME="ARCO-$SERIAL"
        
        INSERT_SQL="
            INSERT INTO $TIPO_EQUIPAMENTO 
            (name, serial, manufacturers_id, computermodels_id, date_creation, is_deleted, is_template) 
            VALUES (
                '$INVENTORY_NAME', 
                '$SERIAL', 
                0, 
                0, 
                NOW(), 
                0,
                0
            );
        "
        
        mysql "$DB_NAME" -e "$INSERT_SQL"
        
        if [ $? -eq 0 ]; then
            echo "SUCESSO: Criado o Serial $SERIAL (ARCO-...). Tentando vincular..."
            # Obtém o ID do item recém-criado para a próxima etapa
            ITEM_ID=$(mysql "$DB_NAME" -Nse "SELECT id FROM $TIPO_EQUIPAMENTO WHERE serial = '$SERIAL' LIMIT 1;")
        else
            echo "ERRO CRÍTICO: Falha ao criar o Serial $SERIAL. Pulando a vinculação."
            continue
        fi
    else
        echo "INFO: Serial $SERIAL já existe (ID $ITEM_ID). Apenas vinculando..."
    fi

    # 3. VINCULAR O DEVICE AO USUÁRIO
    UPDATE_SQL="UPDATE $TIPO_EQUIPAMENTO SET users_id = $USER_ID WHERE id = $ITEM_ID;"
    
    mysql "$DB_NAME" -e "$UPDATE_SQL"
    
    if [ $? -eq 0 ]; then
        echo "SUCESSO: Serial $SERIAL (ID $ITEM_ID) vinculado ao Usuário $USERNAME."
    else
        echo "ERRO: Falha ao vincular o Serial $SERIAL ao usuário $USERNAME."
    fi

done

echo "Processo de CRIAÇÃO e VINCULAÇÃO concluído."

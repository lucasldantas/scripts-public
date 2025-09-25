#!/usr/bin/env bash
set -euo pipefail

echo "==> Procurando apps com publisher/assinatura contendo 'TNT'..."

declare -a FOUND_APPS=()

scan_app() {
  local app="$1"
  [[ -d "$app" ]] || return 0
  # captura assinatura; não falha se codesign der erro (|| true)
  local sig
  sig=$(codesign -dv --verbose=4 "$app" 2>&1 || true)
  # procuro 'TNT' em qualquer linha da assinatura/autoridade
  if echo "$sig" | grep -qi "TNT"; then
    FOUND_APPS+=("$app")
    echo "⚠️  Encontrado: $app"
    echo "$sig" | grep -E "Authority|TeamIdentifier" || true
    echo "---------------------------------------------"
  fi
}

for app in /Applications/*.app ~/Applications/*.app; do
  scan_app "$app"
done

if [[ ${#FOUND_APPS[@]} -eq 0 ]]; then
  echo "✅ Nenhum app com publisher 'TNT' encontrado."
  exit 0
fi

echo "==> Iniciando remoção dos apps encontrados..."

for app in "${FOUND_APPS[@]}"; do
  echo "==> Processando: $app"

  # Tentar descobrir Executable e Bundle Identifier
  CFEXEC=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$app/Contents/Info.plist" 2>/dev/null || basename "$app" .app)
  BUNDLE_ID=$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null || echo "")

  echo "   - CFBundleExecutable: ${CFEXEC:-'(desconhecido)'}"
  echo "   - CFBundleIdentifier: ${BUNDLE_ID:-'(desconhecido)'}"

  echo "   - Encerrando processos relacionados (se houver)..."
  # Mata por caminho do bundle, por executable e por bundle id (sem erro se não existir)
  pkill -f -- "$app" 2>/dev/null || true
  [[ -n "${CFEXEC:-}" ]] && pkill -i -x -- "$CFEXEC" 2>/dev/null || true
  [[ -n "${BUNDLE_ID:-}" ]] && pkill -f -- "$BUNDLE_ID" 2>/dev/null || true

  # Aguarda um pouco para garantir encerramento
  sleep 1

  echo "   - Removendo app (rm -rf, sem Lixeira)..."
  rm -rf -- "$app"

  # Limpeza de rastros por Bundle Identifier em todas as contas locais
  if [[ -n "${BUNDLE_ID:-}" ]]; then
    echo "   - Limpando rastros em Libraries dos usuários..."
    for UHOME in /Users/*; do
      [[ -d "$UHOME" ]] || continue
      [[ "$UHOME" == "/Users/Shared" ]] && continue

      rm -rf -- "$UHOME/Library/Application Support/$BUNDLE_ID" \
               "$UHOME/Library/Caches/$BUNDLE_ID" \
               "$UHOME/Library/Preferences/$BUNDLE_ID.plist" \
               "$UHOME/Library/Saved Application State/${BUNDLE_ID}.savedState" 2>/dev/null || true
    done
  fi

  echo "✅ Removido: $app"
  echo
done

echo "🎯 Concluído. Recomendo reiniciar o Mac para garantir que nada permaneça carregado em memória."

#!/usr/bin/env bash
#
# Helper for inspecting SWORD/RO-Crate mapping and wiring the client.
# Default compose file: docker-compose2.yml
#
# Usage examples:
#   bash scripts/sword_tools.sh inspect \
#     --compose-file docker-compose2.yml \
#     --item-type-name 'デフォルトアイテムタイプ（シンプル）'
#
#   # Get client_id from an access token
#   bash scripts/sword_tools.sh get-client-id --token YOUR_TOKEN
#
#   # Create minimal mapping (RO-Crate name -> title)
#   bash scripts/sword_tools.sh create-map \
#     --item-type-id 30001 \
#     --title-key 'Title.タイトル' \
#     --name 'ROCrate Minimal'
#
#   # Update SWORD client to use the mapping (Direct registration)
#   bash scripts/sword_tools.sh update-client \
#     --client-id YOUR_CLIENT_ID \
#     --mapping-id 51000
#
set -euo pipefail

COMPOSE_FILE=${COMPOSE_FILE:-docker-compose2.yml}

die() { echo "[ERROR] $*" >&2; exit 1; }

require() { local v="$1"; local msg="$2"; [[ -n "${v}" ]] || die "$msg"; }

dc() {
  docker compose -f "${COMPOSE_FILE}" "$@"
}

cmd_inspect() {
  local item_type_name='デフォルトアイテムタイプ（シンプル）'
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--compose-file) COMPOSE_FILE="$2"; shift 2 ;;
      -n|--item-type-name) item_type_name="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done

  echo "[INFO] Inspecting item type: ${item_type_name}" >&2
  dc exec -T web invenio shell -c "from weko_records.models import ItemTypeName; t=ItemTypeName.query.filter_by(name='${item_type_name}').first(); print('ITEM_TYPE_ID=', t.id if t else None)"

  dc exec -T web invenio shell -c "from weko_records.models import ItemTypeName; from weko_search_ui.mapper import JsonLdMapper; t=ItemTypeName.query.filter_by(name='${item_type_name}').first(); m=JsonLdMapper(t.id, {}); print('REQUIRED=', m.required_properties()); keys=sorted(m._create_item_map(detail=True).keys()); print('FIRST_50_KEYS=', keys[:50])"
}

cmd_get_client_id() {
  local token=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--compose-file) COMPOSE_FILE="$2"; shift 2 ;;
      -t|--token) token="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  require "$token" "--token is required"
  dc exec -T web invenio shell -c "from invenio_oauth2server.models import Token; t=Token.query.filter_by(access_token='${token}').one(); print(t.client_id)"
}

cmd_create_map() {
  local item_type_id="" title_key="" map_name="ROCrate Minimal" lang_key="" lang_value=""
  local pubdate="" rtype_key_uri="" rtype_uri="" rtype_key_label="" rtype_label=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--compose-file) COMPOSE_FILE="$2"; shift 2 ;;
      --item-type-id) item_type_id="$2"; shift 2 ;;
      --title-key) title_key="$2"; shift 2 ;;
      --name) map_name="$2"; shift 2 ;;
      --lang-key) lang_key="$2"; shift 2 ;;
      --lang) lang_value="$2"; shift 2 ;;
      --pubdate) pubdate="$2"; shift 2 ;;
      --rtype-key-uri) rtype_key_uri="$2"; shift 2 ;;
      --rtype-uri) rtype_uri="$2"; shift 2 ;;
      --rtype-key-label) rtype_key_label="$2"; shift 2 ;;
      --rtype-label) rtype_label="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  require "$item_type_id" "--item-type-id is required"
  require "$title_key" "--title-key is required"

  # Build mapping dict source
  local parts=()
  parts+=("'${title_key}': 'name'")
  if [[ -n "$lang_key" && -n "$lang_value" ]]; then
    parts+=("'${lang_key}': '\$${lang_value}'")
  fi
  if [[ -n "$pubdate" ]]; then
    parts+=("'PubDate': '\$${pubdate}'")
  fi
  if [[ -n "$rtype_key_uri" && -n "$rtype_uri" ]]; then
    parts+=("'${rtype_key_uri}': '\$${rtype_uri}'")
  fi
  if [[ -n "$rtype_key_label" && -n "$rtype_label" ]]; then
    parts+=("'${rtype_key_label}': '\$${rtype_label}'")
  fi
  local IFS=','
  local mapdict="{ ${parts[*]} }"

  dc exec -T web invenio shell -c "from weko_records.api import JsonldMapping; obj=JsonldMapping.create(name='${map_name}', mapping=${mapdict}, item_type_id=${item_type_id}); print(obj.id)"
}

cmd_update_client() {
  local client_id="" mapping_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--compose-file) COMPOSE_FILE="$2"; shift 2 ;;
      --client-id) client_id="$2"; shift 2 ;;
      --mapping-id) mapping_id="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  require "$client_id" "--client-id is required"
  require "$mapping_id" "--mapping-id is required"

  dc exec -T web invenio shell -c "from weko_swordserver.api import SwordClient; from weko_swordserver.models import SwordClientModel as M; SwordClient.update(client_id='${client_id}', registration_type_id=M.RegistrationType.DIRECT, mapping_id=${mapping_id}, active=True, duplicate_check=False); print('updated')"
}

cmd_validate() {
  local scope="" mapping_id="" item_type_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--compose-file) COMPOSE_FILE="$2"; shift 2 ;;
      --mapping-id) mapping_id="$2"; scope="mapping"; shift 2 ;;
      --item-type-id) item_type_id="$2"; scope="itemtype"; shift 2 ;;
      --all) scope="all"; shift 1 ;;
      *) die "unknown option: $1" ;;
    esac
  done

  if [[ -z "$scope" ]]; then
    die "specify one of --mapping-id, --item-type-id, or --all"
  fi

  if [[ "$scope" == "mapping" ]]; then
    require "$mapping_id" "--mapping-id is required"
    local code=$'from weko_records.api import JsonldMapping\nfrom weko_search_ui.mapper import JsonLdMapper\nimport json, sys, os, traceback\nmid = int(os.environ.get("MID"))\nobj = JsonldMapping.get_mapping_by_id(mid)\nif not obj:\n    print(json.dumps({"error": "mapping not found", "mapping_id": mid}, ensure_ascii=False))\n    sys.exit(2)\ntry:\n    errs = JsonLdMapper(obj.item_type_id, obj.mapping).validate()\n    out = {"mapping_id": obj.id, "item_type_id": obj.item_type_id, "name": getattr(obj, "name", None), "valid": errs is None, "errors": errs or []}\n    print(json.dumps(out, ensure_ascii=False, indent=2))\n    sys.exit(0 if errs is None else 1)\nexcept Exception as ex:\n    traceback.print_exc()\n    print(json.dumps({"error": "exception during validation", "message": str(ex)}, ensure_ascii=False))\n    sys.exit(3)\n'
    dc exec -T -e MID="${mapping_id}" web invenio shell -c "$code"
  elif [[ "$scope" == "itemtype" ]]; then
    require "$item_type_id" "--item-type-id is required"
    local code=$'from weko_records.api import JsonldMapping\nfrom weko_search_ui.mapper import JsonLdMapper\nimport json, sys, os, traceback\nitid = int(os.environ.get("ITID"))\nobjs = JsonldMapping.get_by_itemtype_id(itid)\nresults = []\ninvalid = 0\nfor obj in objs:\n    try:\n        errs = JsonLdMapper(obj.item_type_id, obj.mapping).validate()\n        results.append({"mapping_id": obj.id, "item_type_id": obj.item_type_id, "name": getattr(obj, "name", None), "valid": errs is None, "errors": errs or []})\n        invalid += 0 if errs is None else 1\n    except Exception as ex:\n        traceback.print_exc()\n        results.append({"mapping_id": obj.id, "item_type_id": obj.item_type_id, "name": getattr(obj, "name", None), "valid": False, "errors": ["exception during validation: "+str(ex)]})\n        invalid += 1\nprint(json.dumps(results, ensure_ascii=False, indent=2))\nsys.exit(0 if invalid == 0 else 1)\n'
    dc exec -T -e ITID="${item_type_id}" web invenio shell -c "$code"
  else
    local code=$'from weko_records.api import JsonldMapping\nfrom weko_search_ui.mapper import JsonLdMapper\nimport json, sys, traceback\nobjs = JsonldMapping.get_all()\nresults = []\ninvalid = 0\nfor obj in objs:\n    try:\n        errs = JsonLdMapper(obj.item_type_id, obj.mapping).validate()\n        results.append({"mapping_id": obj.id, "item_type_id": obj.item_type_id, "name": getattr(obj, "name", None), "valid": errs is None, "errors": errs or []})\n        invalid += 0 if errs is None else 1\n    except Exception as ex:\n        traceback.print_exc()\n        results.append({"mapping_id": obj.id, "item_type_id": obj.item_type_id, "name": getattr(obj, "name", None), "valid": False, "errors": ["exception during validation: "+str(ex)]})\n        invalid += 1\nprint(json.dumps(results, ensure_ascii=False, indent=2))\nsys.exit(0 if invalid == 0 else 1)\n'
    dc exec -T web invenio shell -c "$code"
  fi
}

usage() {
  cat <<USAGE
Usage: $0 <command> [options]

Commands:
  inspect            Inspect item type (ID, required keys, first 50 keys)
  get-client-id      Print client_id from access token
  create-map         Create minimal mapping (RO-Crate name -> title)
  update-client      Update SWORD client to use a mapping (Direct)
  validate           Validate JsonLdMapping(s) via docker compose

Options:
  -f, --compose-file <file>   Compose file (default: ${COMPOSE_FILE})

Validate options:
  --mapping-id <id>           Validate a specific mapping by id
  --item-type-id <id>         Validate all mappings for an item type
  --all                       Validate all mappings

See file header for examples.
USAGE
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    inspect)        cmd_inspect "$@" ;;
    get-client-id)  cmd_get_client_id "$@" ;;
    create-map)     cmd_create_map "$@" ;;
    update-client)  cmd_update_client "$@" ;;
    validate)       cmd_validate "$@" ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"

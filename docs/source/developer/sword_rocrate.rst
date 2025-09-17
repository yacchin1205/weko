SWORD v3 + RO-Crate Quickstart and Known Issues
===============================================

Overview
--------
- Symptom: After a clean install via ``install.sh``, SWORD deposit with an RO‑Crate payload returns HTTP 400.
- Root cause: The demo JSON‑LD mapping bundled in demo SQL contains keys that are not present in the default item type (e.g. ID 30001). Validation of the mapping fails before the payload is checked.
- Impact: Even correct RO‑Crate payloads will be rejected until the mapping is made consistent with the item type.

Environment
-----------
- WEKO3 (this repo), Docker Compose
- Elasticsearch 6.8 (plugins: ingest‑attachment, kuromoji, repository‑s3)

Elasticsearch (developer host) notes
------------------------------------
If ES restarts due to seccomp/bootstrap checks, add the following to the ``elasticsearch`` service in ``docker-compose2.yml``::

  environment:
    - "discovery.type=single-node"
    - "bootstrap.system_call_filter=false"

Workflows
---------
There are two practical paths to get SWORD deposits working:

1) Prune the existing JSON‑LD mapping (recommended for demo)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Keep only the keys that exist in the item type, and assign the pruned mapping to your OAuth client.

Steps:

- Get your client_id from a personal access token::

    docker compose -f docker-compose2.yml exec -T web \
      invenio shell -c "from invenio_oauth2server.models import Token; \
      print(Token.query.filter_by(access_token='YOUR_TOKEN').one().client_id)"

- Create a pruned mapping and assign it::

    docker compose -f docker-compose2.yml exec -T web invenio shell -c \
      "from weko_swordserver.api import SwordClient; \
       from weko_swordserver.models import SwordClientModel as M; \
       from weko_records.api import JsonldMapping; \
       from weko_search_ui.mapper import JsonLdMapper; \
       c='CLIENT_ID'; sc=SwordClient.get_client_by_id(c); \
       jm=JsonldMapping.get_mapping_by_id(sc.mapping_id); \
       mapper=JsonLdMapper(jm.item_type_id, jm.mapping); \
       valid=set(mapper._create_item_map(detail=True).keys()); \
       pruned={k:v for k,v in jm.mapping.items() if k in valid}; \
       new=JsonldMapping.create(name=f'PRUNED {jm.id}', mapping=pruned, item_type_id=jm.item_type_id); \
       SwordClient.update(client_id=c, registration_type_id=M.RegistrationType.DIRECT, mapping_id=new.id, active=True, duplicate_check=False); \
       print('NEW_MAPPING_ID=', new.id)"

2) Create a minimal mapping (only required fields)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Create a new mapping that only contains the minimally required keys for the target item type (e.g. Title, Title language, PubDate, Resource Type, Publish Status, Index).

Helper script
-------------
This repository provides ``scripts/sword_tools.sh`` to streamline inspection and setup:

- Inspect item type (ID/required/keys)::

    bash scripts/sword_tools.sh inspect --compose-file docker-compose2.yml \
      --item-type-name 'デフォルトアイテムタイプ（シンプル）'

- Get client_id from token::

    bash scripts/sword_tools.sh get-client-id --token 'YOUR_TOKEN'

- Create minimal mapping (example)::

    bash scripts/sword_tools.sh create-map \
      --item-type-id 30001 \
      --title-key 'Title.タイトル' \
      --lang-key 'Title.言語' --lang ja \
      --pubdate 2025-01-01 \
      --rtype-key-uri 'Resource Type.資源タイプ識別子' --rtype-uri 'other' \
      --rtype-key-label 'Resource Type.資源タイプ' --rtype-label 'other'

- Assign mapping to client::

    bash scripts/sword_tools.sh update-client --client-id CLIENT_ID --mapping-id MAPPING_ID

RO‑Crate payload requirements
-----------------------------
For the default item type (ID 30001), ensure the RO‑Crate (``data/ro-crate-metadata.json``) includes:

- Title: ``dc:title.value`` and ``dc:title.language``
- Publish date: ``datePublished`` (ISO 8601)
- Resource type (allowed values only): ``dc:type.value`` and ``dc:type.rdf:resource``
- Publish status: ``wk:publishStatus`` ("public" or "private")
- Index: ``wk:index`` (list of index IDs the user can contribute to)

Example (root dataset)::

  {
    "@id": "./",
    "@type": "Dataset",
    "dc:title": {"value": "サンプルタイトル", "language": "ja"},
    "datePublished": "2025-01-01",
    "dc:type": {"value": "other", "rdf:resource": "other"},
    "wk:publishStatus": "public",
    "wk:index": [1623632832836],
    "hasPart": [{"@id": "example.txt"}]
  }

Sending the deposit
-------------------
Use HTTPS with ``-k`` if self‑signed certs are in use, and send as multipart/form-data::

  curl -k -X POST https://localhost/sword/service-document \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Disposition: attachment; filename=payload.zip" \
    -H "Packaging: http://purl.org/net/sword/3.0/package/SimpleZip" \
    -H "Digest: SHA-256=$DIGEST" \
    -F "file=@payload.zip;type=application/zip"

Troubleshooting
---------------
- 400 with "Mapping is invalid…": mapping validation failed (fix mapping or prune).
- 400 with "PUBLISH_STATUS is required item.": set ``wk:publishStatus`` in RO‑Crate.
- 400 with "Both of IndexID and POS_INDEX…": set ``wk:index`` (or positional index path).
- 415 ContentType/Packaging: ensure headers and multipart ``file=`` part.
- Elasticsearch restarts: see the "Elasticsearch notes" section above.


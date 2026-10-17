#!/usr/bin/env python3
"""Export / import Firestore documents or whole collections as readable JSON.

PATH decides what is copied:
  users/<uid>        a single document (even number of segments)
  users              a whole collection — every document, plus all nested
                     subcollections, recursively (odd number of segments)
  users/<uid>/logs   a subcollection works the same way

Typical use — copy your production user record into a test database:

    python3 tool/FirestoreImportExport.py export users/<uid> -o me.json
    python3 tool/FirestoreImportExport.py import users/<uid> -i me.json --db test1 \
        --set role=admin --set status=active --unset environment

Copy a whole collection from production into test1:

    python3 tool/FirestoreImportExport.py export users -o users.json
    python3 tool/FirestoreImportExport.py import users -i users.json --db test1

Commands
  export PATH [-o FILE]   Read PATH and write it as JSON (stdout if no -o).
  import PATH -i FILE     Write FILE into PATH. A document is replaced as a whole.
                          For a collection, each document in the file overwrites the
                          document with the same id; other documents are kept unless
                          --replace is given.

Options
  --db NAME           Firestore database: "(default)" (= production, the default) or e.g. "test1".
  --project ID        Firebase project (default: officeai-registry).
  --no-subcollections (collection export) Only the collection's own documents, no nested data.
  --set FIELD=VALUE   (import) Override a top-level field — on the document, or on every
                      top-level document of a collection. VALUE is parsed as JSON if it can be
                      (true, 42, null, "text"), otherwise taken as a plain string. Repeatable.
  --unset FIELD       (import) Drop a top-level field the same way. Repeatable.
  --replace           (collection import) Also delete documents (and their subcollections)
                      in the target that are not in the file, so it matches the file exactly.
  --yes               (import) Don't ask for confirmation.
  --allow-production  (import) Required to write into the "(default)" production database.

Authentication: uses the account you're logged into with `firebase login` (Firebase CLI).
The CLI's stored access token is refreshed automatically by running a harmless
`firebase projects:list` when it has expired. Owner access through the REST API
bypasses security rules, which is why imports into production need --allow-production.

Set FIRESTORE_EMULATOR_HOST=localhost:8080 to run against the local emulator instead.

JSON format
  Document file: the document's fields as a JSON object.
  Collection file:
    {"__collection__": "users",
     "documents": {
       "<docId>": {"fields": {...},
                   "subcollections": {"<name>": {"<docId>": {"fields": ..., ...}}}}}}
    A document that exists only as a parent of subcollections has "exists": false
    and no fields; import leaves it fieldless.
  Values: plain JSON for strings/numbers/booleans/null/maps/lists. Firestore types
  with no JSON equivalent are written as single-key objects so they round-trip:
    {"__timestamp__": "2026-10-17T05:30:00Z"}  {"__ref__": "users/abc"}
    {"__bytes__": "<base64>"}                   {"__geopoint__": [12.97, 77.59]}
  Integers stay integers; a whole-number double is written as e.g. 5.0.
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_PROJECT = 'officeai-registry'
PRODUCTION_DB = '(default)'
CLI_CONFIG = os.path.expanduser('~/.config/configstore/firebase-tools.json')
COLLECTION_MARKER = '__collection__'
BATCH_LIMIT = 500  # Firestore's max writes per commit.


# ---------------------------------------------------------------- auth / http

def _access_token():
    if os.environ.get('FIRESTORE_EMULATOR_HOST'):
        return 'owner'  # The emulator accepts this as an admin token.
    for attempt in range(2):
        try:
            with open(CLI_CONFIG) as f:
                tokens = json.load(f).get('tokens', {})
        except FileNotFoundError:
            tokens = {}
        token = tokens.get('access_token')
        expires_at_ms = tokens.get('expires_at', 0)
        if token and expires_at_ms / 1000 > time.time() + 60:
            return token
        if attempt == 0:
            # Any authenticated CLI command refreshes and re-saves the token.
            subprocess.run(['firebase', 'projects:list', '--json'], stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, check=False)
    sys.exit('Not logged in to the Firebase CLI (or token refresh failed). Run: firebase login')


class Db:
    """REST access to one Firestore database."""

    def __init__(self, project, db):
        self.project = project
        self.db = db
        emulator = os.environ.get('FIRESTORE_EMULATOR_HOST')
        root = 'http://%s' % emulator if emulator else 'https://firestore.googleapis.com'
        self.api = root + '/v1/'
        # Resource name prefix, e.g. projects/p/databases/(default)/documents
        self.docs_name = 'projects/%s/databases/%s/documents' % (project, db)

    def name(self, path):
        return '%s/%s' % (self.docs_name, path.strip('/'))

    def _url(self, resource_name, suffix=''):
        return self.api + urllib.parse.quote(resource_name, safe='/()') + suffix

    def request(self, method, url, body=None):
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, method=method, data=data, headers={
            'Authorization': 'Bearer ' + _access_token(),
            'Content-Type': 'application/json',
        })
        try:
            with urllib.request.urlopen(req) as resp:
                return json.load(resp)
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            detail = e.read().decode(errors='replace')
            sys.exit('Firestore %s %s failed (%d): %s' % (method, url, e.code, detail))

    def get_doc(self, path):
        return self.request('GET', self._url(self.name(path)))

    def list_docs(self, collection_path):
        """All documents in a collection, including fieldless parents of subcollections."""
        docs, token = [], None
        while True:
            query = {'pageSize': 300, 'showMissing': 'true'}
            if token:
                query['pageToken'] = token
            resp = self.request('GET', self._url(self.name(collection_path), '?' + urllib.parse.urlencode(query)))
            if not resp:
                return docs
            docs.extend(resp.get('documents', []))
            token = resp.get('nextPageToken')
            if not token:
                return docs

    def list_subcollections(self, doc_path):
        ids, token = [], None
        while True:
            body = {'pageSize': 300}
            if token:
                body['pageToken'] = token
            resp = self.request('POST', self._url(self.name(doc_path), ':listCollectionIds'), body) or {}
            ids.extend(resp.get('collectionIds', []))
            token = resp.get('nextPageToken')
            if not token:
                return sorted(ids)

    def commit(self, writes):
        for start in range(0, len(writes), BATCH_LIMIT):
            self.request('POST', self._url(self.docs_name.rsplit('/documents', 1)[0], '/documents:commit'),
                         {'writes': writes[start:start + BATCH_LIMIT]})


def _segments(path):
    parts = [p for p in path.strip('/').split('/') if p]
    if not parts:
        sys.exit('Path must not be empty.')
    return parts


def _is_collection(path):
    return len(_segments(path)) % 2 == 1


# ------------------------------------------------------ value <-> plain JSON

def from_firestore(value):
    """Firestore REST typed value -> plain JSON value."""
    if 'nullValue' in value:
        return None
    if 'booleanValue' in value:
        return value['booleanValue']
    if 'integerValue' in value:
        return int(value['integerValue'])
    if 'doubleValue' in value:
        return float(value['doubleValue'])
    if 'stringValue' in value:
        return value['stringValue']
    if 'timestampValue' in value:
        return {'__timestamp__': value['timestampValue']}
    if 'bytesValue' in value:
        return {'__bytes__': value['bytesValue']}
    if 'referenceValue' in value:
        # Store just the path inside the database so it can be re-targeted on import.
        return {'__ref__': value['referenceValue'].split('/documents/', 1)[-1]}
    if 'geoPointValue' in value:
        g = value['geoPointValue']
        return {'__geopoint__': [g.get('latitude', 0.0), g.get('longitude', 0.0)]}
    if 'arrayValue' in value:
        return [from_firestore(v) for v in value['arrayValue'].get('values', [])]
    if 'mapValue' in value:
        return {k: from_firestore(v) for k, v in value['mapValue'].get('fields', {}).items()}
    raise ValueError('Unsupported Firestore value: %r' % value)


def to_firestore(value, db):
    """Plain JSON value -> Firestore REST typed value."""
    if value is None:
        return {'nullValue': None}
    if isinstance(value, bool):
        return {'booleanValue': value}
    if isinstance(value, int):
        return {'integerValue': str(value)}
    if isinstance(value, float):
        return {'doubleValue': value}
    if isinstance(value, str):
        return {'stringValue': value}
    if isinstance(value, list):
        return {'arrayValue': {'values': [to_firestore(v, db) for v in value]}}
    if isinstance(value, dict):
        if len(value) == 1:
            (key, inner), = value.items()
            if key == '__timestamp__':
                return {'timestampValue': inner}
            if key == '__bytes__':
                return {'bytesValue': inner}
            if key == '__ref__':
                return {'referenceValue': db.name(inner)}
            if key == '__geopoint__':
                return {'geoPointValue': {'latitude': inner[0], 'longitude': inner[1]}}
        return {'mapValue': {'fields': {k: to_firestore(v, db) for k, v in value.items()}}}
    raise ValueError('Unsupported JSON value: %r' % (value,))


def _fields_to_json(doc):
    return {k: from_firestore(v) for k, v in doc.get('fields', {}).items()}


def _fields_to_firestore(data, db):
    return {k: to_firestore(v, db) for k, v in data.items()}


def _parse_set(item):
    if '=' not in item:
        sys.exit('--set expects FIELD=VALUE, got "%s"' % item)
    field, raw = item.split('=', 1)
    try:
        return field, json.loads(raw)
    except ValueError:
        return field, raw


def _apply_overrides(data, args):
    for field in args.unset or []:
        data.pop(field, None)
    for item in args.set or []:
        field, value = _parse_set(item)
        data[field] = value
    return data


# ------------------------------------------------------- collection export

def export_collection(db, collection_path, include_subcollections, counter):
    """Returns {docId: {"fields":..., ["exists": False], ["subcollections": {...}]}}."""
    out = {}
    for doc in db.list_docs(collection_path):
        doc_id = doc['name'].rsplit('/', 1)[-1]
        doc_path = '%s/%s' % (collection_path.strip('/'), doc_id)
        # showMissing returns fieldless parents without a createTime.
        exists = 'createTime' in doc
        entry = {'fields': _fields_to_json(doc)}
        if not exists:
            entry['exists'] = False
        else:
            counter[0] += 1
        if include_subcollections:
            subs = {}
            for sub_id in db.list_subcollections(doc_path):
                subs[sub_id] = export_collection(db, '%s/%s' % (doc_path, sub_id), True, counter)
            if subs:
                entry['subcollections'] = subs
        if exists or entry.get('subcollections'):
            out[doc_id] = entry
    return out


# ------------------------------------------------------- collection import

def _existing_tree_names(db, collection_path):
    """Resource names of every existing document under a collection, recursively."""
    names = []
    for doc in db.list_docs(collection_path):
        doc_id = doc['name'].rsplit('/', 1)[-1]
        doc_path = '%s/%s' % (collection_path, doc_id)
        if 'createTime' in doc:
            names.append(doc['name'])
        for sub_id in db.list_subcollections(doc_path):
            names.extend(_existing_tree_names(db, '%s/%s' % (doc_path, sub_id)))
    return names


def plan_collection_import(db, collection_path, documents, replace, overrides, plan):
    """Fills plan["writes"], plan["new"], plan["overwrite"], plan["delete"]."""
    collection_path = collection_path.strip('/')
    existing = {}
    for doc in db.list_docs(collection_path):
        existing[doc['name'].rsplit('/', 1)[-1]] = 'createTime' in doc

    for doc_id, entry in documents.items():
        doc_path = '%s/%s' % (collection_path, doc_id)
        if entry.get('exists', True):
            data = dict(entry.get('fields', {}))
            if overrides is not None:
                _apply_overrides(data, overrides)
            plan['writes'].append({'update': {'name': db.name(doc_path), 'fields': _fields_to_firestore(data, db)}})
            plan['overwrite' if existing.get(doc_id) else 'new'] += 1
        elif replace and existing.get(doc_id):
            # The file says this doc has no fields of its own; make the target match.
            plan['writes'].append({'delete': db.name(doc_path)})
            plan['delete'] += 1

        file_subs = entry.get('subcollections', {})
        if replace and doc_id in existing:
            for sub_id in db.list_subcollections(doc_path):
                if sub_id not in file_subs:
                    for name in _existing_tree_names(db, '%s/%s' % (doc_path, sub_id)):
                        plan['writes'].append({'delete': name})
                        plan['delete'] += 1
        for sub_id, sub_docs in file_subs.items():
            # --set/--unset apply to top-level documents only.
            plan_collection_import(db, '%s/%s' % (doc_path, sub_id), sub_docs, replace, None, plan)

    if replace:
        for doc_id in existing:
            if doc_id not in documents:
                doc_path = '%s/%s' % (collection_path, doc_id)
                names = [db.name(doc_path)] if existing[doc_id] else []
                for sub_id in db.list_subcollections(doc_path):
                    names.extend(_existing_tree_names(db, '%s/%s' % (doc_path, sub_id)))
                for name in names:
                    plan['writes'].append({'delete': name})
                    plan['delete'] += 1


# ------------------------------------------------------------------ commands

def _write_output(text, output):
    if output:
        with open(output, 'w', encoding='utf-8') as f:
            f.write(text)
    else:
        sys.stdout.write(text)


def cmd_export(args):
    db = Db(args.project, args.db)
    path = '/'.join(_segments(args.path))
    if _is_collection(path):
        counter = [0]
        documents = export_collection(db, path, not args.no_subcollections, counter)
        payload = {COLLECTION_MARKER: path, 'documents': documents}
        _write_output(json.dumps(payload, indent=2, ensure_ascii=False, sort_keys=True) + '\n', args.output)
        print('Exported collection %s from %s: %d top-level, %d documents in total%s.' % (
            path, args.db, len(documents), counter[0],
            '' if args.no_subcollections else ' (incl. subcollections)'), file=sys.stderr)
        return

    doc = db.get_doc(path)
    if doc is None:
        sys.exit('Document %s not found in database %s.' % (path, args.db))
    data = _fields_to_json(doc)
    _write_output(json.dumps(data, indent=2, ensure_ascii=False, sort_keys=True) + '\n', args.output)
    print('Exported %s from %s (%d fields)%s.' % (path, args.db, len(data),
                                                 ' -> ' + args.output if args.output else ''), file=sys.stderr)


def _confirm(message, args):
    if args.yes:
        return
    answer = input(message + ' Continue? [y/N] ')
    if answer.strip().lower() not in ('y', 'yes'):
        sys.exit('Cancelled.')


def cmd_import(args):
    if args.db == PRODUCTION_DB and not args.allow_production:
        sys.exit('Refusing to write to the production database "(default)" without --allow-production.')
    db = Db(args.project, args.db)
    path = '/'.join(_segments(args.path))
    with open(args.input, encoding='utf-8') as f:
        payload = json.load(f)
    if not isinstance(payload, dict):
        sys.exit('%s must contain a JSON object.' % args.input)
    is_collection_file = COLLECTION_MARKER in payload and isinstance(payload.get('documents'), dict)

    if _is_collection(path):
        if not is_collection_file:
            sys.exit('%s is a collection path but %s is a single-document export.' % (path, args.input))
        plan = {'writes': [], 'new': 0, 'overwrite': 0, 'delete': 0}
        plan_collection_import(db, path, payload['documents'], args.replace, args, plan)
        if not plan['writes']:
            print('Nothing to import.', file=sys.stderr)
            return
        summary = 'Import into %s / %s: %d new, %d overwritten%s.' % (
            args.db, path, plan['new'], plan['overwrite'],
            ', %d deleted' % plan['delete'] if args.replace else '')
        _confirm(summary, args)
        db.commit(plan['writes'])
        print('Done. ' + summary, file=sys.stderr)
        return

    if args.replace:
        sys.exit('--replace only applies to collection imports.')
    if is_collection_file:
        sys.exit('%s is a document path but %s is a collection export.' % (path, args.input))
    data = _apply_overrides(payload, args)
    if db.get_doc(path) is not None:
        _confirm('%s already exists in %s and will be replaced.' % (path, args.db), args)
    db.commit([{'update': {'name': db.name(path), 'fields': _fields_to_firestore(data, db)}}])
    print('Imported %s into %s (%d fields).' % (path, args.db, len(data)), file=sys.stderr)


def main(argv=None):
    parser = argparse.ArgumentParser(
        description='Export/import a Firestore document or collection as JSON.',
        epilog='See the docstring at the top of this file for the JSON format and examples.')
    sub = parser.add_subparsers(dest='command', required=True)

    def common(p):
        p.add_argument('path', help='Document (users/abc123) or collection (users) path')
        p.add_argument('--db', default=PRODUCTION_DB, help='Database: "(default)" (production) or e.g. test1')
        p.add_argument('--project', default=DEFAULT_PROJECT)

    p_export = sub.add_parser('export', help='Write a document or collection to JSON')
    common(p_export)
    p_export.add_argument('-o', '--output', help='Output file (default: stdout)')
    p_export.add_argument('--no-subcollections', action='store_true',
                          help='Collection export: skip nested subcollections')
    p_export.set_defaults(func=cmd_export)

    p_import = sub.add_parser('import', help='Write JSON into a document or collection')
    common(p_import)
    p_import.add_argument('-i', '--input', required=True, help='JSON file to import')
    p_import.add_argument('--set', action='append', metavar='FIELD=VALUE')
    p_import.add_argument('--unset', action='append', metavar='FIELD')
    p_import.add_argument('--replace', action='store_true',
                          help='Collection import: delete target documents not in the file')
    p_import.add_argument('--yes', action='store_true', help="Don't ask for confirmation")
    p_import.add_argument('--allow-production', action='store_true',
                          help='Permit writing to the "(default)" production database')
    p_import.set_defaults(func=cmd_import)

    args = parser.parse_args(argv)
    args.func(args)


if __name__ == '__main__':
    main()

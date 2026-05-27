# WebDAV Cloud Storage Layout

**Feature**: 003-data-storage-sync

---

## Directory Hierarchy

```
MyAssistant/{username}/
├── profile/
│   └── user_profile.json
│
├── todos/
│   ├── todos_index.json
│   ├── 2026/
│   │   ├── 202605/
│   │   │   ├── 20260520/
│   │   │   │   ├── abc123.json
│   │   │   │   └── def456.json
│   │   │   └── 20260521/
│   │   │       └── ghi789.json
│   │   └── 202606/
│   │       └── ...
│   └── ...
│
├── bills/
│   ├── bills_index.json
│   └── 2026/
│       └── ...
│
├── notes/
│   ├── notes_index.json
│   └── 2026/
│       └── ...
│
├── chats/
│   ├── chats_index.json
│   └── 2026/
│       └── ...
│
└── sync_meta/
    ├── device_{deviceId}.json
    └── conflict_backups/
        └── ...
```

## File Naming Convention

| Component | Format | Example |
|-----------|--------|---------|
| Year | `YYYY` | `2026` |
| Year-Month | `YYYYMM` | `202605` |
| Year-Month-Day | `YYYYMMDD` | `20260520` |
| Data file | `{uuid}.json` | `abc123-def456.json` |
| Index file | `{type}_index.json` | `todos_index.json` |
| Conflict backup | `{id}_conflict_{timestamp}.json` | `abc123_conflict_20260520T093000Z.json` |
| Device meta | `device_{deviceId}.json` | `device_dev-uuid-001.json` |

## Operations

### Create directory tree for new data file

```
PUT /MyAssistant/{user}/todos/2026/202605/20260520/abc123.json
→ WebDAV auto-creates intermediate directories (MKCOL if needed)
```

### Pull index

```
GET /MyAssistant/{user}/todos/todos_index.json
→ 200: return JSON body
→ 404: index doesn't exist (first sync)
```

### Update index

```
PUT /MyAssistant/{user}/todos/todos_index.json
→ 200/201: index updated
```

### Pull changed files

```
GET /MyAssistant/{user}/todos/2026/202605/20260520/abc123.json
→ 200: return file content
→ 404: file deleted remotely
```

## Data File Schema

```json
{
  "id": "string (UUID)",
  "type": "todo|bill|note|chat|profile",
  "version": "integer",
  "updatedAt": "ISO 8601 UTC",
  "deviceId": "string (UUID)",
  "data": { /* type-specific JSON */ },
  "deleted": "boolean"
}
```

## Index File Schema

```json
{
  "type": "todo|bill|note|chat|profile",
  "updatedAt": "ISO 8601 UTC",
  "entries": [
    {
      "id": "string (UUID)",
      "version": "integer",
      "updatedAt": "ISO 8601 UTC"
    }
  ]
}
```

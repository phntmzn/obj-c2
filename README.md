# obj-c2

Objective-C command-and-control server prototype for macOS.

The current implementation exposes:

- A plain TCP listener
- A small interactive operator console
- Text command handling (`ping`, `status`, `echo`, `encrypt`, `decrypt`)
- Basic HTTP request parsing on the same port (`/health`, `/status`, `/echo`)
- File-backed client persistence and local logging

## Project Layout

- `obj-c2/main.m`: entry point
- `obj-c2/Config/server.plist`: runtime configuration
- `obj-c2/C2Server/Core`: server lifecycle, client handling, command processing
- `obj-c2/C2Server/Network`: TCP listener, HTTP parsing, SSL config validation
- `obj-c2/C2Server/Crypto`: symmetric string encryption helper
- `obj-c2/C2Server/Database`: file-backed client record storage
- `obj-c2/C2Server/Utils`: logging

## Requirements

- macOS
- Xcode or Xcode Command Line Tools
- `clang`/Foundation framework via Apple toolchain

## Build

CLI build from the repo root:

```bash
make -C obj-c2
```

This produces:

```text
obj-c2/c2_server
```

Xcode build from the repo root:

```bash
xcodebuild -scheme obj-c2 -project obj-c2.xcodeproj build
```

## Run

From the repo root:

```bash
./obj-c2/c2_server
```

The server looks for `Config/server.plist` first and will also use the bundled copy when launched from the app target.

## Configuration

Main config file:

```text
obj-c2/Config/server.plist
```

Current keys:

- `port`: listener port, default `4444`
- `ssl_enabled`: `0` or `1`
- `cert_path`: certificate path, resolved relative to the config file when not absolute
- `key_path`: key path, resolved relative to the config file when not absolute
- `database_path`: storage path for client records, resolved relative to the config file when not absolute
- `max_connections`: present in config, currently not enforced

Example current config:

```plist
{
  cert_path = "./certs/server.crt";
  database_path = "./data/c2_server.db";
  key_path = "./certs/server.key";
  max_connections = 100;
  port = 4444;
  ssl_enabled = 0;
}
```

## Operator Console

After startup the process enters an interactive console with:

- `list`
- `interact <id>`
- `help`
- `exit`

## Network Commands

Send raw text over TCP:

- `ping`
- `status`
- `echo <text>`
- `encrypt <passphrase> <text>`
- `decrypt <passphrase> <base64>`
- any other input returns `ack <client>: <command>`

Quick test with `nc`:

```bash
printf 'ping\n' | nc 127.0.0.1 4444
```

## HTTP Endpoints

The listener also recognizes HTTP/1.0 and HTTP/1.1 request lines on the same socket.

- `GET /health` -> `200 ok`
- `GET /status` -> JSON server status
- `POST /echo` -> echoes the request body

Examples:

```bash
curl http://127.0.0.1:4444/health
curl http://127.0.0.1:4444/status
curl -X POST http://127.0.0.1:4444/echo -d 'hello'
```

## Persistence and Logs

- Logs are written to `logs/c2_server.log`
- Client records are appended to the file at `database_path`

Important: despite the default `.db` filename, the current storage layer writes an Apple property-list array, not SQLite.

## Current Limitations

- `ssl_enabled=1` validates certificate/key files, but the listener still uses plain TCP. TLS transport is not implemented yet.
- `max_connections` is not enforced.
- Client persistence is minimal and append-only.
- `ConfigParser` exists in the tree but is not used by the current startup path.

## Development Notes

- The Xcode target uses synced folders, so generated runtime artifacts should stay out of the source tree where possible.
- The CLI build path is defined in `obj-c2/Makefile`.

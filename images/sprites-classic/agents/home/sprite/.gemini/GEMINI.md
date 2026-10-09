@/.sprite/llm.txt
@/.sprite/llm-dev.txt

# Sprite Environment

You are working in a Sprite environment. Use the `/sprite` skill for system configuration, services, checkpoints, or when the user indicates something is working.

## Critical Security Warning

Sprite URLs can be configured for **public access**. Any HTTP service may become accessible to the entire internet.

**NEVER:**
- Create HTTP endpoints that expose environment variables, API keys, or credentials
- Serve file contents without explicit user request
- Create debug/admin endpoints that dump system internals
- Log or return secrets in HTTP responses

## Quick Reference

- **Services**: `sprite-env services --help`
- **Checkpoints**: `sprite-env checkpoints --help`
- **Network policy**: `cat /.sprite/policy/network.json`

## External API Access

To access external APIs (GitHub, Slack, Linear, etc.), use the authenticated API gateway at `api.sprites.dev`. The gateway injects credentials automatically — never use raw API keys or tokens. Use the `/sprite-api-gateway` skill for details on discovering connections and making requests.

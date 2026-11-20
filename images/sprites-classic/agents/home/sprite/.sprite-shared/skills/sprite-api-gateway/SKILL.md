---
name: sprite-api-gateway
description: Use this skill whenever a task needs an external API or third-party service (GitHub, Slack, Linear, an LLM provider, a SaaS API, anything that would otherwise need a token), and before asking the user for an API key, token, or credential. The Sprites API gateway at api.sprites.dev holds the organization's credentials and attaches them for you, so a sprite never needs a raw key.
---

Connectors are third-party API credentials the organization holds. You call
them through the Sprites API gateway, which identifies this sprite on its own
and attaches the credential, so the sprite never sees a key. This is the only
supported way to reach an external API from a Sprite.

## Step 1: Find the connector

Run this before asking the user for an API key, token, or credential, when a
task names a third-party service, when an external API answers 401 or 403,
or when egress denies a host:

```bash
sprite-env connectors find github
sprite-env connectors find "web search"
```

Pass a name, a keyword, a host, or a full URL such as
`https://api.github.com/repos/acme/web/issues`. Host and URL searches use
`upstream_host` and prefer an exact host over a parent or child host. Name
searches use `provider`, `display_name`, `keywords`, `categories`, and
`description`. The JSON result includes the `query`, the `match` (one of
the four outcomes below), a `connector` or `null`, up to five other
matches in `candidates`, and a `next_step`.

## Step 2: Act on the match

- **`connected`** means this sprite may call the connector. Use its
  `gateway_base_url` as the base URL and append the provider's API path.
  Use `usage_snippet` as a starting point when provided. Do not add an
  Authorization header, API key, or token. The gateway attaches the
  credential, and a header you add can override it.
- **`restricted`** means the connector's access policy denies this sprite.
  Tell the user why, quoting `access_reason`, give them the
  connector's `manage_url`, and wait. Once they allow this sprite, run
  `find` again to get the callable `gateway_base_url`. No restart is
  needed. Never try to work around the policy.
- **`available`** means the dashboard offers setup for this provider.
  Check `candidates` for a relevant `connected` or `restricted` match and
  follow its steps if one fits. If `connectors list` omits `restricted`,
  ask the user to check the dashboard for an existing connector before
  creating one. If setup is needed, relay the setup link or dashboard
  instructions from `next_step`. Ask the user
  to allow this sprite in the connector's access policy, then run `find`
  again after they confirm access. The credential stays off the sprite.
- **`none`** means nothing matches. Follow `next_step`. If it suggests a
  Custom API connector, give the user the API's base URL and the name of the
  auth header so they can create it in the dashboard. Do not ask them to
  paste the credential into the sprite instead.

`sprite-env connectors get <connector_id>` shows one connector by id, with the
same `match` and `next_step`.

## The full list

`sprite-env connectors list` prints the gateway's response unchanged. If the
CLI is unavailable, the same data comes from:

```bash
curl -s https://api.sprites.dev/v1/gateway/list
```

It has three buckets:

- `connections`: connectors this sprite may call. Each has `id`, `provider`,
  `display_name`, `description`, `gateway_base_url`, `usage_snippet`,
  `scopes`, `request_scopes_url`, `manage_url`, `upstream_host`,
  `categories`, and `keywords`.
- `restricted`: connectors whose access policy denies this sprite. Each has
  `id`, `provider`, `display_name`, `access_reason` (why this sprite is
  denied), `manage_url` (where a person changes that), `upstream_host`,
  `categories`, and `keywords`. Older platforms omit this bucket and
  leave denied connections out of the response.
- `available`: providers eligible for setup, including providers with
  existing connections. Each has `provider`, `display_name`,
  `description`, `setup_url` (the dashboard page with the provider selected),
  `auth_kind`, `setup`, `website_url`, `upstream_host`, `categories`, and
  `keywords`. Older platforms may omit the setup link and discovery metadata.

Match on `provider`, `display_name`, `upstream_host`, `keywords`, or
`description`; `find` does this for you.

## Missing scopes

If an OAuth provider reports missing scopes, check the connection's
`scopes` and explain which additional scopes the operation needs. Append
the URL-encoded, comma-separated list of existing and required scopes to
`request_scopes_url`, which ends in `?scopes=`. Give the user the completed
link and retry after they grant the scopes.

## Reading gateway errors

Read the error body alongside the HTTP status.

- If the gateway says it could not verify the sprite's identity, make the
  request from this sprite directly, without a tunnel or another host.
- If the gateway gives a reason this sprite is denied by the connector's
  access policy, follow the `restricted` steps and wait. Do not retry with
  a different identity, header, or route.
- If the gateway reports a rejected saved credential, ask the user to
  reconnect it from the dashboard. If it reports an unsupported request
  path or method, check the connector's supported operations.
- If the response contains an upstream provider error, follow the provider's
  error details. For missing OAuth scopes, use the steps above.

## Rules

- **Never add the provider's authorization header**, an API key, or a token to
  a gateway request. The gateway handles authentication.
- **Never ask the user to paste a token, key, or credential** into the sprite,
  a file, or a service's environment. Send them to `setup_url` or
  `manage_url` instead; the credential stays in the dashboard.
- **Never weaken or work around an access policy.** Only a person can grant
  the sprite access in the dashboard.
- **Always run `find` or read the list first**; never guess a gateway URL.
  The `gateway_base_url` differs per connection.
- **This is the only supported way to call external APIs** from a Sprite.

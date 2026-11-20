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
sprite-env connectors find <service or host>
```

Pass a name, a keyword, a host, or a full URL, for example `github`,
`web search`, or `https://api.github.com/repos/acme/web/issues`. A host or
URL is matched against each connector's `upstream_host` (an exact host beats
a parent or child host); a name is matched against `provider`,
`display_name`, `keywords`, `categories`, and `description`. It prints one
JSON object:

```json
{"query": "...", "match": "connected|restricted|available|none",
 "connector": {...} or null, "candidates": [...up to 5 runners-up...],
 "next_step": "one sentence to act on or relay"}
```

## Step 2: Act on the match

- **`connected`**: this sprite may call it. Use the connector's
  `gateway_base_url` as the base URL and append the provider's API path, for
  example `curl -s <gateway_base_url>/user/repos`. The `usage_snippet` is a
  ready example. Do not add an Authorization header, API key, or token: the
  gateway attaches the credential, and a header you add can override it.
- **`restricted`**: the connection exists but this sprite's access policy
  denies it. Tell the user why, quoting `access_reason`, give them the
  connector's `manage_url`, and wait. Once they allow this sprite, call it
  without restarting anything. Never try to work around the policy.
- **`available`**: the provider is supported but nobody in the organization
  has connected it. Relay the setup link or dashboard instructions in
  `next_step` (the `setup_url` pre-selects the provider and this sprite in
  the dashboard; without one, `next_step` gives the dashboard path), explain
  that the credential stays off the sprite, and run `find` again once the
  user says setup is done.
- **`none`**: nothing matches. Follow `next_step`. If it suggests a Custom
  API connector, give the user the API's base URL and the name of the auth
  header so they can create it in the dashboard. Do not ask them to paste
  the credential into the sprite instead.

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
  `categories`, and `keywords`. Older platforms omit this bucket; treat a
  missing key as empty.
- `available`: providers nobody has connected. Each has `provider`,
  `display_name`, `description`, `setup_url` (the dashboard page to create
  the connection, pre-selecting the provider and this sprite), `auth_kind`,
  `setup`, `website_url`, `upstream_host`, `categories`, and `keywords`.

Match on `provider`, `display_name`, `upstream_host`, `keywords`, or
`description`; `find` does this for you.

## Missing scopes

If a connected provider rejects an operation for lack of permission, check
the connection's `scopes`, name the scopes the operation needs and why, and
send the user to its `request_scopes_url` to grant them. Then retry.

## Reading gateway errors

- **403** from the gateway means policy: this sprite is not allowed to use
  that connection. Treat it like `restricted`: report it, give the user the
  `manage_url`, and wait. Do not retry with a different identity, header, or
  route.
- **401** from the gateway means the caller is not recognized as a sprite.
  The request did not come from this sprite's own network identity, for
  example because it went through a tunnel or another host. Make the call
  from this sprite directly.
- A 4xx or 5xx with the upstream provider's own error body came from the
  provider; read it as you would any API error.

## Rules

- **Never add the provider's authorization header**, an API key, or a token to
  a gateway request. The gateway handles authentication.
- **Never ask the user to paste a token, key, or credential** into the sprite,
  a file, or a service's environment. Send them to `setup_url` or
  `manage_url` instead; the credential stays in the dashboard.
- **Never weaken or work around an access policy.** A `restricted` match or a
  403 is a decision a person makes in the dashboard.
- **Always run `find` or read the list first**; never guess a gateway URL.
  The `gateway_base_url` differs per connection.
- **This is the only supported way to call external APIs** from a Sprite.

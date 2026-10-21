# syntax=docker/dockerfile:1

FROM sprites-classic-devtools AS base

FROM base AS ccache
ARG UBUNTU_SNAPSHOT

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    << 'EOF'
set -e

# switch the secretly snapshotted lists back to their snapshot names so APT
# fetches from the right server
cd /var/lib/apt/lists
for list in archive.ubuntu.com_ubuntu_dists_* security.ubuntu.com_ubuntu_dists_*
do
    cp "$list" "snapshot.ubuntu.com_ubuntu_${UBUNTU_SNAPSHOT}_dists_${list#*_dists_}"
done
cd /

apt-get install -y --no-install-recommends --snapshot "$UBUNTU_SNAPSHOT" ccache
EOF

ENV PATH="/usr/lib/ccache:$PATH" \
    CCACHE_DIR=/var/cache/ccache \
    CCACHE_MAXSIZE=2G

# -- nvm + Node.js

FROM base AS node
ARG TARGETARCH

RUN --mount=type=cache,target=/root/.npm \
    --mount=type=cache,target=/.sprite/languages/node/nvm/.cache \
    --mount=type=cache,target=/tmp/node-compile-cache \
    << 'EOF'
set -e

# Baseline pinned LTS as of 2026-10-21: 24.22.1
NODE_VERSION="${NODE_VERSION:-24.22.1}"
NVM_VERSION="${NVM_VERSION:-v0.40.5}"
# Pin the package-manager toolchain independently of the agent releases.
NPM_VERSION="${NPM_VERSION:-12.0.2}"
export NVM_DIR="/.sprite/languages/node/nvm"

mkdir -p "$NVM_DIR" "/.sprite/bin"

echo "Downloading and installing nvm ${NVM_VERSION}..."
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
rm -rf "$NVM_DIR/.git" "$NVM_DIR/.github" "$NVM_DIR/test"
. "$NVM_DIR/nvm.sh"

echo "Installing Node.js ${NODE_VERSION}..."
nvm install "$NODE_VERSION"
nvm alias default "$NODE_VERSION"
nvm use default

echo "Installing common global packages..."
npm install -g "npm@$NPM_VERSION"
case "$TARGETARCH" in
    amd64) OPENSSL_ARCH="linux-x86_64" ;;
    arm64) OPENSSL_ARCH="linux-aarch64" ;;
esac
OPENSSL_ARCHS_DIR="$NVM_DIR/versions/node/v$NODE_VERSION/include/node/openssl/archs"
if [ -n "$OPENSSL_ARCH" ] && [ -d "$OPENSSL_ARCHS_DIR/$OPENSSL_ARCH" ]; then
    find "$OPENSSL_ARCHS_DIR" -mindepth 1 -maxdepth 1 ! -name "$OPENSSL_ARCH" -exec rm -rf {} +
fi
EOF

FROM base AS node-shims

RUN --mount=type=bind,source=gen-shims.py,target=/usr/local/bin/gen-shims \
    gen-shims << 'SPEC'
name = "node"
commands = ["node", "npm", "npx", "corepack"]
paths = ["$NODE_BIN_DIR"]
require-dirs = true

[env]
NVM_DIR = "/.sprite/languages/node/nvm"

[resolve]
shim = '''
[ -s "$NVM_DIR/nvm.sh" ] || export NVM_DIR="/.sprite/languages/node/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use default >/dev/null 2>&1 || true
NODE_BIN="$(nvm which default 2>/dev/null || nvm which current 2>/dev/null || command -v node)"
NODE_BIN_DIR="$(dirname "$NODE_BIN")"
'''
bash = '''
local NODE_BIN_DIR=""
if [ -s "$NVM_DIR/alias/default" ]; then
    local ver=$(cat "$NVM_DIR/alias/default")
    [ -d "$NVM_DIR/versions/node/$ver/bin" ] && NODE_BIN_DIR="$NVM_DIR/versions/node/$ver/bin"
    [ -z "$NODE_BIN_DIR" ] && [ -d "$NVM_DIR/versions/node/v$ver/bin" ] && NODE_BIN_DIR="$NVM_DIR/versions/node/v$ver/bin"
fi
if [ -z "$NODE_BIN_DIR" ] || [ ! -d "$NODE_BIN_DIR" ]; then
    NODE_BIN_DIR=$(ls -d "$NVM_DIR/versions/node"/*/bin 2>/dev/null | head -1)
fi
'''
fish = '''
set -l NODE_BIN_DIR "$NVM_DIR/versions/node/"(ls "$NVM_DIR/versions/node/" 2>/dev/null | head -1)"/bin"
'''
SPEC

# -- kerl and Erlang

FROM ccache AS erlang
ARG CCACHE_REFRESH

RUN --mount=type=cache,target=/.sprite/languages/erlang/kerl/archives \
    --mount=type=cache,id=ccache,target=/var/cache/ccache \
    << 'EOF'
set -e

# Baseline pinned version as of 2026-08-12: 28.5
ERLANG_VERSION="${ERLANG_VERSION:-28.5}"
KERL_VERSION="${KERL_VERSION:-4.4.0}"
export KERL_BASE_DIR="/.sprite/languages/erlang/kerl"
export KERL_BUILD_DIR="$KERL_BASE_DIR/builds"
export KERL_DEFAULT_INSTALL_DIR="$KERL_BASE_DIR/installs"
export KERL_DOWNLOAD_DIR="$KERL_BASE_DIR/archives"
ERLANG_ROOT="/.sprite/languages/erlang"

mkdir -p "$KERL_BASE_DIR" "$KERL_BUILD_DIR" "$KERL_DEFAULT_INSTALL_DIR" "$KERL_DOWNLOAD_DIR" "/.sprite/bin"

echo "Downloading kerl ${KERL_VERSION}..."
curl -fo "$KERL_BASE_DIR/kerl" "https://raw.githubusercontent.com/kerl/kerl/${KERL_VERSION}/kerl"
chmod +x "$KERL_BASE_DIR/kerl"

cat > "$KERL_BASE_DIR/.kerlrc" << KERLRC
KERL_BASE_DIR="$KERL_BASE_DIR"
KERL_BUILD_DIR="$KERL_BUILD_DIR"
KERL_DOWNLOAD_DIR="$KERL_DOWNLOAD_DIR"
KERL_DEFAULT_INSTALL_DIR="$KERL_DEFAULT_INSTALL_DIR"
KERL_BUILD_DOCS=no
KERLRC
"$KERL_BASE_DIR/kerl" update releases

echo "Building Erlang ${ERLANG_VERSION}..."
"$KERL_BASE_DIR/kerl" build "$ERLANG_VERSION" "$ERLANG_VERSION"
"$KERL_BASE_DIR/kerl" install "$ERLANG_VERSION" "$KERL_DEFAULT_INSTALL_DIR/$ERLANG_VERSION"
"$KERL_BASE_DIR/kerl" delete build "$ERLANG_VERSION"

ln -sfn "$KERL_DEFAULT_INSTALL_DIR/$ERLANG_VERSION" "$ERLANG_ROOT/current"
EOF

FROM base AS erlang-shims

RUN --mount=type=bind,source=gen-shims.py,target=/usr/local/bin/gen-shims \
    gen-shims << 'SPEC'
name = "erlang"
commands = ["erl", "erlc", "escript", "dialyzer", "rebar3", "kerl"]
paths = ["$ERL_BIN_DIR"]
activator = "erl -version"
shim-persist-paths = false

[resolve]
shim = '''
DEFAULT_LANG_ROOT="/.sprite/languages/erlang"
export KERL_BASE_DIR="${KERL_BASE_DIR:-$DEFAULT_LANG_ROOT/kerl}"
export KERL_BUILD_DIR="${KERL_BUILD_DIR:-$KERL_BASE_DIR/builds}"
export KERL_DOWNLOAD_DIR="${KERL_DOWNLOAD_DIR:-$KERL_BASE_DIR/archives}"
export KERL_DEFAULT_INSTALL_DIR="${KERL_DEFAULT_INSTALL_DIR:-$KERL_BASE_DIR/installs}"

ACTIVE_DIR="$DEFAULT_LANG_ROOT/current"
if [ ! -d "$ACTIVE_DIR" ]; then
  ACTIVE_DIR="$KERL_DEFAULT_INSTALL_DIR/28.5"
fi

cmd_name="$(basename "$0")"
if [ "$cmd_name" = "kerl" ]; then
  exec "$KERL_BASE_DIR/kerl" "$@"
fi

ERL_BIN_DIR="$ACTIVE_DIR/bin"
'''
bash = '''
local ERLANG_ROOT="/.sprite/languages/erlang"
export KERL_BASE_DIR="${KERL_BASE_DIR:-$ERLANG_ROOT/kerl}"
local LANG_ENV="/etc/profile.d/languages_env"
grep -q "^export KERL_BASE_DIR=" "$LANG_ENV" 2>/dev/null || \
    echo 'export KERL_BASE_DIR="'"$ERLANG_ROOT/kerl"'"' >> "$LANG_ENV" 2>/dev/null || true
local ACTIVE_DIR="$ERLANG_ROOT/current"
[ -d "$ACTIVE_DIR" ] && export PATH="$ACTIVE_DIR/bin:$PATH"
'''
fish = '''
set -l ERLANG_ROOT "/.sprite/languages/erlang"
set -gx KERL_BASE_DIR (test -n "$KERL_BASE_DIR"; and echo $KERL_BASE_DIR; or echo "$ERLANG_ROOT/kerl")
set -l LANG_ENV "/etc/profile.d/languages_env"
if not grep -q "^export KERL_BASE_DIR=" "$LANG_ENV" 2>/dev/null
    echo 'export KERL_BASE_DIR="'"$ERLANG_ROOT/kerl"'"' >> "$LANG_ENV" 2>/dev/null; or true
end
set -l ACTIVE_DIR "$ERLANG_ROOT/current"
if test -d "$ACTIVE_DIR"
    set -gx PATH $ACTIVE_DIR/bin $PATH
end
'''
SPEC

# -- Elixir

FROM erlang AS elixir

RUN --mount=type=cache,target=/.sprite/languages/elixir/.mix/archives/tmp \
    --mount=type=cache,target=/.sprite/languages/elixir/.hex \
    << 'EOF'
set -e

# Install multiple versions; the first is the default
# Baseline pinned versions as of 2025-12-22
ELIXIR_VERSIONS="${ELIXIR_VERSIONS:-1.19.2 1.18.4}"
ELIXIR_DEFAULT_VERSION="${ELIXIR_DEFAULT_VERSION:-1.19.2}"
ELIXIR_ROOT="/.sprite/languages/elixir"
VERSIONS_DIR="$ELIXIR_ROOT/versions"
export MIX_HOME="$ELIXIR_ROOT/.mix"
export HEX_HOME="$ELIXIR_ROOT/.hex"

export PATH="/.sprite/languages/erlang/current/bin:$ELIXIR_ROOT/current/bin:$PATH"

mkdir -p "$ELIXIR_ROOT" "/.sprite/bin"

read -r _ ELIXIR_OTP_MAJOR < /.sprite/languages/erlang/current/releases/start_erl.data
echo "Found Erlang/OTP $ELIXIR_OTP_MAJOR"

for ELIXIR_VERSION in $ELIXIR_VERSIONS; do
    INSTALL_DIR="$VERSIONS_DIR/$ELIXIR_VERSION-otp-$ELIXIR_OTP_MAJOR"

    if [ -d "$INSTALL_DIR" ]; then
        echo "Elixir $ELIXIR_VERSION already installed, skipping..."
        continue
    fi

    echo "Downloading precompiled Elixir $ELIXIR_VERSION for OTP $ELIXIR_OTP_MAJOR..."
    mkdir -p "$INSTALL_DIR"

    TMP_ZIP="/tmp/elixir-precompiled.zip"
    set +e
    curl -fsSL "https://repo.hex.pm/builds/elixir/v$ELIXIR_VERSION-otp-$ELIXIR_OTP_MAJOR.zip" -o "$TMP_ZIP" || \
    curl -fsSL "https://github.com/elixir-lang/elixir/releases/download/v$ELIXIR_VERSION/elixir-otp-$ELIXIR_OTP_MAJOR.zip" -o "$TMP_ZIP" || \
    curl -fsSL "https://github.com/elixir-lang/elixir/releases/download/v$ELIXIR_VERSION/Precompiled.zip" -o "$TMP_ZIP"
    rc=$?
    set -e
    if [ $rc -ne 0 ] || [ ! -s "$TMP_ZIP" ]; then
        echo "Failed to download precompiled Elixir for version $ELIXIR_VERSION (OTP $ELIXIR_OTP_MAJOR)."
        exit 1
    fi

    unzip -q "$TMP_ZIP" -d "$INSTALL_DIR"
    rm -f "$TMP_ZIP"
    echo "Installed Elixir $ELIXIR_VERSION"
done

ln -sfn "$VERSIONS_DIR/$ELIXIR_DEFAULT_VERSION-otp-$ELIXIR_OTP_MAJOR" "$ELIXIR_ROOT/current"

echo "Installing Hex package manager..."
"$ELIXIR_ROOT/current/bin/mix" local.hex --force

echo "Installing rebar3..."
"$ELIXIR_ROOT/current/bin/mix" local.rebar --force
EOF

FROM base AS elixir-shims

RUN --mount=type=bind,source=gen-shims.py,target=/usr/local/bin/gen-shims \
    gen-shims << 'SPEC'
name = "elixir"
commands = ["elixir", "elixirc", "iex", "mix"]
paths = ["$BIN_PATH"]
activator = "elixir --version"
shim-persist-paths = false

[resolve]
shim = '''
ELIXIR_ROOT="/.sprite/languages/elixir"
VERSIONS_DIR="$ELIXIR_ROOT/versions"

# Find .tool-versions file by walking up from current directory
find_tool_versions() {
    dir="$PWD"
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/.tool-versions" ]; then
            echo "$dir/.tool-versions"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# Get requested elixir version from .tool-versions
get_elixir_version() {
    tool_versions_file="$1"
    if [ -f "$tool_versions_file" ]; then
        # Parse "elixir <version>" line, strip any -otp-XX suffix from the spec
        ver=$(grep -E "^elixir[[:space:]]+" "$tool_versions_file" 2>/dev/null | awk '{print $2}' | sed 's/-otp-.*//')
        if [ -n "$ver" ]; then
            echo "$ver"
            return 0
        fi
    fi
    return 1
}

# Find matching installed version
find_installed_version() {
    requested="$1"
    # Look for exact match with any OTP suffix
    match=$(ls -d "$VERSIONS_DIR/$requested-otp-"* 2>/dev/null | head -n1)
    if [ -n "$match" ] && [ -d "$match" ]; then
        echo "$match"
        return 0
    fi
    return 1
}

# Determine which Elixir to use
BIN_PATH=""
if tool_versions_file=$(find_tool_versions); then
    if requested_version=$(get_elixir_version "$tool_versions_file"); then
        if installed_dir=$(find_installed_version "$requested_version"); then
            BIN_PATH="$installed_dir/bin"
        else
            echo "Error: Elixir $requested_version requested in $tool_versions_file but not installed." >&2
            echo "Installed versions:" >&2
            ls -1 "$VERSIONS_DIR" 2>/dev/null | sed 's/^/  /' >&2
            echo "Run: elixir-version install $requested_version" >&2
            exit 1
        fi
    fi
fi

# Fall back to current symlink if no .tool-versions or no elixir line
if [ -z "$BIN_PATH" ]; then
    BIN_PATH="$ELIXIR_ROOT/current/bin"
fi

'''
bash = '''
local ELIXIR_ROOT="/.sprite/languages/elixir"
local ACTIVE_DIR="$ELIXIR_ROOT/current"
[ -d "$ACTIVE_DIR" ] && export PATH="$ACTIVE_DIR/bin:$PATH"
export MIX_HOME="${MIX_HOME:-$ELIXIR_ROOT/.mix}"
export HEX_HOME="${HEX_HOME:-$ELIXIR_ROOT/.hex}"
local LANG_ENV="/etc/profile.d/languages_env"
grep -q "^export MIX_HOME=" "$LANG_ENV" 2>/dev/null || \
    echo 'export MIX_HOME="'"$ELIXIR_ROOT/.mix"'"' >> "$LANG_ENV" 2>/dev/null || true
grep -q "^export HEX_HOME=" "$LANG_ENV" 2>/dev/null || \
    echo 'export HEX_HOME="'"$ELIXIR_ROOT/.hex"'"' >> "$LANG_ENV" 2>/dev/null || true
'''
fish = '''
set -l ELIXIR_ROOT "/.sprite/languages/elixir"
set -l ACTIVE_DIR "$ELIXIR_ROOT/current"
if test -d "$ACTIVE_DIR"
    set -gx PATH $ACTIVE_DIR/bin $PATH
end
set -gx MIX_HOME (test -n "$MIX_HOME"; and echo $MIX_HOME; or echo "$ELIXIR_ROOT/.mix")
set -gx HEX_HOME (test -n "$HEX_HOME"; and echo $HEX_HOME; or echo "$ELIXIR_ROOT/.hex")
set -l LANG_ENV "/etc/profile.d/languages_env"
if not grep -q "^export MIX_HOME=" "$LANG_ENV" 2>/dev/null
    echo 'export MIX_HOME="'"$ELIXIR_ROOT/.mix"'"' >> "$LANG_ENV" 2>/dev/null; or true
end
if not grep -q "^export HEX_HOME=" "$LANG_ENV" 2>/dev/null
    echo 'export HEX_HOME="'"$ELIXIR_ROOT/.hex"'"' >> "$LANG_ENV" 2>/dev/null; or true
end
'''
SPEC

# -- Go

FROM base AS go
ARG TARGETARCH

RUN << 'EOF'
set -e

# Baseline pinned version as of 2025-10-04: 1.25.1
GO_VERSION="${GO_VERSION:-1.25.1}"
GO_BASE_DIR="/.sprite/languages/go"
GO_VERSION_DIR="$GO_BASE_DIR/versions/$GO_VERSION"

mkdir -p "$GO_VERSION_DIR" "/.sprite/bin"

DOWNLOAD_URL="https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz"
echo "Downloading Go ${GO_VERSION} from: $DOWNLOAD_URL"
curl -fsSL -o "/tmp/go${GO_VERSION}.tar.gz" "$DOWNLOAD_URL"
tar -xzf "/tmp/go${GO_VERSION}.tar.gz" -C "$GO_VERSION_DIR" --strip-components=1
rm "/tmp/go${GO_VERSION}.tar.gz"

ln -sf "$GO_VERSION_DIR" "$GO_BASE_DIR/current"

mkdir -p "$GO_BASE_DIR/workspace/src" "$GO_BASE_DIR/workspace/bin" \
    "$GO_BASE_DIR/workspace/pkg"
EOF

FROM base AS go-shims

RUN --mount=type=bind,source=gen-shims.py,target=/usr/local/bin/gen-shims \
    gen-shims << 'SPEC'
name = "go"
commands = ["go", "gofmt"]
paths = ["/.sprite/languages/go/current/bin"]

[env]
GOPATH = "/.sprite/languages/go/workspace"
SPEC

# -- rbenv + Ruby

FROM ccache AS ruby
ARG CCACHE_REFRESH

RUN --mount=type=cache,target=/root/.cache/gem \
    --mount=type=cache,id=ccache,target=/var/cache/ccache \
    << 'EOF'
set -e

export RUBY_BUILD_BUILD_PATH=/tmp/ruby-build

# Baseline pinned version as of 2025-10-04: 3.4.6
RUBY_VERSION="${RUBY_VERSION:-3.4.6}"
export RBENV_ROOT="/.sprite/languages/ruby/rbenv"
export PATH="$RBENV_ROOT/bin:$PATH"

mkdir -p "$RBENV_ROOT" "/.sprite/bin"

echo "Installing rbenv..."
git clone https://github.com/rbenv/rbenv.git "$RBENV_ROOT"
cd "$RBENV_ROOT" && src/configure && make -C src

echo "Installing ruby-build plugin..."
mkdir -p "$RBENV_ROOT/plugins"
git clone https://github.com/rbenv/ruby-build.git "$RBENV_ROOT/plugins/ruby-build"
rm -rf "$RBENV_ROOT/.git" "$RBENV_ROOT/plugins/ruby-build/.git"

echo "Installing Ruby ${RUBY_VERSION}..."
rbenv install "$RUBY_VERSION"
rbenv global "$RUBY_VERSION"
rbenv rehash

echo "Updating RubyGems..."
"$RBENV_ROOT/shims/gem" update --system
"$RBENV_ROOT/shims/gem" install bundler

"$RBENV_ROOT/shims/gem" cleanup --silent || true
"$RBENV_ROOT/shims/gem" uninstall -ax rubygems-update || true
find "$RBENV_ROOT/versions" -path '*/gems/*/ext/*' -name '*.o' -delete
rm -rf /tmp/ruby-build.*.log
EOF

FROM base AS ruby-shims

RUN --mount=type=bind,source=gen-shims.py,target=/usr/local/bin/gen-shims \
    gen-shims << 'SPEC'
name = "ruby"
commands = ["ruby", "gem", "bundle", "bundler", "irb", "rake", "rbenv"]
paths = ["$RBENV_ROOT/shims", "$RBENV_ROOT/bin"]

[exec-overrides]
rbenv = "$RBENV_ROOT/bin"

[env]
RBENV_ROOT = "/.sprite/languages/ruby/rbenv"
SPEC

# -- Rust

FROM base AS rust

RUN --mount=type=cache,target=/.sprite/languages/rust/rustup/downloads \
    << 'EOF'
set -e

# Baseline pinned version as of 2025-10-04: 1.90.0
RUST_VERSION="${RUST_VERSION:-1.90.0}"
export RUSTUP_HOME="/.sprite/languages/rust/rustup"
export CARGO_HOME="/.sprite/languages/rust/cargo"
export PATH="$CARGO_HOME/bin:$PATH"

mkdir -p "$RUSTUP_HOME" "$CARGO_HOME" "/.sprite/bin"

echo "Downloading and installing rustup..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- -y --no-modify-path --default-toolchain none

echo "Installing Rust ${RUST_VERSION}..."
# Download everything in the default profile except rust-docs (~600 MB).
rustup toolchain install --profile minimal "$RUST_VERSION"
rustup default "$RUST_VERSION"
rustup component add clippy rust-src rust-analysis rustfmt
rustup self update -y >/dev/null 2>&1 || true
rm -rf "$RUSTUP_HOME/tmp"
EOF

FROM base AS rust-shims

RUN --mount=type=bind,source=gen-shims.py,target=/usr/local/bin/gen-shims \
    gen-shims << 'SPEC'
name = "rust"
commands = ["rustc", "cargo", "rustup", "rustfmt", "rustdoc"]
paths = ["$CARGO_HOME/bin"]

[env]
RUSTUP_HOME = "/.sprite/languages/rust/rustup"
CARGO_HOME = "/.sprite/languages/rust/cargo"
SPEC

# -- Bun

FROM base AS bun

RUN << 'EOF'
set -e

export BUN_INSTALL="/.sprite/languages/bun"

mkdir -p "$BUN_INSTALL" "/.sprite/bin"

echo "Downloading and installing Bun..."
curl -fsSL https://bun.sh/install | bash
EOF

FROM base AS bun-shims

RUN --mount=type=bind,source=gen-shims.py,target=/usr/local/bin/gen-shims \
    gen-shims << 'SPEC'
name = "bun"
commands = ["bun", "bunx"]
paths = ["$BUN_INSTALL/bin"]

[env]
BUN_INSTALL = "/.sprite/languages/bun"
SPEC

# -- Deno

FROM base AS deno

RUN << 'EOF'
set -e

export DENO_INSTALL="/.sprite/languages/deno"

mkdir -p "$DENO_INSTALL" "/.sprite/bin"

echo "Downloading and installing Deno..."
curl -fsSL https://deno.land/install.sh | sh
EOF

FROM base AS deno-shims

RUN --mount=type=bind,source=gen-shims.py,target=/usr/local/bin/gen-shims \
    gen-shims << 'SPEC'
name = "deno"
commands = ["deno"]
paths = ["$DENO_INSTALL/bin"]

[env]
DENO_INSTALL = "/.sprite/languages/deno"
SPEC

# -- Java

FROM base AS java

RUN --mount=type=cache,target=/.sprite/languages/java/sdkman/archives \
    --mount=type=tmpfs,target=/.sprite/languages/java/sdkman/tmp \
    << 'EOF'
set -e

JAVA_VERSION="${JAVA_VERSION:-25-tem}"
export SDKMAN_DIR="/.sprite/languages/java/sdkman"
export SDKMAN_CANDIDATES_DIR="$SDKMAN_DIR/candidates"

mkdir -p "/.sprite/bin"

echo "Installing SDKMAN..."
curl -fsSL "https://get.sdkman.io" | bash

echo "Installing Java $JAVA_VERSION via SDKMAN..."
bash -lc "export SDKMAN_DIR='$SDKMAN_DIR'; \
  [ -s '$SDKMAN_DIR/bin/sdkman-init.sh' ] && source '$SDKMAN_DIR/bin/sdkman-init.sh'; \
  sdk install java '$JAVA_VERSION' <<< 'y'; \
  sdk default java '$JAVA_VERSION' || true"
EOF

FROM base AS java-shims

RUN --mount=type=bind,source=gen-shims.py,target=/usr/local/bin/gen-shims \
    gen-shims << 'SPEC'
name = "java"
commands = [
    "java", "javac", "jar", "jshell", "javadoc", "jcmd", "jstack", "jmap",
    "jps", "jstat", "keytool", "jlink", "jdeps",
]
paths = ["$JAVA_BIN_DIR"]
shim-persist-paths = false
require-dirs = true

[env]
SDKMAN_DIR = "/.sprite/languages/java/sdkman"

[resolve]
shim = '''
[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"

JAVA_BIN_DIR="$SDKMAN_DIR/candidates/java/current/bin"
if [ ! -d "$JAVA_BIN_DIR" ]; then
  JAVA_BIN="$(command -v java || true)"
  JAVA_BIN_DIR="$(dirname "$JAVA_BIN")"
fi
'''
bash = '''
local JAVA_BIN_DIR="$SDKMAN_DIR/candidates/java/current/bin"
'''
fish = '''
set -l JAVA_BIN_DIR "$SDKMAN_DIR/candidates/java/current/bin"
'''
SPEC

# -- pyenv + Python + uv

FROM ccache AS python
ARG CCACHE_REFRESH

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,id=ccache,target=/var/cache/ccache \
    << 'EOF'
set -e

export PYTHON_BUILD_BUILD_PATH=/tmp/python-build

# Baseline pinned version as of 2025-10-04: 3.13.7
PYTHON_VERSION="${PYTHON_VERSION:-3.13.7}"
export PYENV_ROOT="/.sprite/languages/python/pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
UV_BIN_DIR="/.sprite/languages/uv/bin"

mkdir -p "$PYENV_ROOT" "$UV_BIN_DIR" "/.sprite/bin"

echo "Installing pyenv..."
git clone https://github.com/pyenv/pyenv.git "$PYENV_ROOT"
cd "$PYENV_ROOT" && src/configure && make -C src

echo "Installing pyenv-virtualenv plugin..."
mkdir -p "$PYENV_ROOT/plugins"
git clone https://github.com/pyenv/pyenv-virtualenv.git "$PYENV_ROOT/plugins/pyenv-virtualenv"
rm -rf "$PYENV_ROOT/.git" "$PYENV_ROOT/plugins/pyenv-virtualenv/.git"

echo "Installing Python ${PYTHON_VERSION}..."
pyenv install "$PYTHON_VERSION"
pyenv global "$PYTHON_VERSION"
pyenv rehash

echo "Installing Python tools..."
"$PYENV_ROOT/shims/pip" install --upgrade pip
"$PYENV_ROOT/shims/pip" install setuptools wheel virtualenv pipenv poetry

echo "Installing uv..."
UV_INSTALLER="$(mktemp)"
curl -fsSL https://astral.sh/uv/install.sh -o "$UV_INSTALLER"
UV_UNMANAGED_INSTALL="$UV_BIN_DIR" sh "$UV_INSTALLER"
rm -f "$UV_INSTALLER"

rm -rf /tmp/python-build.*.log /tmp/python-patch.*
rm -rf "$PYENV_ROOT/install_local_python.gif" "$PYENV_ROOT/terminal_output.png" "$PYENV_ROOT/test" "$PYENV_ROOT/.github"
find "$PYENV_ROOT/versions/$PYTHON_VERSION/lib/python${PYTHON_VERSION%.*}/test" -type d -name __pycache__ -prune -exec rm -rf {} +

for cmd in uv uvx; do
    ln -sf "$UV_BIN_DIR/$cmd" "/.sprite/bin/$cmd"
done
EOF

FROM base AS python-shims

RUN --mount=type=bind,source=gen-shims.py,target=/usr/local/bin/gen-shims \
    gen-shims << 'SPEC'
name = "python"
commands = ["python", "python3", "pip", "pip3", "pipenv", "poetry", "virtualenv", "pyenv"]
paths = ["$PYENV_ROOT/shims", "$PYENV_ROOT/bin"]

[exec-overrides]
pyenv = "$PYENV_ROOT/bin"

[env]
PYENV_ROOT = "/.sprite/languages/python/pyenv"
SPEC

FROM base AS languages

COPY --from=bun /.sprite/ /.sprite/
COPY --from=deno /.sprite/ /.sprite/
COPY --from=elixir /.sprite/ /.sprite/
COPY --from=go /.sprite/ /.sprite/
COPY --from=java /.sprite/ /.sprite/
COPY --from=node /.sprite/ /.sprite/
COPY --from=python /.sprite/ /.sprite/
COPY --from=ruby /.sprite/ /.sprite/
COPY --from=rust /.sprite/ /.sprite/

COPY --chmod=u=rwX,go=rX .sprite/ /.sprite/

RUN << 'EOF'
set -e

cat >> /etc/bash.bashrc << 'RC'

# Source language paths (prepend to PATH, avoiding duplicates)
if [ -r /etc/profile.d/languages_paths ]; then
    while IFS= read -r p; do
        case ":$PATH:" in
            *":$p:"*) ;;
            *) [ -d "$p" ] && PATH="$p:$PATH" ;;
        esac
    done < /etc/profile.d/languages_paths
    export PATH
fi
RC

cat >> /etc/zsh/zshrc << 'RC'

# Source language paths (prepend to PATH, avoiding duplicates)
if [ -r /etc/profile.d/languages_paths ]; then
    while IFS= read -r p; do
        case ":$PATH:" in
            *":$p:"*) ;;
            *) [ -d "$p" ] && PATH="$p:$PATH" ;;
        esac
    done < /etc/profile.d/languages_paths
    export PATH
fi
RC

cat >> /etc/fish/config.fish << 'RC'

# Source language paths (prepend to PATH, avoiding duplicates)
if test -r /etc/profile.d/languages_paths
    for p in (cat /etc/profile.d/languages_paths)
        if test -d "$p"; and not contains $p $PATH
            set -gx PATH $p $PATH
        end
    end
end
RC
EOF

RUN --mount=type=bind,from=node-shims,source=/.sprite,target=/tmp/shims/node \
    --mount=type=bind,from=erlang-shims,source=/.sprite,target=/tmp/shims/erlang \
    --mount=type=bind,from=elixir-shims,source=/.sprite,target=/tmp/shims/elixir \
    --mount=type=bind,from=go-shims,source=/.sprite,target=/tmp/shims/go \
    --mount=type=bind,from=ruby-shims,source=/.sprite,target=/tmp/shims/ruby \
    --mount=type=bind,from=rust-shims,source=/.sprite,target=/tmp/shims/rust \
    --mount=type=bind,from=bun-shims,source=/.sprite,target=/tmp/shims/bun \
    --mount=type=bind,from=deno-shims,source=/.sprite,target=/tmp/shims/deno \
    --mount=type=bind,from=java-shims,source=/.sprite,target=/tmp/shims/java \
    --mount=type=bind,from=python-shims,source=/.sprite,target=/tmp/shims/python \
    --mount=type=bind,source=combine-shell-functions.sh,target=/usr/local/bin/combine-shell-functions \
    << 'EOF'
set -e

for dir in /tmp/shims/*
do
    cp -r "$dir/." /.sprite/
done

combine-shell-functions /.sprite/languages/shells

cat >> /etc/bash.bashrc << 'RC'

# Source language activation functions (self-unset after first use)
[ -r /.sprite/languages/shells/languages.bash ] && . /.sprite/languages/shells/languages.bash
RC

cat >> /etc/zsh/zshrc << 'RC'

# Source language activation functions (self-unset after first use)
[ -r /.sprite/languages/shells/languages.zsh ] && . /.sprite/languages/shells/languages.zsh
RC

cat >> /etc/fish/config.fish << 'RC'

# Source language activation functions (self-erase after first use)
if test -r /.sprite/languages/shells/languages.fish
    source /.sprite/languages/shells/languages.fish
end
RC
EOF

RUN touch /etc/profile.d/languages_paths /etc/profile.d/languages_env \
    && chown 1001:1001 /etc/profile.d/languages_paths /etc/profile.d/languages_env

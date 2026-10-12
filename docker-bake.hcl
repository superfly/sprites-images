group "default" {
  targets = [
    "ubuntu-base",
    "sprites-classic-devtools",
    "sprites-classic-languages",
    "sprites-classic-agents",
    "sprites-classic",
    "sprites-classic-languages-noshims",
    "sprites-classic-agents-noshims",
    "sprites-classic-noshims",
  ]
}

group "test" {
  targets = [
    "sprites-classic-languages-test",
    "sprites-classic-agents-test",
  ]
}

target "ubuntu-base" {
  context   = "./images/ubuntu-base"
  platforms = ["linux/amd64"]
  attest    = ["type=provenance,disabled=true"]
  args = {
    SOURCE_DATE_EPOCH = SOURCE_DATE_EPOCH
    UBUNTU_RELEASE    = UBUNTU_RELEASE
    UBUNTU_VERSION    = UBUNTU_VERSION
  }
}

target "sprites-classic-devtools" {
  context   = "./images/sprites-classic/devtools"
  platforms = ["linux/amd64"]
  attest    = ["type=provenance,disabled=true"]
  contexts = {
    ubuntu-base = "target:ubuntu-base"
  }
  args = {
    SOURCE_DATE_EPOCH = SOURCE_DATE_EPOCH
    UBUNTU_SNAPSHOT   = UBUNTU_SNAPSHOT
  }
}

target "sprites-classic-languages" {
  context   = "./images/sprites-classic/languages"
  platforms = ["linux/amd64"]
  attest    = ["type=provenance,disabled=true"]
  contexts = {
    sprites-classic-devtools = "target:sprites-classic-devtools"
  }
  args = {
    UBUNTU_SNAPSHOT = UBUNTU_SNAPSHOT
  }
}

target "sprites-classic-languages-noshims" {
  inherits = ["sprites-classic-languages"]
  target   = "languages-noshims"
}

# Node-only target for agent installers.
target "sprites-classic-languages-node" {
  inherits = ["sprites-classic-languages"]
  target   = "node"
}

target "sprites-classic-languages-test" {
  context    = "./images/sprites-classic/languages"
  dockerfile = "Dockerfile.test"
  platforms  = ["linux/amd64"]
  output     = ["type=cacheonly"]
  contexts = {
    ubuntu-base               = "target:ubuntu-base"
    sprites-classic-languages = "target:sprites-classic-languages"
  }
}

target "sprites-classic-agents" {
  context   = "./images/sprites-classic/agents"
  platforms = ["linux/amd64"]
  attest    = ["type=provenance,disabled=true"]
  contexts = {
    sprites-classic-devtools       = "target:sprites-classic-devtools"
    sprites-classic-languages      = "target:sprites-classic-languages"
    sprites-classic-languages-node = "target:sprites-classic-languages-node"
  }
}

target "sprites-classic-agents-noshims" {
  inherits = ["sprites-classic-agents"]
  contexts = {
    sprites-classic-languages = "target:sprites-classic-languages-noshims"
  }
}

target "sprites-classic-agents-test" {
  context    = "./images/sprites-classic/agents"
  dockerfile = "Dockerfile.test"
  platforms  = ["linux/amd64"]
  output     = ["type=cacheonly"]
  contexts = {
    ubuntu-base                    = "target:ubuntu-base"
    sprites-classic-agents         = "target:sprites-classic-agents"
    sprites-classic-languages-node = "target:sprites-classic-languages-node"
  }
}

target "sprites-classic" {
  context   = "./images/sprites-classic"
  platforms = ["linux/amd64"]
  attest    = ["type=provenance,disabled=true"]
  contexts = {
    sprites-classic-agents = "target:sprites-classic-agents"
  }
}

target "sprites-classic-noshims" {
  inherits = ["sprites-classic"]
  contexts = {
    sprites-classic-agents = "target:sprites-classic-agents-noshims"
  }
}

target "s2-nixos" {
  context   = "./experimental/s2-nixos"
  platforms = ["linux/amd64"]
  attest    = ["type=provenance,disabled=true"]
}

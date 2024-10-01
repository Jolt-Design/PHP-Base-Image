variable "platforms" {
  default = [
    "linux/amd64",
    // "linux/arm64",
  ]
}

variable "versions" {
  default = [
    // "7.4",
    "8.0",
    "8.1",
    "8.2",
  ]
}

variable "runtimes" {
  default = [
    "apache",
    // "fpm",
  ]
}

variable "default_runtime" {
  default = "apache"
}

variable "image" {
  default = "joltdesign/php"
}

group "default" {
  targets = ["php"]
}

target "php" {
  name = "php-${replace(version, ".", "-")}-${runtime}${dev ? "-dev": ""}"
  context = "build"

  matrix = {
    version = versions
    runtime = runtimes
    dev = [true, false]
  }

  args = {
    PHP_VERSION = version
    RUNTIME = runtime
  }

  platforms = platforms

  target = dev ? "dev" : "production"

  tags = concat(
    ["${image}:${version}-${runtime}${dev ? "-dev": ""}"],
    runtime == default_runtime ? ["${image}:${version}${dev ? "-dev": ""}"] : [],
  )
}

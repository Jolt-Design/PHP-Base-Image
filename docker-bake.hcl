variable "platforms" {
  default = [
    "linux/amd64",
    // "linux/arm64",
  ]
}

variable "versions" {
  default = [
    "7.4",
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

variable "dependency_versions" {
  default = {
    "7.4" = {
      xdebug = "3.1.6"
      mcrypt = "1.0.4"
    }
  }
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
    XDEBUG_VERSION = try(dependency_versions[version]["xdebug"], null)
    MCRYPT_VERSION = try(dependency_versions[version]["mcrypt"], null)
  }

  platforms = platforms

  target = dev ? "dev" : "production"

  tags = concat(
    ["${image}:${version}-${runtime}${dev ? "-dev": ""}"],
    runtime == default_runtime ? ["${image}:${version}${dev ? "-dev": ""}"] : [],
  )
}

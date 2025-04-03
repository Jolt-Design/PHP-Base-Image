variable "platforms" {
  // This is a string so it can be overwritten with env vars for testing
  default = "linux/amd64"
}

variable "versions" {
  default = [
    "7.4",
    "8.0",
    "8.1",
    "8.2",
    "8.3",
    "8.4",
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

// tag_suffix lets you optionally add a suffix to the image tag, e.g. passing tag_suffix="-v2" would generate tags like `joltdesign/php:8.0-v2` and `joltdesign/php:8.0-apache-v2`
variable "tag_suffix" {
  default = ""
}

variable "dependency_versions" {
  default = {
    "7.4" = {
      xdebug = "3.1.6"
      mcrypt = "1.0.4"
      imagick = "3.5.1"
    }

    "8.4" = {
      mcrypt = "disabled"
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
    IMAGICK_VERSION = try(dependency_versions[version]["imagick"], null)
  }

  platforms = split(",", platforms)

  target = dev ? "dev" : "production"

  tags = concat(
    ["${image}:${version}-${runtime}${dev ? "-dev": ""}${tag_suffix}"],
    runtime == default_runtime ? ["${image}:${version}${dev ? "-dev": ""}${tag_suffix}"] : [],
  )
}

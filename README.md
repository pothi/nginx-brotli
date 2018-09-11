# Compile Nginx from Source with Brotli Support

This little script compiles Nginx from source with [Brotli](https://opensource.googleblog.com/2015/09/introducing-brotli-new-compression.html) support.

## Supported Platforms

- Debian 9
- Ubuntu 16.04 and Ubuntu 18.04

## What does it do?

It compiles Nginx from source and creates two `.deb` files...

1. nginx_version~os_arch.deb
2. nginx-dbg_version~os_arch.deb

Both files depend on each other. So, one can not work, if other is not installled.

## How to install?

Once you have the `.deb` files, install them using `sudo dpkg -i nginx*.deb`.

## How to compile?

Download the script, go through what it does and execute it under the user with sudo privilege. It may take a while to compile depending on the memory and CPU in your server.

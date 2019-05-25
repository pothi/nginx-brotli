# Compile Nginx from Source with Brotli Support

This little script compiles Nginx from source with [Brotli](https://opensource.googleblog.com/2015/09/introducing-brotli-new-compression.html) support. In particular, it uses [https://github.com/eustas/ngx_brotli/](https://github.com/eustas/ngx_brotli/) to compile Nginx.

## Supported Platforms

- Debian 9
- Ubuntu 16.04 and Ubuntu 18.04
- Linux Mint 19 Tara

## Tested Nginx versions

- Stable versions: 1.16
- Mainline versions: 1.17

## What does it do?

It compiles Nginx from source and creates two `.deb` files...

1. nginx_version~os_arch.deb
2. nginx-dbg_version~os_arch.deb

Both files depend on each other. So, one can not work, if other is not installled.

## How to install?

Run the script as `root` and the script tries to install the `.deb` files automatically, replacing the existing Nginx installation. 

Or you can install manually using `sudo dpkg -i nginx*.deb`, once you have the `.deb` files at the end of the execution of the script.

## How to compile?

Download the script (and gcc patch file, if needed), go through what it does (note: never trust any script on the internet) and execute it as a user with sudo privilege. It may take a while to compile depending on the memory and CPU in your server.

## Contributors and Sources

* [Rafał Michalski](https://github.com/PLumowina) - provided patch for gcc-8 and brought a number of best practices to this script.
* [Eugene Kliuchnikov](https://github.com/eustas) - this script is based on his work at [https://github.com/eustas/ngx_brotli](https://github.com/eustas/ngx_brotli).

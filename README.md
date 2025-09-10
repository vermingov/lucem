# Notice
As of *8th of May, 2025*: Lucem is now **officially deprecated**. No updates will henceforth be released. 

#

This is why Verm was created.\
Verm is a fork of Lucem, and i am constantly updating it to keep it working.\
I will also be adding new features every now and then.\
Everything in here will stay open-source.

ALL CREDITS GO TO THE OWNER OF THE ORIGINAL REPO: https://github.com/xTrayambak/lucem (Deprecated)

## <img width="512" src="src/assets/verm-title.svg">
verm is a small wrapper over [Sober](https://sober.vinegarhq.org) to provide some QoL improvements. \
Please keep in mind that while verm is fully open source software, Sober is proprietary for a very good reason, that being to preserve RoL from 9-year-old skiddies.

![A demo of verm's font patcher](screenshots/roblox_fonts.png)
![A demo of verm demonstrating Discord rich presence and a notification saying where the server is located](screenshots/demo.webp)

## Contact/Support
You can open issues for bugs. \
We now have a Discord server! You can join it [here](https://discord.gg/Z5m3n9fjcU)

## Disclaimer, in big bold letters.
verm does not allow you to bypass the (reasonable and justified) restrictions the Vinegar team has put on Sober's ability to load APKs that are modified.

If you really cheat on Roblox, I'd say you should reconsider your life decisions than anything. \
**Verm is not associated with the VinegarHQ team or Roblox, nor is it endorsed by them!**
 
## Features
- GTK4 + Libadwaita GUI to modify settings
- GTK4-based FFlag editor that is easy to use
- Rich presence
- Server region notifier
- Game overlay
- If you're not a fan of GUIs, we provide a nifty configuration file that does the same thing! (located at `~/.config/verm/config.toml`, or you can run `verm edit-config`!)
- Managing Sober

Whilst not a feature you use directly, verm also caches API calls whenever it can in order to save bandwidth and resources.

## Icon
The verm icon is made by [AshtakaOOf](https://github.com/AshtakaOOf). It is located [here](src/assets/verm.svg). \
You are free to use it wherever you want.

### Patches
verm provides the following optional patches. All of them go under the `tweaks` section in your configuration.

#### Bring back the old Oof sound
```toml
oldOof = true
```

#### Use another font
Both OTFs and TTFs are supported.
```toml
font = "/path/to/your/font.ttf"
```

#### Replace sun and moon
```toml
sun = "/path/to/sun.jpeg"
moon = "/path/to/moon.jpeg"
```

#### Force X11 or Wayland to be used
This one goes in the `client` section!
```toml
[client]
backend = "x11" # or "wayland", "wl". This is case insensitive.
```

## Installation
### AUR
If you use Arch, you can install verm directly from the [AUR](https://aur.archlinux.org/packages/verm-git) using
```command
# yay -S verm-git
```

### Building from source
You will need the following dependencies to compile verm:

#### Arch
```command
# pacman -S gtk4 libadwaita nim git libcurl
```

#### Fedora
```command
# dnf install gtk4-devel libadwaita-devel git libcurl-devel
```
You can get nim from the [Terra](https://terra.fyralabs.com/) repository

#### Debian
```command
# apt install gtk4 libadwaita-1-0 libadwaita-1-dev git libcurl4-openssl-dev
```
Debian ships an old version of Nim that is not compatible with verm, install Nim [here](https://nim-lang.org/install_unix.html)

#### NixOS
There's no Nix flake yet.
```command
$ git clone https://github.com/xTrayambak/verm
$ cd verm
$ nix-shell
```

The package names are similar for other distributions.

Run the following command to compile verm.
```command
$ nimble install https://github.com/xTrayambak/verm
```

## Submitting bug reports
Please make sure to attach the logs that verm generates. Also, please run verm with the verbose flag (`verm run -v`) and submit that log as it contains crucial debugging informationt.

## Usage
### Launching the verm GUI
```command
$ verm shell
```

### Configuring verm
```command
$ verm edit-config
```

This will open the configuration file in your preferred editor. Your configuration will immediately be validated after you exit the editor.

### Launching Roblox
```command
$ verm run
```

### Check build metadata
```command
$ verm meta
```

### Clearing API caches
```command
$ verm clear-cache
```

### Installing Desktop File
```command
$ verm install-desktop-files
```

### Installing Systemd Service (run as user, not root!)
```command
$ verm install-systemd-service
```

## Troubleshooting

### It says `verm: command not found` after compiling!
The nimble binary folder is not in your PATH, you can run:
```command
$ export PATH=$HOME/.nimble/bin:$PATH
```
Add the export to your .bashrc to make it permanent.

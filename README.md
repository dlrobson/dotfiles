# Setup

First, ensure that all dependencies are installed:
```bash
sudo apt install git curl stow unzip
```

Now, you can run `setup.sh`. In the root of the directory, run
```bash
./setup.sh
```

## Installing Neovim and its dependencies

Install the unstable version of neovim
```bash
sudo add-apt-repository ppa:neovim-ppa/unstable && sudo apt dist-upgrade
```

Open up nvim, and run `PackerSync` while in COMMAND mode:
```vim
:PackerSync
```

## Setting up Linters, Formatters, and Intellisense

**TODO**: How to check linter status


To install the `rust-analyzer`
```bash
curl -L https://github.com/rust-analyzer/rust-analyzer/releases/latest/download/rust-analyzer-$(uname -m)-unknown-linux-gnu.gz | gunzip -c - > ~/.cargo/bin/rust-analyzer
chmod 755 ~/.cargo/bin/rust-analyzer
```

Ensure that clangd is in path. *This argument may be different*. You may need to install clangd through apt or other means
```bash
sudo ln -s clangd-14 clangd
```

**TODO**: clang-tidy

**TODO**: copilot

# Good Fonts

Good font list which include other special characters. Download, install, and then change the terminal font to match.

- HackNerdFont
```
curl https://github.com/ryanoasis/nerd-fonts/releases/download/v2.3.0/Hack.zip
```

# NVIM Hotkeys
Go to declaration of function
```
Ctrl+r+j
```

Open file
```
space + z
```

Open file in vertical mode
```
space + z + ctrl + v
```

Open file in horizontal mode
```
space + z + ctrl + x
```

Delete word
```
dw
```

Format
```
space + f
```

Remove intellisense for copilot
```
ctrl + e
```

Expand pane vertically
```
ctrl + w + _
```

Expand pane horizontally
```
ctrl + w + |
```

Equalize Panes
```
ctrl + w + =
```

# TMUX ACTIONS
New tmux window
```
Ctrl + b + c
```

Move to next tmux window
```
Ctrl + b + n
```

Move to previous tmux window
```
Ctrl + b + p
```

Move to tmux window
```
Ctrl + b + 1
```


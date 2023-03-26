# Setup

First, ensure that all dependencies are installed:
```bash
sudo apt install git curl stow unzip
```

Clone the repo to your home directory, and setup the dotfiles:
```bash
git clone https://github.com/dlrobson/dotfiles.git
cd dotfiles
./setup.sh
```

Install the unstable version of neovim. neovim was for some reason needed for `fzf`
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
## Errors:

### With Ctrl-R: `unknown option: --scheme=history`

Something was wrong with the installed version of fzf. Try:
```bash
sudo apt remove fzf
```

**TODO**: clang-tidy

**TODO**: copilot

# Good Fonts

Good font list which include other special characters. Download, install, and then change the terminal font to match.

- HackNerdFont
```
curl https://github.com/ryanoasis/nerd-fonts/releases/download/v2.3.0/Hack.zip
```



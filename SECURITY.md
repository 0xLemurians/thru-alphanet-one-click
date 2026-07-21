# Security notes

- Thru CLI private keys are stored locally in plaintext inside `~/.thru/cli/config.yaml`.
- Never commit that file, paste it into issues, or share it in screenshots.
- This repository's `.gitignore` blocks common secret paths, but `.gitignore` is not a substitute for careful review.
- The project targets AlphaNet/testnet. Do not treat faucet funds as real assets.
- Review shell scripts before running them as root.

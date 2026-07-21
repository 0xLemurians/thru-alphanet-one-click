# Thru AlphaNet One-Click DevKit

An unofficial community installer for setting up the Thru AlphaNet C development environment on Ubuntu 24.04.

The underlying installation workflow was manually tested end-to-end using:

- Thru CLI `0.2.38`
- NVM `0.40.3`
- Node.js `24`
- RISC-V toolchain `0.2.38`
- Thru C SDK `0.2.38`
- AlphaNet account creation
- Faucet funding
- Example C program build
- Unique-seed program upload

> **Warning:** Thru AlphaNet and its development tools are pre-release software and may change.

## Requirements

- Ubuntu Server 24.04 LTS
- x86_64 architecture
- Root or sudo access
- At least 8 GB free disk space
- Internet connection

## One-line installation

Run this command on a clean Ubuntu 24.04 server:

```bash
git clone --depth 1 https://github.com/0xLemurians/thru-alphanet-one-click.git && cd thru-alphanet-one-click && sudo -H bash install.sh --full
```

The installer will ask for confirmation before starting.

For unattended test servers:

```bash
git clone --depth 1 https://github.com/0xLemurians/thru-alphanet-one-click.git && cd thru-alphanet-one-click && sudo -H bash install.sh --full --yes
```

## Verify the installation

```bash
cd thru-alphanet-one-click
sudo -H bash verify.sh
```

## What the installer does

1. Checks for Ubuntu 24.04 and x86_64.
2. Installs the required system packages.
3. Installs NVM and Node.js 24.
4. Installs Thru CLI `0.2.38`.
5. Tests the AlphaNet connection.
6. Downloads the pinned RISC-V toolchain.
7. Verifies the toolchain SHA-256 checksum.
8. Downloads the pinned Thru C SDK.
9. Verifies the C SDK SHA-256 checksum.
10. Builds and installs the C SDK library.
11. Creates the default AlphaNet key and account.
12. Requests test tokens from the faucet when needed.
13. Creates and builds an example C program.
14. Uploads the program with a unique seed.
15. Verifies that the upload completed successfully.

## Installed locations

| Item | Location |
|---|---|
| Thru CLI configuration | `/root/.thru/cli/config.yaml` |
| RISC-V toolchain | `/root/.thru/sdk/toolchain` |
| Thru C SDK | `/root/.thru/sdk/c` |
| Example project | `/root/thru-projects/my-first-thru-program` |
| Last upload seed | `/root/.thru/last-upload-seed` |
| Installer log | `/root/thru-one-click-YYYYMMDD-HHMMSS.log` |

## Security warning

The Thru private key is stored inside:

```text
/root/.thru/cli/config.yaml
```

The installer restricts sensitive files to the root user.

Never:

- Share your private key.
- Upload `config.yaml` to GitHub.
- Publish installation logs without reviewing them.
- Use valuable production keys with this AlphaNet installer.

Use this repository only for test environments.

See [SECURITY.md](SECURITY.md) for more information.

## Common problems

### Upload transaction fails

An uploader seed may already exist on AlphaNet.

This installer generates a unique timestamp and random seed for every upload.

The latest seed is stored at:

```text
/root/.thru/last-upload-seed
```

### `tn_sdk.h: No such file or directory`

Reinstall the development kit:

```bash
sudo -H bash scripts/install_devkit.sh
```

### `cannot find -ltn_sdk`

Check that the SDK library exists:

```bash
ls -lh /root/.thru/sdk/c/thru-sdk/lib/libtn_sdk.a
```

Reinstall the development kit when the file is missing:

```bash
sudo -H bash scripts/install_devkit.sh
```

### Version mismatch

This repository intentionally pins the following components to version `0.2.38`:

- Thru CLI
- RISC-V toolchain
- Thru C SDK

Mixing different versions may cause build or upload errors.

## Upstream resources

- [Unto-Labs/thru](https://github.com/Unto-Labs/thru)
- [Thru DevKit documentation](https://docs.thru.org/program-development/setting-up-thru-devkit)
- [Thru v0.2.38 release](https://github.com/Unto-Labs/thru/releases/tag/v0.2.38)

## Disclaimer

This repository is not affiliated with or officially supported by Unto Labs or the Thru team.

Review the scripts before running them. Use them at your own risk.

## License

Licensed under the MIT License. See [LICENSE](LICENSE).

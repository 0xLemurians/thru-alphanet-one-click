# Thru AlphaNet One-Click DevKit

A reproducible Ubuntu 24.04 setup for the Thru AlphaNet C development workflow we tested end to end:

- Thru CLI `0.2.38`
- NVM `0.40.3` + Node.js 24
- RISC-V toolchain `0.2.38`
- Thru C SDK `0.2.38`
- Keypair and on-chain account
- Faucet balance
- Example C project build
- Unique-seed uploader deployment and verification

> **Unofficial community guide.** Thru documentation is pre-release and may change before v1.0.0.

## Requirements

- Ubuntu Server 24.04 LTS
- x86_64
- Root or sudo access
- At least 4 GB RAM recommended
- At least 8 GB free disk space
- Internet access

## One-line full setup

Replace `0xLemurians` after this repository is published:

```bash
git clone --depth 1 https://github.com/0xLemurians/thru-alphanet-one-click.git && cd thru-alphanet-one-click && sudo -H bash install.sh --full
```

The command is interactive and asks for confirmation. For unattended test servers:

```bash
git clone --depth 1 https://github.com/0xLemurians/thru-alphanet-one-click.git && cd thru-alphanet-one-click && sudo -H bash install.sh --full --yes
```

## Safer two-stage setup

Install only the CLI, toolchain and C SDK:

```bash
sudo -H bash install.sh
```

Then create the test account and build/upload the sample:

```bash
sudo -H bash scripts/account.sh
sudo -H bash scripts/build_upload.sh
```

## Verify

```bash
sudo -H bash verify.sh
```

## What the full installer does

1. Validates Ubuntu 24.04 and x86_64.
2. Installs build dependencies.
3. Installs NVM, Node.js and the pinned Thru CLI.
4. Verifies AlphaNet connectivity.
5. Downloads pinned release archives and verifies SHA-256 checksums.
6. Installs the RISC-V toolchain and builds the C SDK library.
7. Creates the `default` key/account when missing.
8. Requests faucet funds when the raw balance is below `10000`.
9. Generates and builds `my-first-thru-program`.
10. Uploads with a unique seed such as `thru_demo_<timestamp>_<random>`.
11. Confirms `status: uploaded` and checks that uploader accounts are not corrupted.

## Important files

- CLI config/private key: `/root/.thru/cli/config.yaml`
- Toolchain: `/root/.thru/sdk/toolchain`
- C SDK: `/root/.thru/sdk/c`
- Example project: `/root/thru-projects/my-first-thru-program`
- Last upload seed: `/root/.thru/last-upload-seed`
- Installer log: `/root/thru-one-click-YYYYMMDD-HHMMSS.log`

## Common issues

### `Transaction verification error` / VM revert during upload

A seed may already exist on-chain. This repository automatically creates a timestamp-plus-random seed instead of reusing `my_first_thru_program`.

### `tn_sdk.h: No such file or directory`

Run:

```bash
sudo -H bash scripts/install_devkit.sh
```

### `cannot find -ltn_sdk`

Verify that this file exists:

```bash
ls -lh /root/.thru/sdk/c/thru-sdk/lib/libtn_sdk.a
```

Then reinstall the devkit if needed.

### CLI/toolchain version mismatch

This guide intentionally pins all Thru components to `0.2.38`, the combination tested by this repository.

## Security

The Thru private key is stored in plaintext in `/root/.thru/cli/config.yaml`. Never commit or share it. See [SECURITY.md](SECURITY.md).

## Upstream

- [Unto-Labs/thru](https://github.com/Unto-Labs/thru)
- [Thru DevKit documentation](https://docs.thru.org/program-development/setting-up-thru-devkit)
- [Thru v0.2.38 release](https://github.com/Unto-Labs/thru/releases/tag/v0.2.38)

## License

No license has been selected yet. Add one before encouraging external contributions.

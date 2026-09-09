# Disk Encryption with LUKS on This System

Guide for installing and using LUKS/`cryptsetup` disk encryption on this specific
laptop, plus the technical limitations found on the system that affect how (and
what) you can encrypt.

_System snapshot taken: 2026-07-21._

---

## 1. This System at a Glance

| Item | Value |
|------|-------|
| OS | Ubuntu 24.04.4 LTS |
| Kernel | 6.8.0-136-generic (x86_64) |
| CPU | Intel Core i7-9750H (12 threads), **AES-NI** hardware acceleration present |
| RAM / Swap | 15 GiB / 2 GiB (swap currently unencrypted) |
| Firmware | UEFI, **Secure Boot disabled** |
| TPM | **TPM 2.0 present** (`/dev/tpm0`, `/dev/tpmrm0`) |
| Boot | GRUB 2.12 via EFI shim (`\EFI\ubuntu\shimx64.efi`) |
| Dual boot | Windows Boot Manager on the same disk |
| User privileges | `dror` is in `sudo` group (can run `cryptsetup`) |

### Disk layout (`nvme0n1`, 954 GB)

| Partition | Size | FS | Mount | Notes |
|-----------|------|----|-------|-------|
| `nvme0n1p1` | 260 M | vfat | `/boot/efi` | EFI system partition (shared with Windows) |
| `nvme0n1p2` | 16 M | — | — | Microsoft reserved |
| `nvme0n1p3` | 250 G | ntfs | — | Windows data |
| `nvme0n1p4` | 200 G | ext4 | `/` | Linux root — **86% full**, `/boot` lives here |
| `nvme0n1p5` | 502 G | ntfs | `/mnt/projects` | data (12% used) |
| `nvme0n1p6` | 1000 M | ntfs | — | (likely Windows recovery) |

---

## 2. Requirements — Status on This Machine

Everything LUKS needs is already present **except the `cryptsetup` package**.

| Requirement | Status |
|-------------|--------|
| Kernel `dm-crypt` | ✅ `CONFIG_DM_CRYPT=m` (loads on demand) |
| AES / XTS crypto | ✅ `CONFIG_CRYPTO_AES=y`, `CONFIG_CRYPTO_XTS=y` |
| Hardware AES accel | ✅ `aesni_intel` module loaded, CPU has `aes` flag |
| `dmsetup` | ✅ `/usr/sbin/dmsetup` |
| GRUB LUKS modules | ✅ `cryptodisk.mod`, `luks.mod`, `luks2.mod` (efi + pc) |
| Root/sudo | ✅ user in `sudo` group |
| **`cryptsetup`** | ❌ **not installed** |

### Install the one missing package

```bash
sudo apt update
sudo apt install cryptsetup
```

That is the complete installation. LUKS and `cryptsetup` are free and open source
(GPL) — no license, subscription, or purchase.

---

## 3. Working with LUKS

### Option A (recommended here): file-backed encrypted container

Best fit for this system because there is **no free/unpartitioned space** and all
partitions hold data. A container is just a large file living inside an existing
filesystem (e.g. on the roomy `/mnt/projects`).

```bash
# 1. Create a 20 GB empty file (adjust size; ensure the host FS has room)
fallocate -l 20G /mnt/projects/secure.img

# 2. Format it as LUKS (prompts for a passphrase; erases the file's contents)
sudo cryptsetup luksFormat /mnt/projects/secure.img

# 3. Unlock -> creates /dev/mapper/secure
sudo cryptsetup open /mnt/projects/secure.img secure

# 4. Make a filesystem inside it (first time only)
sudo mkfs.ext4 /dev/mapper/secure

# 5. Mount and use
sudo mkdir -p /mnt/secure
sudo mount /dev/mapper/secure /mnt/secure

# ... work in /mnt/secure ...

# 6. Lock again when done
sudo umount /mnt/secure
sudo cryptsetup close secure
```

> Note: `/mnt/projects` is NTFS (mounted via fuseblk). A container file works on
> NTFS, but a native ext4 host would be more robust. If you plan heavy use,
> consider dedicating space on an ext4 filesystem.

### Option B: encrypt a whole partition

Same commands, target a partition instead of a file (e.g. `/dev/nvme0n1p6`).
**`luksFormat` erases the partition** — back up first. You have no spare partition
today, so you would first have to free one up (see limitations below).

### Everyday commands

```bash
sudo cryptsetup open <device_or_file> <name>   # unlock
sudo cryptsetup close <name>                    # lock
sudo cryptsetup luksDump <device_or_file>       # show header/key slots
sudo cryptsetup luksAddKey <device>             # add a second passphrase
sudo cryptsetup luksChangeKey <device>          # change a passphrase
```

### Auto-mount at boot (optional)

Add to `/etc/crypttab` (unlock) and `/etc/fstab` (mount). For a container you will
be prompted for the passphrase at boot, or point it at a keyfile.

---

## 4. Technical Limitations Found on This System

These are the real constraints, ordered by how likely they are to bite you.

### 4.1 No free disk space to add an encrypted partition
Every partition on the NVMe is allocated and in use. To encrypt a **new partition**
you must first shrink/back-up-and-reformat an existing one. This is why the
**file-backed container (Option A)** is the path of least resistance.

### 4.2 Root partition is 86% full and has no separate `/boot`
- `/` (`nvme0n1p4`) is at 86% (159 G of 196 G). Not a good encryption candidate,
  and low headroom for a large container.
- `/boot` is **not** a separate partition — it lives on the root ext4. So
  **encrypting root** would put the kernel/initramfs inside the LUKS container,
  forcing GRUB to unlock LUKS itself → **two passphrase prompts at boot** unless a
  keyfile is configured, or you carve out a separate unencrypted `/boot` (no free
  space for that today).

### 4.3 GRUB is capable but not configured for cryptodisk
GRUB has the LUKS modules, but:
- `GRUB_ENABLE_CRYPTODISK` is **not set** in `/etc/default/grub`. Encrypting root
  requires adding `GRUB_ENABLE_CRYPTODISK=y`, then `sudo update-grub` +
  `sudo grub-install`.
- GRUB's LUKS2 support struggles with the default **Argon2id** key derivation; you
  may need to reformat the boot volume with `--pbkdf pbkdf2` for GRUB to unlock it.
- None of this matters for a **data partition or container** — GRUB is not involved.

### 4.4 Dual-boot with Windows on the same disk
`Boot0004 Windows Boot Manager` shares the same EFI partition. Encrypting a Linux
data volume does not touch Windows, but any repartitioning to free space (4.1/4.2)
must avoid disturbing the Windows/EFI layout. Windows cannot read LUKS volumes.

### 4.5 Swap is unencrypted
`Swap: 2.0 GiB`, currently plain. Sensitive data paged out to swap would be written
in the clear. For real confidentiality, encrypt swap too (e.g. a random-key LUKS
swap via `/etc/crypttab`, or use a swapfile inside an encrypted volume).

### 4.6 Secure Boot is disabled
`mokutil --sb-state` → **SecureBoot disabled**. LUKS works fine either way, but with
Secure Boot off there is no firmware-level protection against a tampered
bootloader/initramfs (an "evil maid" could alter the unencrypted `/boot`). This is a
threat-model note, not a blocker.

### 4.7 TPM 2.0 present but unused
A **TPM 2.0** is available (`/dev/tpm0`). It is **not** currently used to seal any
LUKS key. Optionally you could enroll a TPM-bound key (e.g. `systemd-cryptenroll
--tpm2-device=auto`) for automatic unlock without typing a passphrase — but note
that TPM auto-unlock without Secure Boot + measured boot weakens the security
guarantee.

---

## 5. Recommendation for This Machine

1. `sudo apt install cryptsetup`.
2. Use a **file-backed LUKS container** (Option A) for encrypting sensitive files —
   it sidesteps the no-free-space and `/boot` limitations entirely and needs no
   GRUB changes.
3. Only pursue **full root/disk encryption** if you are prepared to back up,
   repartition to add a dedicated `/boot`, reconfigure GRUB cryptodisk, and work
   around the Windows dual-boot layout.
4. If you go further, also **encrypt swap** and consider **TPM enrollment** with the
   Secure Boot caveat in mind.

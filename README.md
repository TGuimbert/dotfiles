# dotfiles

## NixOs installation

To enable discards at the LUKS configuration and to use fstrim, add the `--allow-discards` option, like this:

```bash
cryptsetup --allow-discards --persistent refresh luks-643dc-4e37-9207-5c053a75fc70
```

To verify that it is working:

```sh
$ cryptsetup luksDump /dev/sda4 | grep Flags
Flags:          allow-discard
```
# Sources

- [Enable TRIM on external LUKS encrypted drive](https://www.guyrutenberg.com/2021/11/23/enable-trim-on-external-luks-encrypted-drive/)

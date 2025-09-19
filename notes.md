# Interesting observations

## AppArmor FUSE

AppArmor in Ubuntu denies fusemounts in `/var/tmp`, so we have two tempdirs:
- `/tmp` (RAM) for FUSE mounts (fuseiso, archivemount)
- `/var/tmp` (disk) for 7z extraction of large UDF DVDs

Kernel log shows: `apparmor="DENIED" operation="mount" profile="fusermount3" name="/var/tmp/"`

Fix: `make_tmpdir` function with "ram" or "disk" option.

## Roxio DVD Producer 1.0 timstamp bugs

Found a DVD created with "Roxio (Sonic) DVD Producer 1.0" with invalid file
timestamp of `-2211753600` (1899-11-30T00:00:00+00:00).

Doing arithmetic on sentinel values eh?

- Year: 1900 + (-1) = 1899
- Month: January + (-1) = December (of previous year)  
- Day: 1st + (-1) = 30th (last day of November)
- equals exactly midnight on 1899-11-30

```bash
udfinfo disc.iso | grep "impid=*DVD Producer 1.0"
```

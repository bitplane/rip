# ✅ to-do list

## general

- [ ] reconsider layout - flexible pipelines baked into job dirs.
- [ ] root level config file
  - [ ] zip method (zstd, xz, gz)
- [ ] `./configure`

## rip

- [ ] use the caching fuse mount I wrote
- [ ] when it's finished, also use qemount to load images
- [ ] better decision about what files to keep

## strip

- [ ] remove this and use hooks instead

## fs

- [ ] support settings types
- [ ] when things fail, actually fucking fail eh?

## queue

- [ ] rename to `rip_job_queue`
- [ ] add a function to re-queue an item
- [ ] support concurrent workers via pid
  - [ ] manage worker's pwd
- [ ] consider more flexible pipelines
  - [ ] have next stage information in queue dir metadata?
  - [ ] use symlinks 

## meta

- [x] add hooks for changes
  - [x] changing date or item name should rename the dir
    - [ ] this was a bad idea! fix it with queue pid fix
  - [ ] move tree to metadata
  - [ ] extract iso information
- [ ] export / import metadata to ia format

## log

- [ ] add debug log mode
- [ ] trace mode using -x
- [ ] add colours to stderr

## upload

- [ ] rename to `ship_ia`
- [ ] use xml or json rather than extracting .meta
- [ ] support other back-ends
  - [ ] google drive
  - [ ] network path
  - [ ] `ipfs`
  - [ ] `bittorrent`


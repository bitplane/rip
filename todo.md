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

## ui

- [ ] status bar for header and footer
- [ ] list file view
- [ ] make bash/awk ui library
  - [ ] test toolkit
  - [ ] low level
    - [x] buffers
    - [x] compositor / cropping
    - [ ] scene graph
    - [ ] render loop
  - [ ] widgets
    - [ ] list
    - [ ] table
    - [ ] split panel
    - [ ] header/footer bar
    - [ ] image viewer
  - [ ] input
    - [ ] generic text
    - [ ] question y/n
    - [ ] mouse hits

## dip

- [ ] `rm` bot code spam
- [ ] drop most globals, use `cd` for `pwd`
- [ ] features
  - [ ] use fs to run a shell in an archive
    - [ ] use`qemount`
  - [ ] allow renaming items

## upload

- [ ] rename to `ship_ia`
- [ ] use xml or json rather than extracting .meta
- [ ] support other back-ends
  - [ ] google drive
  - [ ] network path
  - [ ] `ipfs`
  - [ ] `bittorrent`


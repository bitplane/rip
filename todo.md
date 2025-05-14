# ✅ to-do list

## general

- [ ] reconsider layout - flexible pipelines baked into job dirs.

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
- [ ] manage worker's pwd
- [ ] support concurrent workers via pid
- [ ] consider more flexible pipelines

## meta

- [ ] rename this to `rip_job_info`
- [x] add hooks for changes
  - [ ] changing date or item name should rename the dir
    - actually let's do this by changing the item's name, which will attempt
      to change the dir on a hook
  - [x] ddrescue log should update integrity
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

## dip

- [ ] rm bot code spam
- [ ] drop env vars, use cd for pwd
- [ ] use fs to run a shell in an archive
- [ ] allow renaming items
- [ ] file list as a source of truth

## upload

- [ ] rename to `ship_ia` 


# ✅ to-do list

## general

- [ ] reconsider layout - flexible pipelines baked into job dirs.

## rip

- [ ] use the caching fuse mount I wrote
- [ ] when it's finished, also use qemount to load images
- [ ] better decision about what files to keep

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
- [ ] register generation functions for keys + callbacks for changes
  - [ ] changing date or item name should rename the dir
- [ ] export / import metadata to ia format

## log

- [ ] add debug log mode
- [ ] trace mode using -x
- [ ] add colours to stderr

## ui

- [ ] move more code in from dip
- [ ] status bar for header and footer
- [ ] list file view

## dip

- [ ] rm bot code spam
- [ ] drop env vars, use cd for pwd
- [ ] use fs to run a shell in an archive
- [ ] allow renaming items
- [ ] file list as a source of truth

## upload

- [ ] rename to `ship_ia`
- [ ] 


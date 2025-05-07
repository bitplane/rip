# ✅ to-do list

## general

- [ ] reconsider layout - flexible pipelines baked into job dirs.

## rip

- [ ] tar passes even if it fails - pipefail?
- [ ] use the caching fuse mount I wrote
- [ ] when it's finished, also use qemount to load images
- [ ] better decision about what files to keep
- [ ] metadata for stages

## fs

- [x] fix icon extraction
- [ ] support settings types
- [ ] when things fail, actually fucking fail eh?

## queue

- [ ] rename to `rip_job_queue` and move to subdir
- [ ] add a function to re-queue an item
- [ ] manage worker's pwd
- [ ] support concurrent workers via pid
- [ ] consider more flexible pipelines

## meta

- [ ] rename this to `rip_info`
- [ ] prevent adding empty data
- [ ] register generation functions for keys + callbacks for changes
  - [ ] changing date or item name should rename the dir
- [ ] per-file attributes?
- [ ] export / import metadata to ia format

## log

- [ ] add debug log mode
- [ ] trace mode using
- [ ] add colours

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

- [ ] figure out why most of the tags don't work
- [ ] rename to ia
- [ ] for pluggable uploaders


# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

No unreleased changes.

## [2.0.0](https://github.com/puppetlabs/puppetlabs-cd4pe/tree/2.0.0)
### Changed
- default value of `$cd4pe_version` param in init.pp from 'latest'(2.x) to '3.x'
### Fixed
- syntax error in manifests/db/postgres.pp
- puppet apply failure if the install task was run from the PE console more than once

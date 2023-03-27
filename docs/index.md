# Moremore HTTP Server

This is HTTP server implementation repository from Synopse *mORMot 2* Framework

This is experimental and work in progress project so bugs and errors are to be expected.

## Goal

This repository aims to be slim version of HTTP server implementation of mORMot 2 without
ORM, SOA, REST library etc. If you need them too, you may want to use mORMot 2 directly.

## Installation

### Clone this repository

```
$ git clone https://github.com/zamronypj/moremore.git
```

### Download required static object files

Download https://synopse.info/files/mormot2static.7z

```
$ wget https://synopse.info/files/mormot2static.7z
```

Extract content of `mormot2static.7z` into `static` directory.
[Read mORMot Static Compilation Reference](https://github.com/synopse/mORMot2/tree/master/res/static) for more information.

### Set Environment variable

Set `MOREMORE_DIR` to points to Moremore library directory

```
$ export MOREMORE_DIR="/path/to/moremore"
```

## Original Read Me

[Read original Read Me here](https://github.com/synopse/mORMot2/blob/master/README.md)

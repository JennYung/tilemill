#!/usr/bin/env node
process.title = 'tilemill';

// This is necessary to make optimist not special-case into coffeescript as
// certain node installs (e.g. ubuntu node ppa) do not use `node` as the binary
// name.
process.argv[0] = 'node';
if (process.platform == 'win32') {
    process.env.HOME = process.env.HOMEPATH;
}

require('tilelive-mapnik').registerProtocols(require('tilelive'));
require('mbtiles').registerProtocols(require('tilelive'));

require('bones').load(__dirname);
!module.parent && require('bones').start();

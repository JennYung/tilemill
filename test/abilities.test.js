
require('./support/start')(function(command) {
    exports['test abilities endpoint'] = function(beforeExit, assert) {
        assert.response(command.servers['Core'],
            { url: '/assets/tilemill/js/abilities.js' },
            { status: 200 },
            function(res) {
                var body = res.body.replace(/^\s*var\s+abilities\s*=\s*(.+?);?$/, '$1');
                var abilities = JSON.parse(body);

                assert.ok(abilities.fonts.indexOf('Arial Regular') >= 0 ||
                          abilities.fonts.indexOf('Arial Regular') >= 0);
                assert.deepEqual([0,206,209], abilities.carto.colors.darkturquoise);
                assert.deepEqual([
                    "background-color",
                    "background-image",
                    "srs",
                    "buffer-size",
                    "base",
                    "paths-from-xml",
                    "minimum-version",
                    "font-directory"
                ], Object.keys(abilities.carto.symbolizers.map));

                assert.deepEqual({
                    mbtiles: true,
                    png: true,
                    pdf: true,
                    svg: true
                }, abilities.exports);
            }
        );
    };
});

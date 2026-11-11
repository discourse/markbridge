<?php

// Parses text with s9e\TextFormatter for as long as it gets some: one
// JSON object per line on stdin, {"id": 1, "text": "[b]x[/b]"}, and one
// per line on stdout, {"id": 1, "xml": "<r><B>...</B></r>"}. S9eParser
// in spec/support talks to it.
//
//   php spec/support/s9e/parse.php path/to/TextFormatter [profile]
//
// The path is a checkout of https://github.com/s9e/TextFormatter with
// `composer install --no-dev` run in it (bin/s9e-setup makes one). The
// profile is a key of profiles.php, "bbcodes" when it is left out.

use s9e\TextFormatter\Configurator;

// s9e warns about a string offset for some inputs that end in the
// middle of a tag. It parses them anyway, and the warnings would be
// thousands of lines in a fuzzer run.
error_reporting(E_ALL & ~E_WARNING);

$root = rtrim($argv[1] ?? '', '/');
if (!is_file("$root/vendor/autoload.php")) {
	fwrite(STDERR, "usage: php parse.php path/to/TextFormatter [profile]\n");
	exit(1);
}

require "$root/vendor/autoload.php";

$profiles = require __DIR__ . '/profiles.php';
$configurator = new Configurator;
$profiles[$argv[2] ?? 'bbcodes']($configurator);
extract($configurator->finalize());

while (($line = fgets(STDIN)) !== false) {
	$request = json_decode($line, true);
	echo json_encode(
		['id' => $request['id'], 'xml' => $parser->parse($request['text'])],
		JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE
	), "\n";
	flush();
}

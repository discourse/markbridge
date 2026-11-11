<?php

// Writes spec/fixtures/s9e/cases.json: what s9e\TextFormatter itself makes
// of the inputs of its own plugin tests, as the XML it stores and the
// HTML it renders. s9e_reference_spec.rb converts the XML with Markbridge,
// cooks the Markdown and compares it with that HTML.
//
//   php spec/support/s9e/generate.php path/to/TextFormatter
//
// The path is a checkout of https://github.com/s9e/TextFormatter with
// `composer install --no-dev` run in it. The inputs come from the data
// providers of its tests, which are static methods, so PHPUnit is not
// needed: a stub of its TestCase is enough to load the test classes.
//
// Every input is parsed with the two profiles below, not with the setup
// of its test: the fixture is about what a forum stores, and a forum has
// one configuration for all posts.

namespace PHPUnit\Framework {
	abstract class TestCase
	{
	}
}

namespace {
	use s9e\TextFormatter\Configurator;

	$root = rtrim($argv[1] ?? '', '/');
	if (!is_file("$root/vendor/autoload.php")) {
		fwrite(STDERR, "usage: php generate.php path/to/TextFormatter (with composer install --no-dev)\n");
		exit(1);
	}

	require "$root/vendor/autoload.php";
	spl_autoload_register(function ($class) use ($root) {
		$prefix = 's9e\\TextFormatter\\Tests\\';
		if (str_starts_with($class, $prefix)) {
			$file = "$root/tests/" . str_replace('\\', '/', substr($class, strlen($prefix))) . '.php';
			if (is_file($file)) {
				require $file;
			}
		}
	});

	$profiles = require __DIR__ . '/profiles.php';

	// Test class => data providers, by profile. The first element of a
	// test is the input, a string or an array of lines.
	$passes = 's9e\\TextFormatter\\Tests\\Plugins\\Litedown\\Parser\\Passes\\';
	$sources = [
		'flarum' => [
			$passes . 'BlocksTest' => ['getParsingTests', 'getRenderingTests'],
			$passes . 'EmphasisTest' => ['getParsingTests', 'getRenderingTests'],
			$passes . 'ForcedLineBreaksTest' => ['getParsingTests', 'getRenderingTests'],
			$passes . 'ImagesTest' => ['getParsingTests', 'getRenderingTests'],
			$passes . 'InlineCodeTest' => ['getParsingTests', 'getRenderingTests'],
			$passes . 'InlineSpoilerTest' => ['getParsingTests', 'getRenderingTests'],
			$passes . 'LinksTest' => ['getParsingTests', 'getRenderingTests'],
			$passes . 'StrikethroughTest' => ['getParsingTests', 'getRenderingTests'],
			$passes . 'SubscriptTest' => ['getParsingTests', 'getRenderingTests'],
			$passes . 'SuperscriptTest' => ['getParsingTests', 'getRenderingTests'],
			's9e\\TextFormatter\\Tests\\Plugins\\Escaper\\ParserTest' => ['getParsingTests'],
			's9e\\TextFormatter\\Tests\\Plugins\\Autolink\\ParserTest' => ['getParsingTests'],
			's9e\\TextFormatter\\Tests\\Plugins\\Autoemail\\ParserTest' => ['getParsingTests'],
			's9e\\TextFormatter\\Tests\\Plugins\\BBCodes\\BBCodesTest' => ['getPredefinedBBCodesTests'],
		],
		'bbcodes' => [
			's9e\\TextFormatter\\Tests\\Plugins\\BBCodes\\BBCodesTest' => ['getPredefinedBBCodesTests'],
			's9e\\TextFormatter\\Tests\\Plugins\\BBCodes\\ParserTest' => ['getParsingTests'],
			's9e\\TextFormatter\\Tests\\Plugins\\Autolink\\ParserTest' => ['getParsingTests'],
		],
	];

	$cases = [];
	foreach ($profiles as $profile => $configure) {
		$configurator = new Configurator;
		$configure($configurator);
		extract($configurator->finalize());

		$seen = [];
		foreach ($sources[$profile] as $class => $providers) {
			$name = preg_replace('/^.*\\\\Plugins\\\\/', '', $class);
			$name = str_replace(['\\Parser\\Passes\\', '\\'], '/', $name);
			foreach ($providers as $provider) {
				foreach ($class::$provider() as $test) {
					$text = is_array($test[0]) ? implode("\n", $test[0]) : $test[0];
					if (!is_string($text) || $text === '' || isset($seen[$text])) {
						continue;
					}
					$seen[$text] = true;

					$xml = $parser->parse($text);
					$cases[] = [
						'profile' => $profile,
						'source'  => $name,
						'text'    => $text,
						'xml'     => $xml,
						'html'    => $renderer->render($xml),
					];
				}
			}
		}
	}

	$revision = trim((string) shell_exec('git -C ' . escapeshellarg($root) . ' rev-parse HEAD'));
	$json = json_encode(
		['s9e' => $revision, 'cases' => $cases],
		JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE
	);
	$target = dirname(__DIR__, 2) . '/fixtures/s9e/cases.json';
	if (!is_dir(dirname($target))) {
		mkdir(dirname($target), 0777, true);
	}
	file_put_contents($target, $json . "\n");
	fwrite(STDERR, count($cases) . " cases written to $target\n");
}

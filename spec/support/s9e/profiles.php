<?php

// The s9e\TextFormatter setups that generate.php and parse.php parse
// with, by name.

use s9e\TextFormatter\Configurator;

// The forums Markbridge reads s9e XML from. "flarum" is what Flarum's
// core, flarum/markdown and flarum/bbcode turn on. "bbcodes" is the
// BBCodes of the s9e repository that Markbridge has a handler for,
// with line breaks like phpBB shows them.
return [
	'flarum' => function (Configurator $configurator) {
		$configurator->rootRules->enableAutoLineBreaks();
		$configurator->Escaper;
		$configurator->Autoemail;
		$configurator->Autolink;
		$configurator->Litedown;
		foreach (['B', 'I', 'U', 'S', 'URL', 'IMG', 'EMAIL', 'CODE', 'QUOTE', 'LIST', 'DEL', 'COLOR', 'CENTER', 'SIZE', '*'] as $name) {
			$configurator->BBCodes->addFromRepository($name);
		}
	},
	'bbcodes' => function (Configurator $configurator) {
		$configurator->rootRules->enableAutoLineBreaks();
		$configurator->Autoemail;
		$configurator->Autolink;
		$names = [
			'B', 'I', 'U', 'S', 'URL', 'IMG', 'EMAIL', 'CODE', 'QUOTE', 'LIST', '*', 'COLOR', 'SIZE',
			'ALIGN', 'CENTER', 'LEFT', 'RIGHT', 'JUSTIFY', 'SPOILER', 'HR', 'SUB', 'SUP',
			'TABLE', 'TR', 'TD', 'TH',
		];
		foreach ($names as $name) {
			$configurator->BBCodes->addFromRepository($name);
		}
	},
];

// Reads the defaults of site settings out of a Discourse settings YAML
// (config/site_settings.yml, or the config/settings.yml of a plugin),
// without a YAML parser: every setting is a key two spaces deep with its
// `default:` four spaces deep, which is all these files use for the
// settings read here.

// @param yaml the file content
// @param names the settings to read
// @returns an object with the defaults: booleans and whole numbers as
//   such, everything else as a string without its quotes. A setting the
//   file does not have is left out.
export function settingDefaults(yaml, names) {
  const defaults = {};
  for (const name of names) {
    const block = yaml.split(`\n  ${name}:\n`)[1]?.split(/\n {2}\S/)[0];
    const raw = block?.match(/\n? {4}default: (.*)/)?.[1]?.trim();
    if (raw === undefined) {
      continue;
    }

    if (raw === "true" || raw === "false") {
      defaults[name] = raw === "true";
    } else if (/^\d+$/.test(raw)) {
      defaults[name] = Number(raw);
    } else {
      defaults[name] = raw.replace(/^(["'])(.*)\1$/, "$2");
    }
  }
  return defaults;
}

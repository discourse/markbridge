import { defineRouteMiddleware } from '@astrojs/starlight/route-data';
import { textExportForPage, textExportHref } from './data/text-exports.mjs';

export const onRequest = defineRouteMiddleware((context) => {
  const section = textExportForPage(context.locals.starlightRoute.id);
  if (!section) return;

  // A section can contain several pages, so it is related content, not an alternate page.
  context.locals.starlightRoute.head.push({
    tag: 'link',
    attrs: {
      rel: 'related',
      type: 'text/plain',
      title: `${section.label} as Markdown`,
      href: textExportHref(section.slug),
    },
  });
});

import { getEntry } from 'astro:content';
import { defineRouteMiddleware } from '@astrojs/starlight/route-data';
import { textExportForPage, pageTextExportForPage, textExportHref } from './data/text-exports.mjs';

export const onRequest = defineRouteMiddleware(async (context) => {
  const { id } = context.locals.starlightRoute;
  const entry = await getEntry('docs', id || 'index');
  const page = entry && pageTextExportForPage(id || 'index');
  if (page) {
    context.locals.starlightRoute.head.push({
      tag: 'link',
      attrs: {
        rel: 'alternate',
        type: 'text/plain',
        title: 'This page as Markdown',
        href: textExportHref(page.slug),
      },
    });
  }
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

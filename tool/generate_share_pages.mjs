/**
 * Builds static Open Graph pages for Facebook/Telegram link previews.
 * Spark-compatible: no Cloud Functions — pages are plain Hosting files.
 *
 * Usage (after flutter build web):
 *   node tool/generate_share_pages.mjs
 */
import { mkdir, writeFile, rm, copyFile } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const PROJECT = 'dacha-annonce';
const ORIGIN = 'https://dacha-annonce.web.app';
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = join(ROOT, 'build', 'web', 's');
const WEB = join(ROOT, 'build', 'web');
// New path + version bust so Facebook does not keep the old Flutter icon cache.
const DEFAULT_IMAGE = `${ORIGIN}/brand/og-default.png?v=20261024b`;

const field = (fields, key) => {
  const v = fields?.[key];
  if (!v) return null;
  if (v.stringValue != null) return v.stringValue;
  if (v.timestampValue != null) return v.timestampValue;
  if (v.bytesValue != null) return v.bytesValue;
  if (v.integerValue != null) return Number(v.integerValue);
  if (v.arrayValue?.values) {
    return v.arrayValue.values.map((x) => x.stringValue).filter(Boolean);
  }
  return null;
};

const plain = (value) =>
  String(value ?? '')
    .replace(/[\u201C\u201D\u00AB\u00BB]/g, '"')
    .replace(/[\u2018\u2019]/g, "'")
    .replace(/\u00A0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

/** Escape for HTML attributes; keeps newlines (Facebook shows them as breaks). */
const escapeAttr = (value) =>
  String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');

const escapeText = (value) =>
  plain(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');

/** Plain post body: title, when, place, responsible, description, notes, tags. */
const buildShareText = ({
  title,
  when,
  place,
  responsible,
  body,
  notes,
  directions,
}) =>
  [
    title,
    when,
    place,
    responsible ? `Відповідальний: ${responsible}` : '',
    body,
    notes ? `Примітки: ${notes}` : '',
    directions.length ? directions.join(', ') : '',
  ]
    .map(plain)
    .filter(Boolean)
    .join('\n\n');

const formatWhen = (startIso, endIso) => {
  try {
    const start = new Date(startIso);
    const end = new Date(endIso);
    const day = new Intl.DateTimeFormat('uk-UA', {
      timeZone: 'Europe/Kyiv',
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    }).format(start);
    const t = (d) =>
      new Intl.DateTimeFormat('uk-UA', {
        timeZone: 'Europe/Kyiv',
        hour: '2-digit',
        minute: '2-digit',
        hourCycle: 'h23',
      }).format(d);
    return `${day}, ${t(start)}-${t(end)} (Київ)`;
  } catch {
    return '';
  }
};

const clip = (text, max = 650) => {
  const t = String(text ?? '').trim();
  if (t.length <= max) return t;
  return `${t.slice(0, max - 1).trim()}…`;
};

async function listPublicEvents() {
  const docs = [];
  let pageToken;
  do {
    const url = new URL(
      `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/publicEvents`,
    );
    url.searchParams.set('pageSize', '100');
    if (pageToken) url.searchParams.set('pageToken', pageToken);
    const res = await fetch(url);
    if (!res.ok) {
      throw new Error(`Firestore list failed: ${res.status} ${await res.text()}`);
    }
    const data = await res.json();
    docs.push(...(data.documents ?? []));
    pageToken = data.nextPageToken;
  } while (pageToken);
  return docs;
}

function shareHtml({
  title,
  cardTitle,
  description,
  imageUrl,
  eventUrl,
  shareUrl,
}) {
  // Humans go straight to the Flutter event page. Crawlers (Facebook) do not
  // run this script and keep reading the OG tags on this static URL.
  return `<!DOCTYPE html>
<html lang="uk">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeText(title)} · Дача</title>
  <meta name="description" content="${escapeAttr(description)}">
  <link rel="canonical" href="${escapeAttr(eventUrl)}">
  <meta property="og:site_name" content="Дача">
  <meta property="og:type" content="website">
  <meta property="og:locale" content="uk_UA">
  <meta property="og:title" content="${escapeAttr(cardTitle)}">
  <meta property="og:description" content="${escapeAttr(description)}">
  <meta property="og:url" content="${escapeAttr(shareUrl)}">
  <meta property="og:image" content="${escapeAttr(imageUrl)}">
  <meta property="og:image:secure_url" content="${escapeAttr(imageUrl)}">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="${escapeAttr(title)}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${escapeAttr(cardTitle)}">
  <meta name="twitter:description" content="${escapeAttr(description)}">
  <meta name="twitter:image" content="${escapeAttr(imageUrl)}">
  <script>location.replace(${JSON.stringify(eventUrl)});</script>
</head>
<body>
  <p><a href="${escapeAttr(eventUrl)}">${escapeText(title)}</a></p>
</body>
</html>
`;
}

async function main() {
  await rm(OUT, { recursive: true, force: true });
  await mkdir(OUT, { recursive: true });
  await mkdir(join(WEB, 'brand'), { recursive: true });
  await copyFile(
    join(ROOT, 'web', 'brand', 'og-default.png'),
    join(WEB, 'brand', 'og-default.png'),
  );
  const docs = await listPublicEvents();
  let withCover = 0;
  for (const doc of docs) {
    const id = doc.name.split('/').pop();
    const f = doc.fields ?? {};
    const title = plain(field(f, 'title') || 'Подія на Дачі');
    const body = plain(field(f, 'description') || '');
    const room = plain(field(f, 'roomNameSnapshot') || '');
    const location = plain(field(f, 'locationSnapshot') || '');
    const responsible = plain(field(f, 'responsibleName') || '');
    const notes = plain(field(f, 'notes') || '');
    const directions = (field(f, 'directions') || []).map(plain);
    const when = formatWhen(field(f, 'startAt'), field(f, 'endAt'));
    const place = [room, location].filter(Boolean).join(', ');
    // Short title only — a long og:title makes Facebook hide og:description.
    const cardTitle = clip(title, 90);
    const description = clip(
      buildShareText({
        title,
        when,
        place,
        responsible,
        body,
        notes,
        directions,
      }),
      650,
    );
    const coverBytes = field(f, 'coverImageBytes');
    const coverType = field(f, 'coverImageContentType') || 'image/jpeg';
    let imageUrl = DEFAULT_IMAGE;
    if (coverBytes) {
      const ext =
        coverType === 'image/png'
          ? 'png'
          : coverType === 'image/webp'
            ? 'webp'
            : 'jpg';
      const fileName = `${id}.cover.${ext}`;
      await writeFile(join(OUT, fileName), Buffer.from(coverBytes, 'base64'));
      // Cache-bust covers too.
      imageUrl = `${ORIGIN}/s/${encodeURIComponent(fileName)}?v=20261024b`;
      withCover += 1;
    }
    const eventUrl = `${ORIGIN}/events/${encodeURIComponent(id)}`;
    const shareUrl = `${ORIGIN}/s/${encodeURIComponent(id)}.html`;
    await writeFile(
      join(OUT, `${id}.html`),
      shareHtml({
        title,
        cardTitle,
        description,
        imageUrl,
        eventUrl,
        shareUrl,
      }),
      'utf8',
    );
  }
  console.log(
    `Share pages: ${docs.length} events (${withCover} with cover) → build/web/s`,
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

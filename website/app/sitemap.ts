import { MetadataRoute } from 'next';
import fs from 'fs';
import path from 'path';

export const dynamic = 'force-static';

const baseUrl = 'https://tracelet.ikolvi.com';

function getRoutes(dir: string, baseRoute: string = ''): string[] {
  let routes: string[] = [];
  const files = fs.readdirSync(dir);

  for (const file of files) {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);

    // Skip hidden files, api routes, or special next.js folders
    if (stat.isDirectory() && !file.startsWith('_') && !file.startsWith('.')) {
      routes = routes.concat(getRoutes(filePath, `${baseRoute}/${file}`));
    } else if (file === 'page.mdx' || file === 'page.tsx') {
      if (baseRoute === '') {
        routes.push('/');
      } else {
        routes.push(baseRoute);
      }
    }
  }

  return routes;
}

export default function sitemap(): MetadataRoute.Sitemap {
  const appDir = path.join(process.cwd(), 'app');
  const routes = getRoutes(appDir);

  return routes.map((route) => ({
    url: `${baseUrl}${route}`,
    lastModified: new Date(),
    changeFrequency: 'weekly',
    // Prioritize root and top-level language directories (/en, /es, etc.)
    priority: route === '/' || route.length <= 4 ? 1 : 0.8,
  }));
}

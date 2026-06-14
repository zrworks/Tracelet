# Notification Dropdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a localized notification bell to the website navbar highlighting the 3.3.0 features.

**Architecture:** A new JSON file (`notifications.json`) holds the notification payload. We update `translate.js` to parse and translate this JSON for all supported locales. A React component (`NotificationBell`) reads the localized JSON dynamically based on the current path and displays a dropdown, remembering state in `localStorage`. The component is injected into Nextra via `theme.config.jsx`.

**Tech Stack:** Next.js, Nextra, React, Node.js (for translation script)

---

### Task 1: Create English Notifications Data

**Files:**
- Create: `website/app/en/notifications.json`

- [ ] **Step 1: Write the JSON payload**

```json
{
  "badgeTitle": "New in 3.3.0",
  "items": [
    {
      "title": "Driving & Safety Features",
      "description": "Driving events, transport mode, crash detection, and new telematics APIs.",
      "href": "/core/driving-safety"
    }
  ]
}
```

- [ ] **Step 2: Verify JSON format**

Run: `cat website/app/en/notifications.json | jq .`
Expected: Valid JSON output.

- [ ] **Step 3: Commit**

```bash
git add website/app/en/notifications.json
git commit -m "feat(website): add english notification data"
```

### Task 2: Update Translation Script

**Files:**
- Modify: `website/scripts/translate.js`

- [ ] **Step 1: Implement JSON translation logic in `translate.js`**
Update `run()` to include `notifications.json` in the `filesToTranslate` filter. Add a new `translateJson` function alongside `translateMdx`.

```javascript
async function translateJson(content, targetLang, engine) {
  const data = JSON.parse(content);
  
  // Translate badgeTitle
  if (data.badgeTitle) {
    data.badgeTitle = engine === 'google' 
      ? await translateLineGoogle(data.badgeTitle, targetLang)
      : await translateLineBing(data.badgeTitle, targetLang);
  }
  
  // Translate items
  if (data.items && Array.isArray(data.items)) {
    for (let item of data.items) {
      if (item.title) {
        item.title = engine === 'google'
          ? await translateLineGoogle(item.title, targetLang)
          : await translateLineBing(item.title, targetLang);
      }
      if (item.description) {
        item.description = engine === 'google'
          ? await translateLineGoogle(item.description, targetLang)
          : await translateLineBing(item.description, targetLang);
      }
    }
  }
  
  return JSON.stringify(data, null, 2);
}
```
In the `worker` function, add a condition:
```javascript
        if (task.srcPath.endsWith('.mdx')) {
          translated = await translateMdx(content, task.targetLocale, engine);
          translated = translated.replace(/href="\/en\//g, \`href="/\${task.targetLocale}/\`);
          translated = translated.replace(/\\]\\(\\/en\\//g, \`](/\${task.targetLocale}/\`);
        } else if (task.srcPath.endsWith('_meta.js')) {
          translated = await translateMetaJs(content, task.targetLocale, engine);
        } else if (task.srcPath.endsWith('.json')) {
          translated = await translateJson(content, task.targetLocale, engine);
        }
```
Update the filter logic in `getAllFiles` checking in the `run()` function:
```javascript
    filesToTranslate = allFiles.filter(f => 
      (f.endsWith('.mdx') || f.endsWith('_meta.js') || f.endsWith('notifications.json')) && 
      !f.includes('/privacy/') && 
      !f.includes('/terms/') &&
      !f.includes('/license/')
    );
```

- [ ] **Step 2: Run translation script**

Run: `node website/scripts/translate.js website/app/en/notifications.json`
Expected: Success logs and creation of `website/app/<lang>/notifications.json`.

- [ ] **Step 3: Commit**

```bash
git add website/scripts/translate.js website/app/*/notifications.json
git commit -m "feat(website): support translating notifications.json"
```

### Task 3: Implement Notification Component

**Files:**
- Create: `website/components/NotificationBell.tsx`

- [ ] **Step 1: Write component code**

```tsx
'use client';
import React, { useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';

export default function NotificationBell() {
  const [isOpen, setIsOpen] = useState(false);
  const [showBadge, setShowBadge] = useState(false);
  const [data, setData] = useState<any>(null);
  const pathname = usePathname();
  const router = useRouter();

  useEffect(() => {
    try {
      const seen = localStorage.getItem('tracelet_notif_3.3.0_seen');
      if (!seen) setShowBadge(true);
    } catch (e) {
      // Ignore localStorage errors (e.g., incognito)
    }

    // Determine locale from pathname (e.g., /en/core/...)
    const segments = pathname.split('/');
    const locale = segments[1] || 'en';

    // Fetch the correct JSON
    import(`../app/${locale}/notifications.json`)
      .then((mod) => setData(mod.default || mod))
      .catch(() => {
        // Fallback to english
        import('../app/en/notifications.json').then((mod) => setData(mod.default || mod));
      });
  }, [pathname]);

  if (!data) return null;

  const toggleOpen = () => {
    if (!isOpen && showBadge) {
      setShowBadge(false);
      try {
        localStorage.setItem('tracelet_notif_3.3.0_seen', 'true');
      } catch (e) {}
    }
    setIsOpen(!isOpen);
  };

  const handleNavigate = (href: string) => {
    setIsOpen(false);
    const segments = pathname.split('/');
    const locale = segments[1] || 'en';
    router.push(`/${locale}${href}`);
  };

  return (
    <div style={{ position: 'relative' }}>
      <button 
        onClick={toggleOpen}
        style={{ background: 'none', border: 'none', cursor: 'pointer', position: 'relative', padding: '8px' }}
        aria-label="Notifications"
      >
        <span style={{ fontSize: '1.25rem' }}>🔔</span>
        {showBadge && (
          <span style={{
            position: 'absolute', top: '0', right: '0', background: '#ef4444', color: 'white',
            borderRadius: '50%', width: '16px', height: '16px', fontSize: '10px',
            display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold'
          }}>
            1
          </span>
        )}
      </button>

      {isOpen && (
        <div style={{
          position: 'absolute', top: '100%', right: '0', marginTop: '0.5rem',
          background: 'white', border: '1px solid #e5e7eb', borderRadius: '0.5rem',
          boxShadow: '0 10px 15px -3px rgba(0,0,0,0.1)', width: '300px', zIndex: 50,
          color: '#1f2937'
        }}>
          <div style={{ padding: '0.75rem', borderBottom: '1px solid #e5e7eb', fontWeight: 600, fontSize: '0.875rem' }}>
            {data.badgeTitle}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            {data.items.map((item: any, idx: number) => (
              <button 
                key={idx}
                onClick={() => handleNavigate(item.href)}
                style={{
                  padding: '0.75rem', background: 'none', border: 'none', borderBottom: idx < data.items.length - 1 ? '1px solid #f3f4f6' : 'none',
                  textAlign: 'left', cursor: 'pointer', display: 'flex', flexDirection: 'column', gap: '0.25rem'
                }}
                onMouseOver={(e) => e.currentTarget.style.backgroundColor = '#f9fafb'}
                onMouseOut={(e) => e.currentTarget.style.backgroundColor = 'transparent'}
              >
                <span style={{ fontWeight: 600, fontSize: '0.875rem', color: '#0F9D58' }}>{item.title}</span>
                <span style={{ fontSize: '0.75rem', color: '#6b7280', lineHeight: 1.4 }}>{item.description}</span>
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Typecheck component**

Run: `npx tsc --noEmit` inside `website/`
Expected: Clean compilation (no errors related to `NotificationBell.tsx`).

- [ ] **Step 3: Commit**

```bash
git add website/components/NotificationBell.tsx
git commit -m "feat(website): add notification bell component"
```

### Task 4: Integrate Component into Layout

**Files:**
- Modify: `website/theme.config.jsx`

- [ ] **Step 1: Inject NotificationBell**

Add the import at the top of `website/theme.config.jsx`:
```jsx
import NotificationBell from './components/NotificationBell'
```

Add the `navbar` property:
```jsx
  navbar: {
    extra: <NotificationBell />
  },
```

- [ ] **Step 2: Start dev server to verify**

Run: `npm run dev` inside `website/` (in background/separate terminal)
Verify: Access `http://localhost:3000` and confirm the bell appears. Check dropdown and translations.

- [ ] **Step 3: Commit**

```bash
git add website/theme.config.jsx
git commit -m "feat(website): inject notification bell into navbar"
```

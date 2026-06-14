# Notification Dropdown Design

## Goal
Add a notification bell to the website navigation bar to highlight new features (specifically the 3.3.0 Driving & Safety features) to users. The notification strings must be fully localized using the existing translation script.

## Architecture & Components

### 1. Notification Data (`notifications.json`)
We will create a `website/app/en/notifications.json` file. This acts as the source of truth for current notifications:
```json
{
  "badgeTitle": "New in 3.3.0",
  "items": [
    { "title": "Driving Events", "href": "/core/driving-safety" },
    { "title": "Transport Mode", "href": "/core/driving-safety" },
    { "title": "Crash Detection", "href": "/core/driving-safety" },
    { "title": "Telematics APIs", "href": "/core/driving-safety" }
  ]
}
```

### 2. Localization Pipeline (`scripts/translate.js`)
We will update the automated `translate.js` script to process `.json` files alongside `.mdx` and `_meta.js`.
- It will parse the JSON.
- It will pass the text fields (`badgeTitle`, `title`) through the translation engines (Google/Bing).
- It will write the translated JSON objects to their respective locale folders (`app/es/notifications.json`, `app/ja/notifications.json`, etc.).

### 3. UI Component (`NotificationBell.tsx`)
A new client-side React component in `website/components/NotificationBell.tsx`.
- **State**: Checks `localStorage.getItem('tracelet_notif_3.3.0_seen')` on mount to decide if the red "1" badge should be shown.
- **Interaction**: Clicking the bell opens a dropdown menu listing the items. Opening the menu sets the `localStorage` flag and hides the badge.
- **Routing**: Clicking an item routes to the specified `href`, prepended with the active locale (e.g., `/en/core/driving-safety`).
- **Integration**: It will be injected into the Nextra layout via `theme.config.jsx` using `navbar: { extra: <NotificationBell /> }`.

## Edge Cases & Error Handling
- **SSR / Hydration Mismatch**: `localStorage` is not available on the server. The badge visibility must be determined in a `useEffect` to prevent hydration errors.
- **Missing Translations**: The component will dynamically `import()` the JSON file based on the current locale. If the file is missing or fails to load, it will fallback to importing the English JSON.
- **Incognito Mode**: Wrapping `localStorage` calls in a `try/catch` ensures the site doesn't crash if storage access is blocked by the browser.

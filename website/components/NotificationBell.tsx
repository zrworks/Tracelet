'use client';
import React, { useEffect, useState, useRef } from 'react';
import { usePathname, useRouter } from 'next/navigation';

export default function NotificationBell() {
  const [isOpen, setIsOpen] = useState(false);
  const [showBadge, setShowBadge] = useState(false);
  const [data, setData] = useState<any>(null);
  const pathname = usePathname();
  const router = useRouter();
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    try {
      const seen = localStorage.getItem('tracelet_notif_3.3.0_seen');
      if (!seen) setShowBadge(true);
    } catch (e) {
      // Ignore localStorage errors (e.g., incognito)
    }

    // Determine locale from pathname (e.g., /en/core/...)
    const segments = pathname?.split('/') || [];
    const locale = segments[1] || 'en';

    // Fetch the correct JSON
    import(`../app/${locale}/notifications.json`)
      .then((mod) => setData(mod.default || mod))
      .catch(() => {
        // Fallback to english
        import('../app/en/notifications.json').then((mod) => setData(mod.default || mod));
      });
  }, [pathname]);

  useEffect(() => {
    // Click outside to close
    function handleClickOutside(event: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

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
    const segments = pathname?.split('/') || [];
    const locale = segments[1] || 'en';
    router.push(`/${locale}${href}`);
  };

  return (
    <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }} ref={dropdownRef}>
      <button 
        onClick={toggleOpen}
        style={{ background: 'none', border: 'none', cursor: 'pointer', position: 'relative', padding: '6px', display: 'flex', alignItems: 'center', color: 'currentColor' }}
        aria-label="Notifications"
      >
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ display: 'block' }}>
          <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path>
          <path d="M13.73 21a2 2 0 0 1-3.46 0"></path>
        </svg>
        {showBadge && (
          <span style={{
            position: 'absolute', top: '0px', right: '0px', background: '#ef4444', color: 'white',
            borderRadius: '50%', width: '14px', height: '14px', fontSize: '9px',
            display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold'
          }}>
            1
          </span>
        )}
      </button>

      {isOpen && (
        <div style={{
          position: 'absolute', top: '100%', right: '0', marginTop: '0.5rem',
          backgroundColor: 'var(--nextra-bg, white)', border: '1px solid var(--nextra-border, #e5e7eb)', borderRadius: '0.5rem',
          boxShadow: '0 10px 15px -3px rgba(0,0,0,0.1)', width: '300px', zIndex: 100,
          color: 'var(--nextra-fg, #1f2937)'
        }}>
          <div style={{ padding: '0.75rem', borderBottom: '1px solid var(--nextra-border, #e5e7eb)', fontWeight: 600, fontSize: '0.875rem' }}>
            {data.badgeTitle}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            {data.items.map((item: any, idx: number) => (
              <button 
                key={idx}
                onClick={() => handleNavigate(item.href)}
                style={{
                  padding: '0.75rem', background: 'none', border: 'none', borderBottom: idx < data.items.length - 1 ? '1px solid var(--nextra-border, #f3f4f6)' : 'none',
                  textAlign: 'left', cursor: 'pointer', display: 'flex', flexDirection: 'column', gap: '0.25rem'
                }}
                onMouseOver={(e) => e.currentTarget.style.backgroundColor = 'var(--nextra-primary-hue, rgba(15, 157, 88, 0.05))'}
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

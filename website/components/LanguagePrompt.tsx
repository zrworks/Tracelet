'use client';
import React, { useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';

const languageMap: Record<string, { code: string, name: string, prompt: string }> = {
  'hi': { code: 'hi', name: 'Hindi', prompt: 'हिंदी में अनुवाद करें?' },
  'zh': { code: 'zh', name: 'Chinese', prompt: '翻译成中文？' },
  'ja': { code: 'ja', name: 'Japanese', prompt: '日本語に翻訳しますか？' },
  'es': { code: 'es', name: 'Spanish', prompt: '¿Traducir al español?' },
  'ml': { code: 'ml', name: 'Malayalam', prompt: 'മലയാളത്തിലേക്ക് മാറ്റണോ?' },
  'ta': { code: 'ta', name: 'Tamil', prompt: 'தமிழில் மொழிபெயர்க்கவா?' },
  'ru': { code: 'ru', name: 'Russian', prompt: 'Перевести на русский?' }
};

export default function LanguagePrompt() {
  const [targetLang, setTargetLang] = useState<string | null>(null);
  const pathname = usePathname();
  const router = useRouter();

  useEffect(() => {
    // Only show on English pages (or root)
    if (!pathname || (!pathname.startsWith('/en') && pathname !== '/')) {
      return;
    }

    const dismissed = localStorage.getItem('tracelet_lang_prompt_dismissed');
    if (dismissed) return;

    // Detect browser language (or use URL param for testing)
    const urlParams = new URLSearchParams(window.location.search);
    const testLang = urlParams.get('test_lang');
    
    let browserLang = testLang || navigator.language.split('-')[0].toLowerCase();
    
    // Check if we support it and it's not english
    if (browserLang !== 'en' && languageMap[browserLang]) {
      // Small delay to let page load first
      setTimeout(() => setTargetLang(browserLang), 1500);
    }
  }, [pathname]);

  if (!targetLang) return null;
  const langInfo = languageMap[targetLang];

  const handleYes = () => {
    localStorage.setItem('tracelet_lang_prompt_dismissed', 'true');
    const newPath = pathname === '/' ? `/${targetLang}` : pathname.replace(/^\/en/, `/${targetLang}`);
    router.push(newPath);
  };

  const handleNo = () => {
    localStorage.setItem('tracelet_lang_prompt_dismissed', 'true');
    setTargetLang(null);
  };

  return (
    <div style={{
      position: 'fixed',
      top: '70px',
      right: '24px',
      zIndex: 100,
      animation: 'tracelet-bounce 1.5s infinite ease-in-out'
    }}>
      {/* Upward pointing arrow */}
      <div style={{
        position: 'absolute',
        top: '-8px',
        right: '20px',
        width: 0,
        height: 0,
        borderLeft: '8px solid transparent',
        borderRight: '8px solid transparent',
        borderBottom: '8px solid #ffffff',
        filter: 'drop-shadow(0 -2px 2px rgba(0,0,0,0.05))'
      }}></div>
      
      <div style={{
        backgroundColor: '#ffffff',
        border: '1px solid #e5e7eb',
        boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)',
        borderRadius: '1rem',
        padding: '1rem 1.25rem',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: '0.75rem',
        minWidth: '200px'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <span style={{ fontSize: '1.25rem' }}>🌍</span>
          <span style={{ fontWeight: 500, color: '#1f2937', fontSize: '0.875rem', textAlign: 'center' }}>
            {langInfo.prompt}
          </span>
        </div>
        <div style={{ display: 'flex', gap: '0.5rem', width: '100%', marginTop: '0.25rem' }}>
          <button 
            onClick={handleYes}
            style={{
              flex: 1,
              backgroundColor: '#0F9D58',
              color: '#ffffff',
              padding: '0.375rem 0.75rem',
              borderRadius: '0.5rem',
              fontSize: '0.875rem',
              fontWeight: 600,
              border: 'none',
              cursor: 'pointer'
            }}
          >
            Yes
          </button>
          <button 
            onClick={handleNo}
            style={{
              flex: 1,
              backgroundColor: '#f3f4f6',
              color: '#4b5563',
              padding: '0.375rem 0.75rem',
              borderRadius: '0.5rem',
              fontSize: '0.875rem',
              fontWeight: 500,
              border: 'none',
              cursor: 'pointer'
            }}
          >
            No
          </button>
        </div>
      </div>
    </div>
  );
}

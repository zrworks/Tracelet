"use client"

import React, { useEffect, useRef, useState } from 'react';
import dynamic from 'next/dynamic';

const DotLottieReact = dynamic(
  () => import('@lottiefiles/dotlottie-react').then((mod) => mod.DotLottieReact),
  { ssr: false }
);

export default function LottiePlayer({ 
  src, 
  maxWidth = '600px', 
  minHeight = '300px' 
}: { 
  src: string; 
  maxWidth?: string; 
  minHeight?: string; 
}) {
  const [isVisible, setIsVisible] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const currentRef = containerRef.current;
    
    if (!('IntersectionObserver' in window)) {
      setIsVisible(true);
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            setIsVisible(true);
            observer.disconnect();
          }
        });
      },
      {
        rootMargin: '200px',
        threshold: 0
      }
    );

    if (currentRef) {
      observer.observe(currentRef);
    }

    return () => {
      if (currentRef) {
        observer.unobserve(currentRef);
      }
      observer.disconnect();
    };
  }, []);

  return (
    <div ref={containerRef} style={{ width: '100%', maxWidth, minHeight, margin: '0 auto', padding: '2rem 0' }}>
      {isVisible && (
        <DotLottieReact
          src={src}
          loop
          autoplay
        />
      )}
    </div>
  );
}

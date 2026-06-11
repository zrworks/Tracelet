"use client"

import React from 'react';
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
  return (
    <div style={{ width: '100%', maxWidth, minHeight, margin: '0 auto', padding: '2rem 0' }}>
      <DotLottieReact
        src={src}
        loop
        autoplay
      />
    </div>
  );
}

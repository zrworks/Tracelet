"use client"

import React from 'react';
import dynamic from 'next/dynamic';

const DotLottieReact = dynamic(
  () => import('@lottiefiles/dotlottie-react').then((mod) => mod.DotLottieReact),
  { ssr: false }
);

export default function CityAnimation() {
  return (
    <div style={{ width: '100%', maxWidth: '600px', minHeight: '300px', margin: '0 auto', padding: '2rem 0' }}>
      <DotLottieReact
        src="/buildAnim.json"
        loop
        autoplay
      />
    </div>
  );
}

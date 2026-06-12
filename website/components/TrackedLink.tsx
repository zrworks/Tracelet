"use client";

import React from "react";

interface TrackedLinkProps extends React.AnchorHTMLAttributes<HTMLAnchorElement> {
  eventName: string;
}

export default function TrackedLink({ eventName, children, ...props }: TrackedLinkProps) {
  const handleClick = (e: React.MouseEvent<HTMLAnchorElement>) => {
    // Log the event asynchronously via Cloudflare Zaraz
    if (typeof window !== 'undefined' && (window as any).zaraz) {
      (window as any).zaraz.track(eventName, {
        link_url: props.href
      });
    }

    if (props.onClick) {
      props.onClick(e);
    }
  };

  return (
    <a {...props} onClick={handleClick}>
      {children}
    </a>
  );
}

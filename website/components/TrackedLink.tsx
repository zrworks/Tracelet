"use client";

import React from "react";
import { getAnalyticsInstance } from "../lib/firebase";
import { logEvent } from "firebase/analytics";

interface TrackedLinkProps extends React.AnchorHTMLAttributes<HTMLAnchorElement> {
  eventName: string;
}

export default function TrackedLink({ eventName, children, ...props }: TrackedLinkProps) {
  const handleClick = (e: React.MouseEvent<HTMLAnchorElement>) => {
    // Log the event asynchronously
    getAnalyticsInstance().then(analytics => {
      if (analytics) {
        logEvent(analytics, eventName, {
          link_url: props.href
        });
      }
    });

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

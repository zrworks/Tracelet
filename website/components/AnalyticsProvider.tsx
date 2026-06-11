"use client";

import { useEffect } from "react";
import { usePathname, useSearchParams } from "next/navigation";
import { getAnalyticsInstance } from "../lib/firebase";
import { logEvent } from "firebase/analytics";

export default function AnalyticsProvider() {
  const pathname = usePathname();
  const searchParams = useSearchParams();

  useEffect(() => {
    const url = pathname + searchParams.toString();
    
    getAnalyticsInstance().then((analytics) => {
      if (analytics) {
        logEvent(analytics, "page_view", {
          page_path: url,
        });
      }
    });
  }, [pathname, searchParams]);

  return null;
}

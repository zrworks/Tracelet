"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

export default function RootPage() {
  const router = useRouter();

  useEffect(() => {
    // Basic locale detection could be added here
    // For now, default to English
    router.replace("/en");
  }, [router]);

  return null;
}

"use client";

import { useEffect, useState } from "react";

export default function CookieBanner() {
  const [showBanner, setShowBanner] = useState(false);

  useEffect(() => {
    // Check if user has already made a choice
    const consent = localStorage.getItem("tracelet_cookie_consent");
    if (!consent) {
      setShowBanner(true);
    } else if (consent === "accepted") {
      // Cloudflare Zaraz loads analytics server-side, but we can track the consent event
      if (typeof window !== 'undefined' && (window as any).zaraz) {
         (window as any).zaraz.track("consent_previously_given");
      }
    }
  }, []);

  const handleAccept = () => {
    localStorage.setItem("tracelet_cookie_consent", "accepted");
    setShowBanner(false);
    
    // Initialize analytics right now
    if (typeof window !== 'undefined' && (window as any).zaraz) {
       (window as any).zaraz.track("consent_accepted");
    }
  };

  const handleDecline = () => {
    localStorage.setItem("tracelet_cookie_consent", "declined");
    setShowBanner(false);
  };

  if (!showBanner) return null;

  return (
    <div style={{
      position: "fixed",
      bottom: "20px",
      left: "20px",
      right: "20px",
      maxWidth: "600px",
      margin: "0 auto",
      borderRadius: "0.75rem",
      padding: "1.25rem",
      boxShadow: "0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)",
      zIndex: 9999,
      display: "flex",
      flexDirection: "column",
      gap: "1rem"
    }} className="cookie-banner">
      <div style={{ display: "flex", alignItems: "flex-start", gap: "1rem" }}>
        <span style={{ fontSize: "1.5rem" }}>🍪</span>
        <div style={{ flex: 1 }}>
          <h3 style={{ margin: 0, fontWeight: "600", fontSize: "1rem" }}>We use cookies</h3>
          <p style={{ margin: "0.5rem 0 0 0", fontSize: "0.875rem" }} className="cookie-banner-text">
            We use Google Analytics to understand how you interact with our documentation. 
            This helps us improve the developer experience. Do you accept tracking?
          </p>
        </div>
      </div>
      <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.75rem" }}>
        <button 
          onClick={handleDecline}
          style={{ padding: "0.5rem 1rem", borderRadius: "0.375rem", backgroundColor: "transparent", cursor: "pointer", fontSize: "0.875rem", fontWeight: "500", color: "inherit", transition: "all 0.2s" }}
          className="cookie-btn-decline"
        >
          Decline
        </button>
        <button 
          onClick={handleAccept}
          style={{ padding: "0.5rem 1rem", borderRadius: "0.375rem", border: "none", backgroundColor: "#0F9D58", color: "white", cursor: "pointer", fontSize: "0.875rem", fontWeight: "600", transition: "all 0.2s" }}
          className="hover:opacity-90 transition-opacity"
        >
          Accept
        </button>
      </div>
    </div>
  );
}

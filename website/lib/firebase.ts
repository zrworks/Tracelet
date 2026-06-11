import { initializeApp, getApps, getApp } from "firebase/app";
import { getAnalytics, isSupported } from "firebase/analytics";

const firebaseConfig = {
  projectId: "ikolvi",
  appId: "1:472060165856:web:6ed52b22d46cc8c9d2da85",
  apiKey: "AIzaSyDNHLV16UG_5zV5-B9n7QsxQmmFZfj5zxQ",
  messagingSenderId: "472060165856",
  measurementId: "G-42X97WN4M8"
};

// Initialize Firebase
const app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);

// Initialize Analytics lazily to ensure it only runs on the client and if consent is given
export const getAnalyticsInstance = async () => {
  if (typeof window !== "undefined" && await isSupported()) {
    return getAnalytics(app);
  }
  return null;
};

export { app };

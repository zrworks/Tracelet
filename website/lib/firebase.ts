import { initializeApp, getApps, getApp } from "firebase/app";

const firebaseConfig = {
  projectId: "ikolvi",
  appId: "1:472060165856:web:6ed52b22d46cc8c9d2da85",
  apiKey: "AIzaSyDNHLV16UG_5zV5-B9n7QsxQmmFZfj5zxQ",
  messagingSenderId: "472060165856",
  measurementId: "G-42X97WN4M8"
};

// Initialize Firebase
const app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);

export { app };

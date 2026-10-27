import { StrictMode, useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import { supabase } from "./services/supabase";
import AuthPage from "./pages/AuthPage.jsx";
import AuthorityDashboard from "./pages/AuthorityDashboard.jsx";

function AppPreview() {
  return <AuthorityDashboard />;
}

createRoot(document.getElementById("root")).render(
  <StrictMode>
    <AppPreview />
  </StrictMode>
);
